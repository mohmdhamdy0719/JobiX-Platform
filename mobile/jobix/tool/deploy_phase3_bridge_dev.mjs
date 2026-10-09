// Approved development-only bridge rollout. No migrations, keys or Credit commands.
import {readFile,writeFile} from 'node:fs/promises';
import {google,project,region,backend} from './phase3_google.mjs';
import {gatewayIdentity,publicClientKey} from '../backend/export-gateway/core.mjs';

let operation='PRECONDITIONS',resource='',principal='';
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const assert=(condition,code)=>{if(!condition)throw Error(code);};
async function main() {
  assert(process.argv.includes('--approved-development-bridge-rollout'),'EXPLICIT_APPROVAL_REQUIRED');
  const images=JSON.parse(await readFile('/tmp/jobix-bridge-built-images.json','utf8')).images;
  const pinned=component=>{
    const prefix=`${region}-docker.pkg.dev/${project}/jobix-dev/${component}:source-`;
    const image=images.find(x=>x.name.startsWith(prefix));
    assert(image&&/^sha256:[0-9a-f]{64}$/.test(image.digest),'PINNED_IMAGE_REQUIRED');
    return image.name.split(':')[0]+'@'+image.digest;
  };
  const workerImage=pinned('pdf-worker'),bridgeImage=pinned('export-gateway');
  const config=JSON.parse(await readFile('mobile/jobix/config/dev.local.json','utf8'));
  assert(config.APP_ENV==='dev'&&config.SUPABASE_URL==='https://lmouxhbjhtqdtiqijcee.supabase.co',
    'DEVELOPMENT_AUTH_REQUIRED');
  publicClientKey(config.SUPABASE_CLIENT_KEY);
  const adr=await readFile('mobile/jobix/backend/pdf/ADR-retention-deletion.md','utf8');
  assert(adr.includes('Product decision approved')&&adr.includes('7-day logical retention'),
    'APPROVED_DELETION_CONTRACT_REQUIRED');
  const g=await google();principal=g.principal;
  assert(principal==='jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com','EXPECTED_DEPLOYER_REQUIRED');
  const parent=`projects/${project}/locations/${region}/services`;
  const workerName=parent+'/jobix-dev-pdf-export',bridgeName=parent+'/jobix-dev-export-gateway';
  const url=name=>'https://run.googleapis.com/v2/'+name;
  const flags=service=>Object.fromEntries(service.template.containers[0].env
    .filter(e=>['JOBIX_EXPORT_ENABLED','JOBIX_EXPORT_DELETION_POLICY_APPROVED'].includes(e.name))
    .map(e=>[e.name,e.value]));
  const wait=async op=>{
    for(let i=0;i<60;i++) {
      const r=await g.request('https://run.googleapis.com/v2/'+op.name);
      if(r.error)throw Error('CLOUD_RUN_OPERATION_FAILED_CODE_'+r.error.code);
      if(r.done)return;
      await sleep(5000);
    }
    throw Error('CLOUD_RUN_OPERATION_TIMEOUT');
  };
  const privateWorker=async()=>{
    const service=await g.request(url(workerName)),policy=await g.request(url(workerName)+':getIamPolicy');
    assert(!service.invokerIamDisabled,'WORKER_MUST_REMAIN_PRIVATE');
    assert(!(policy.bindings??[]).some(b=>b.members?.some(m=>
      ['allUsers','allAuthenticatedUsers'].includes(m))),'PUBLIC_WORKER_BINDING_REJECTED');
    assert(service.template.serviceAccount===backend,'WORKER_IDENTITY_CHANGED');
    assert((policy.bindings??[]).some(b=>b.role==='roles/run.invoker'&&!b.condition&&
      b.members?.includes('serviceAccount:'+gatewayIdentity)),'GATEWAY_WORKER_INVOKER_REQUIRED');
    return service;
  };
  const permission=await g.request(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/${gatewayIdentity}:testIamPermissions`,
    {method:'POST',body:{permissions:['iam.serviceAccounts.actAs']}});
  assert(permission.permissions?.includes('iam.serviceAccounts.actAs'),'GATEWAY_ACTAS_REQUIRED');
  try{await g.request(url(bridgeName));throw Error('EXISTING_BRIDGE_REQUIRES_RECONCILIATION');}
  catch(e){if(e.status!==404)throw e;}
  const worker=await privateWorker(),workerUri=worker.uri;
  assert(flags(worker).JOBIX_EXPORT_DELETION_POLICY_APPROVED==='true','PRESERVE_APPROVED_DELETION_GATE');
  const containers=structuredClone(worker.template.containers);
  containers[0].image=workerImage;
  const exportFlag=containers[0].env.find(e=>e.name==='JOBIX_EXPORT_ENABLED');
  assert(exportFlag&&Object.hasOwn(exportFlag,'value'),'WORKER_EXPORT_FLAG_REQUIRED');
  exportFlag.value='false';
  operation='PATCH_WORKER_IMAGE_AND_DISABLE_EXPORTS';resource=workerName;
  await wait(await g.request(url(workerName)+'?updateMask=template.containers',
    {method:'PATCH',write:true,body:{name:workerName,etag:worker.etag,template:{containers}}}));
  const updated=await privateWorker();
  assert(flags(updated).JOBIX_EXPORT_ENABLED==='false','WORKER_EXPORTS_NOT_DISABLED');
  assert(flags(updated).JOBIX_EXPORT_DELETION_POLICY_APPROVED==='true','DELETION_APPROVAL_CHANGED');
  console.log(JSON.stringify({operation,revision:updated.latestReadyRevision,exportsEnabled:false,
    deletionPolicyApproved:true,image:workerImage}));

  operation='CREATE_DEVELOPMENT_GATEWAY';resource=bridgeName;
  const create=await g.request(url(parent)+'?serviceId=jobix-dev-export-gateway',
    {method:'POST',write:true,body:{
      labels:{product:'jobix',environment:'development',component:'export-gateway'},
      ingress:'INGRESS_TRAFFIC_ALL',invokerIamDisabled:false,
      template:{serviceAccount:gatewayIdentity,timeout:'60s',maxInstanceRequestConcurrency:20,
        scaling:{minInstanceCount:0,maxInstanceCount:1},containers:[{
          image:bridgeImage,ports:[{containerPort:8080}],
          resources:{limits:{cpu:'1',memory:'256Mi'},cpuIdle:true},
          startupProbe:{httpGet:{path:'/ready',port:8080},periodSeconds:5,timeoutSeconds:2,failureThreshold:24},
          env:[
            {name:'GCP_PROJECT_ID',value:project},
            {name:'JOBIX_DEV_EXPORT_WORKER_URL',value:workerUri},
            {name:'JOBIX_DEV_SUPABASE_CLIENT_KEY',value:config.SUPABASE_CLIENT_KEY},
            {name:'JOBIX_EXPORT_ENABLED',value:'false'},
            {name:'JOBIX_EXPORT_DELETION_POLICY_APPROVED',value:'true'},
          ],
        }]},
    }});
  await wait(create);
  const bridge=await g.request(url(bridgeName));
  assert(bridge.template.serviceAccount===gatewayIdentity,'GATEWAY_IDENTITY_CHANGED');
  assert(flags(bridge).JOBIX_EXPORT_ENABLED==='false','GATEWAY_EXPORTS_NOT_DISABLED');
  operation='PUBLIC_INVOCATION_ON_GATEWAY_ONLY';
  const policy=await g.request(url(bridgeName)+':getIamPolicy');
  assert(!(policy.bindings??[]).length,'UNEXPECTED_NEW_GATEWAY_BINDINGS');
  await g.request(url(bridgeName)+':setIamPolicy',{method:'POST',write:true,
    body:{policy:{version:3,etag:policy.etag,bindings:[{role:'roles/run.invoker',members:['allUsers']}]}}});
  console.log(JSON.stringify({operation,resource:bridgeName,revision:bridge.latestReadyRevision,
    identity:gatewayIdentity,image:bridgeImage,exportsEnabled:false}));
  operation='LIVE_SECURITY_PROBES';
  let ready;
  for(let i=0;i<12;i++){
    const r=await fetch(bridge.uri+'/ready',{signal:AbortSignal.timeout(20000)});
    if(r.ok){ready=await r.json();break;}await sleep(5000);
  }
  assert(ready?.workerAuthenticationVerified&&ready.workerOnlyPathsDenied&&
    ready.exportsEnabled===false&&ready.identity===gatewayIdentity,'HOSTED_BRIDGE_WORKER_CHECK_FAILED');
  const claims={iss:config.SUPABASE_URL+'/auth/v1',aud:'authenticated',
    sub:'00000000-0000-4000-8000-000000000001',exp:Math.floor(Date.now()/1000)+120};
  const token=[{alg:'ES256',typ:'JWT'},claims].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url'))
    .join('.')+'.'+Buffer.alloc(64).toString('base64url');
  const post=(uri,body,auth)=>fetch(uri,{method:'POST',signal:AbortSignal.timeout(30000),
    headers:{'Content-Type':'application/json',...(auth?{Authorization:auth}:{})},body:JSON.stringify(body)});
  const checks=[{name:'hosted_gateway_to_worker_and_worker_only_path_denial',pass:true}];
  const anonymous=await post(workerUri+'/command',{action:'history',command:{}});
  checks.push({name:'anonymous_worker_rejected',status:anonymous.status,pass:anonymous.status===403});
  for(const [name,body,auth,expected] of [
    ['missing_user_token',{action:'history',command:{}},null,401],
    ['invalid_signature_rejected_by_supabase',{action:'history',command:{}},'Bearer '+token,401],
    ['forged_actor_rejected',{action:'history',command:{},actor:claims.sub},'Bearer '+token,403],
    ['worker_only_command_rejected',{action:'recover',command:{}},'Bearer '+token,400],
  ]) {
    const r=await post(bridge.uri+'/resume-export',body,auth);
    const b=await r.json();
    checks.push({name,status:r.status,code:b.error?.code,pass:r.status===expected});
  }
  await privateWorker();
  const publicPolicy=await g.request(url(bridgeName)+':getIamPolicy');
  assert(publicPolicy.bindings?.length===1&&publicPolicy.bindings[0].role==='roles/run.invoker'&&
    publicPolicy.bindings[0].members?.length===1&&publicPolicy.bindings[0].members[0]==='allUsers',
    'GATEWAY_PUBLIC_POLICY_MISMATCH');
  await writeFile('/tmp/jobix-bridge-live-results.json',JSON.stringify({
    worker:workerName,workerRevision:updated.latestReadyRevision,gateway:bridgeName,
    gatewayRevision:bridge.latestReadyRevision,gatewayUri:bridge.uri,checks,
    exportsEnabled:false,deletionPolicyApproved:true,
  },null,2));
  console.log(JSON.stringify({operation,gatewayUri:bridge.uri,checks,exportsEnabled:false}));
  assert(checks.every(c=>c.pass),'LIVE_SECURITY_CHECK_FAILED');
}
main().catch(e=>{
  console.error(JSON.stringify({operation,principal,resource,status:e.status??null,
    permission:e.permission??null,reason:e.reason??null,code:e.message}));
  process.exitCode=1;
});
