// Image-only update of the existing development Worker; never opens export gates.
import {readFile,writeFile} from 'node:fs/promises';
import {google,project,region,backend} from './phase3_google.mjs';
const assert=(value,code)=>{if(!value)throw Error(code);};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let stage='preconditions';
async function main() {
  assert(process.argv.includes('--approved-development-worker-fix'),'EXPLICIT_APPROVAL_REQUIRED');
  const submitted=JSON.parse((await readFile('/tmp/jobix-phone-worker-build-submit.log','utf8'))
    .trim().split('\n').at(-1));
  assert(/^[0-9a-f-]{36}$/.test(submitted.buildId),'REGIONAL_BUILD_ID_REQUIRED');
  const g=await google();
  assert(g.principal==='jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com',
    'EXPECTED_DEPLOYER_REQUIRED');
  const build=await g.request(`https://cloudbuild.googleapis.com/v1/projects/${project}/locations/${region}/builds/${submitted.buildId}`);
  assert(build.status==='SUCCESS','SUCCESSFUL_BUILD_REQUIRED');
  const result=build.results?.images?.find(x=>x.name===submitted.image);
  assert(result&&/^sha256:[0-9a-f]{64}$/.test(result.digest),'VERIFIED_BUILD_DIGEST_REQUIRED');
  const image=`${region}-docker.pkg.dev/${project}/jobix-dev/pdf-worker@${result.digest}`;
  const base=`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services/`;
  const url=base+'jobix-dev-pdf-export',gatewayUrl=base+'jobix-dev-export-gateway';
  const [before,policy,gateway]=await Promise.all([
    g.request(url),g.request(url+':getIamPolicy'),g.request(gatewayUrl),
  ]);
  const privateWorker=(s,p)=>{
    assert(!s.invokerIamDisabled&&s.template.serviceAccount===backend,'PRIVATE_WORKER_IDENTITY_REQUIRED');
    assert(!(p.bindings??[]).some(b=>b.members?.some(m=>['allUsers','allAuthenticatedUsers'].includes(m))),
      'PRIVATE_WORKER_POLICY_REQUIRED');
  };
  privateWorker(before,policy);
  const env=Object.fromEntries(before.template.containers[0].env.map(e=>[e.name,e.value??e.valueSource]));
  assert(env.JOBIX_EXPORT_ENABLED==='false'&&env.JOBIX_EXPORT_DELETION_POLICY_APPROVED==='true',
    'CLOSED_GATE_APPROVED_POLICY_REQUIRED');
  assert(env.JOBIX_DEV_EXPORT_DATABASE_URL?.secretKeyRef?.secret==='jobix-dev-export-database'&&
    env.JOBIX_DEV_EXPORT_DATABASE_URL.secretKeyRef.version==='1'&&
    env.JOBIX_DEV_DATABASE_CA_FILE==='/opt/jobix/assets/certs/supabase-root-2021.crt',
    'EXISTING_DATABASE_TLS_CONFIG_REQUIRED');
  assert(gateway.template.containers[0].env.find(x=>x.name==='JOBIX_EXPORT_ENABLED')?.value==='false',
    'CLOSED_GATEWAY_GATE_REQUIRED');
  const containers=structuredClone(before.template.containers);
  containers[0].image=image;
  stage='image_only_worker_patch';
  const op=await g.request(url+'?updateMask=template.containers',{
    method:'PATCH',write:true,
    body:{name:before.name,etag:before.etag,template:{containers}},
  });
  let done=false;
  for(let i=0;i<60;i++){
    const status=await g.request('https://run.googleapis.com/v2/'+op.name);
    assert(!status.error,'WORKER_REVISION_ERROR_'+(status.error?.code??''));
    if(status.done){done=true;break;}await sleep(5000);
  }
  assert(done,'WORKER_REVISION_TIMEOUT_NO_AUTOMATIC_REDEPLOY');
  stage='verify_unchanged_config_and_private_worker';
  const [after,afterPolicy,gatewayAfter]=await Promise.all([
    g.request(url),g.request(url+':getIamPolicy'),g.request(gatewayUrl),
  ]);
  privateWorker(after,afterPolicy);
  assert(after.latestReadyRevision===after.latestCreatedRevision,'WORKER_REVISION_NOT_READY');
  assert(after.template.containers[0].image===image,'WORKER_IMAGE_MISMATCH');
  const normalized=structuredClone(after.template.containers);
  normalized[0].image=before.template.containers[0].image;
  assert(JSON.stringify(normalized)===JSON.stringify(before.template.containers),'NON_IMAGE_CONTAINER_CHANGE');
  assert(JSON.stringify(afterPolicy.bindings)===JSON.stringify(policy.bindings),'WORKER_IAM_CHANGED');
  assert(gatewayAfter.latestReadyRevision===gateway.latestReadyRevision&&
    JSON.stringify(gatewayAfter.template)===JSON.stringify(gateway.template),'GATEWAY_CHANGED');
  stage='gateway_worker_connectivity_and_negative_security';
  const checks=[];
  const ready=await fetch(gateway.uri+'/ready',{signal:AbortSignal.timeout(30000)});
  const body=await ready.json().catch(()=>null);
  // /ready reports the Gateway's successful startup check, not a fresh
  // authenticated user request through the newly deployed Worker.
  checks.push({name:'existing_gateway_startup_health',status:ready.status,pass:ready.ok&&
    body?.workerAuthenticationVerified===true&&body?.workerOnlyPathsDenied===true&&body?.exportsEnabled===false});
  const post=(uri,command,token)=>fetch(uri,{method:'POST',headers:{
    'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),
  },body:JSON.stringify(command),signal:AbortSignal.timeout(30000)});
  const anonymous=await post(after.uri+'/command',{action:'history',command:{}});
  checks.push({name:'anonymous_worker_denied',status:anonymous.status,pass:anonymous.status===403});
  for(const [name,path,command,token,expected] of [
    ['gateway_missing_token','/resume-export',{action:'history',command:{}},null,401],
    ['gateway_invalid_token','/resume-export',{action:'history',command:{}},'invalid',401],
    ['worker_recovery_path_not_public','/recover',{},null,404],
    ['worker_cleanup_command_denied','/resume-export',{action:'cleanup',command:{}},'invalid',400],
  ]){
    const r=await post(gateway.uri+path,command,token);
    checks.push({name,status:r.status,pass:r.status===expected});
  }
  assert(checks.every(x=>x.pass),'DEPLOYED_SECURITY_PROBE_FAILED_NO_AUTOMATIC_REDEPLOY');
  const evidence={project,region,buildId:build.id,workerRevision:after.latestReadyRevision.split('/').at(-1),
    workerImage:image,previousWorkerRevision:before.latestReadyRevision.split('/').at(-1),
    gatewayRevision:gatewayAfter.latestReadyRevision.split('/').at(-1),gatewayImage:gatewayAfter.template.containers[0].image,
    workerPrivate:true,configurationUnchanged:true,exportsEnabled:false,checks};
  await writeFile('/tmp/jobix-phone-worker-deployed.json',JSON.stringify(evidence,null,2));
  console.log(JSON.stringify(evidence,null,2));
}
main().catch(error=>{
  console.error(JSON.stringify({stage,status:error.status??null,permission:error.permission??null,
    code:error.message,principal:'jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com',
    resource:`projects/${project}/locations/${region}/services/jobix-dev-pdf-export`}));
  process.exitCode=1;
});
