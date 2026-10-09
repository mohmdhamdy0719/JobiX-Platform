// Owner-approved existing-service read-only rollout; no keys/migrations/Credits.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {google,project,region,backend} from './phase3_google.mjs';
import {gatewayIdentity} from '../backend/export-gateway/core.mjs';

const ref='lmouxhbjhtqdtiqijcee';
const base=`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services/`;
const workerUrl=base+'jobix-dev-pdf-export',gatewayUrl=base+'jobix-dev-export-gateway';
const assert=(condition,code)=>{if(!condition)throw Error(code);};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let operation='PRECONDITIONS',resource='',principal='';
const flags=service=>Object.fromEntries(service.template.containers[0].env
  .filter(e=>['JOBIX_EXPORT_ENABLED','JOBIX_EXPORT_DELETION_POLICY_APPROVED'].includes(e.name))
  .map(e=>[e.name,e.value]));
function guard(service,identity) {
  assert(service.template.serviceAccount===identity,'ATTACHED_IDENTITY_CHANGED');
  assert(!service.invokerIamDisabled,'IAM_ENFORCEMENT_REQUIRED');
  assert(flags(service).JOBIX_EXPORT_ENABLED==='false','EXPORTS_MUST_STAY_DISABLED');
  assert(flags(service).JOBIX_EXPORT_DELETION_POLICY_APPROVED==='true','PRESERVE_DELETION_APPROVAL');
}
const publicBindings=policy=>(policy.bindings??[]).filter(b=>b.members?.some(m=>
  ['allUsers','allAuthenticatedUsers'].includes(m)));
async function supabase(path,{method='GET',body}={}) {
  assert(path===`/v1/projects/${ref}/secrets`||
    path===`/v1/projects/${ref}/functions/deploy?slug=resume-export`,'DEV_EDGE_RESOURCE_GUARD');
  const token=process.env.JOBIX_DEV_SUPABASE_ACCESS_TOKEN;
  assert(token,'EXISTING_MANAGEMENT_TOKEN_REQUIRED');
  const multipart=body instanceof FormData;
  const r=await fetch('https://api.supabase.com'+path,{method,
    headers:{Authorization:'Bearer '+token,...(multipart?{}:{'Content-Type':'application/json'})},
    body:body===undefined?undefined:multipart?body:JSON.stringify(body),
    redirect:'error',signal:AbortSignal.timeout(120000)});
  if(!r.ok) {
    const e=Error('SUPABASE_MANAGEMENT_OPERATION_REJECTED');
    e.status=r.status;
    e.permission=path.includes('/functions/')?'edge_functions_write':
      method==='GET'?'edge_functions_secrets_read':'edge_functions_secrets_write';
    // Do not log provider bodies, token, environment values or source bundles.
    throw e;
  }
  return r.json();
}
async function main() {
  assert(process.argv.includes('--approved-development-readonly-ingress'),'EXPLICIT_APPROVAL_REQUIRED');
  const mode=process.argv.includes('--edge-only')?'edge':
    process.argv.includes('--images-and-invocation')?'cloud':null;
  assert(mode,'EXPLICIT_ROLLOUT_STAGE_REQUIRED');
  const g=await google();principal=g.principal;
  assert(principal==='jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com','EXPECTED_DEPLOYER_REQUIRED');
  const [worker,gateway,wp,gp]=await Promise.all([
    g.request(workerUrl),g.request(gatewayUrl),
    g.request(workerUrl+':getIamPolicy?options.requestedPolicyVersion=3'),
    g.request(gatewayUrl+':getIamPolicy?options.requestedPolicyVersion=3'),
  ]);
  guard(worker,backend);guard(gateway,gatewayIdentity);
  assert(publicBindings(wp).length===0,'WORKER_PUBLIC_POLICY_REJECTED');
  assert((wp.bindings??[]).some(b=>b.role==='roles/run.invoker'&&!b.condition&&
    b.members?.includes('serviceAccount:'+gatewayIdentity)),'GATEWAY_WORKER_INVOKER_REQUIRED');
  assert(publicBindings(gp).length===0,'UNEXPECTED_EXISTING_PUBLIC_GATEWAY_BINDING');
  if(mode==='edge') {
    principal='Supabase principal represented by JOBIX_DEV_SUPABASE_ACCESS_TOKEN';
    // Set only these owner-approved non-credential settings. No unrelated keys.
    operation='VERIFY_DEVELOPMENT_EDGE_EXPORT_SETTINGS';resource=`projects/${ref}/secrets`;
    const desired=[
      {name:'JOBIX_DEV_EXPORT_GATEWAY_URL',value:gateway.uri},
      {name:'JOBIX_EXPORT_ENABLED',value:'false'},
      {name:'JOBIX_EXPORT_DELETION_POLICY_APPROVED',value:'true'},
    ];
    const metadata=await supabase(`/v1/projects/${ref}/secrets`);
    assert(Array.isArray(metadata),'UNEXPECTED_SETTINGS_METADATA');
    // Only compare these known non-credential settings. Supabase returns
    // hashed values; never log values/hashes or inspect unrelated secrets.
    const missing=desired.filter(({name,value})=>{
      const row=metadata.find(x=>x.name===name);
      return !row||(row.value!==value&&row.value!==createHash('sha256').update(value).digest('hex'));
    });
    if(missing.length) {
      operation='SET_DEVELOPMENT_EDGE_EXPORT_SETTINGS';
      await supabase(`/v1/projects/${ref}/secrets`,{method:'POST',body:missing});
    }
    operation='DEPLOY_EXISTING_EDGE_HANDLER';resource=`projects/${ref}/functions/resume-export`;
    const form=new FormData();
    form.append('metadata',JSON.stringify({name:'resume-export',entrypoint_path:'index.ts',verify_jwt:true}));
    for(const name of ['index.ts','transport.mjs']) {
      form.append('file',new Blob([await readFile(`mobile/jobix/supabase/functions/resume-export/${name}`)],
        {type:name.endsWith('.ts')?'application/typescript':'application/javascript'}),name);
    }
    const result=await supabase(`/v1/projects/${ref}/functions/deploy?slug=resume-export`,
      {method:'POST',body:form});
    assert(result.slug==='resume-export'&&result.verify_jwt===true,'EDGE_VERIFICATION_METADATA_MISMATCH');
    console.log(JSON.stringify({operation,slug:result.slug,version:result.version,status:result.status,
      verifyJwt:true,exportsEnabled:false,gatewayUri:gateway.uri}));
    return;
  }
  const images=JSON.parse(await readFile('/tmp/jobix-readonly-built-images.json','utf8')).images;
  const pinned=component=>{
    const prefix=`${region}-docker.pkg.dev/${project}/jobix-dev/${component}:source-`;
    const image=images.find(x=>x.name.startsWith(prefix));
    assert(image&&/^sha256:[0-9a-f]{64}$/.test(image.digest),'PINNED_IMAGE_REQUIRED');
    return image.name.split(':')[0]+'@'+image.digest;
  };
  async function wait(op) {
    for(let i=0;i<60;i++){
      const status=await g.request('https://run.googleapis.com/v2/'+op.name);
      if(status.error)throw Error('CLOUD_RUN_OPERATION_FAILED_CODE_'+status.error.code);
      if(status.done)return;
      await sleep(5000);
    }
    throw Error('CLOUD_RUN_OPERATION_TIMEOUT');
  }
  const revisions=[];
  for(const [url,previous,identity,component] of [
    [workerUrl,worker,backend,'pdf-worker'],[gatewayUrl,gateway,gatewayIdentity,'export-gateway'],
  ]) {
    operation='PATCH_READONLY_'+component.toUpperCase();resource=previous.name;
    const containers=structuredClone(previous.template.containers),image=pinned(component);
    containers[0].image=image;
    await wait(await g.request(url+'?updateMask=template.containers',{
      method:'PATCH',write:true,body:{name:previous.name,etag:previous.etag,template:{containers}},
    }));
    const updated=await g.request(url);guard(updated,identity);
    assert(updated.latestReadyRevision===updated.latestCreatedRevision,'REVISION_NOT_READY');
    revisions.push({component,revision:updated.latestReadyRevision,image});
    console.log(JSON.stringify({operation,...revisions.at(-1),exportsEnabled:false}));
  }
  // One narrowly scoped public invoker member; preserve all existing bindings.
  operation='PUBLIC_INVOCATION_ON_AUTH_GATEWAY_ONLY';resource=gateway.name;
  const before=await g.request(gatewayUrl+':getIamPolicy?options.requestedPolicyVersion=3');
  assert(JSON.stringify(before.bindings??[])===JSON.stringify(gp.bindings??[]),'GATEWAY_POLICY_CHANGED_DURING_ROLLOUT');
  const policy=structuredClone(before);policy.version=3;policy.bindings??=[];
  let binding=policy.bindings.find(b=>b.role==='roles/run.invoker'&&!b.condition);
  if(!binding){binding={role:'roles/run.invoker',members:[]};policy.bindings.push(binding);}
  binding.members.push('allUsers');
  await g.request(gatewayUrl+':setIamPolicy',{method:'POST',write:true,body:{policy}});
  const [after,finalWorker,finalGateway]=await Promise.all([
    g.request(gatewayUrl+':getIamPolicy?options.requestedPolicyVersion=3'),
    g.request(workerUrl+':getIamPolicy?options.requestedPolicyVersion=3'),g.request(gatewayUrl),
  ]);
  assert(JSON.stringify(finalWorker.bindings??[])===JSON.stringify(wp.bindings??[]),'WORKER_IAM_CHANGED');
  assert(publicBindings(after).length===1&&publicBindings(after)[0].role==='roles/run.invoker'&&
    publicBindings(after)[0].members.includes('allUsers')&&
    !publicBindings(after)[0].members.includes('allAuthenticatedUsers'),'PUBLIC_GATEWAY_POLICY_MISMATCH');
  guard(finalGateway,gatewayIdentity);
  const r=await fetch(finalGateway.uri+'/ready',{signal:AbortSignal.timeout(30000),redirect:'error'});
  const ready=await r.json().catch(()=>null);
  assert(r.ok&&ready?.workerAuthenticationVerified&&ready.workerOnlyPathsDenied&&
    ready.exportsEnabled===false,'HOSTED_READONLY_BRIDGE_NOT_READY');
  await writeFile('/tmp/jobix-readonly-deployed.json',JSON.stringify({revisions,gatewayUri:gateway.uri,
    workerUri:worker.uri,exportsEnabled:false,workerPrivate:true,publicGatewayOnly:true},null,2));
  console.log(JSON.stringify({operation,revisions,publicGatewayOnly:true,workerPrivate:true,
    exportsEnabled:false,workerAuthenticationVerified:true,workerOnlyPathsDenied:true}));
}
main().catch(e=>{
  console.error(JSON.stringify({operation,resource,principal,status:e.status??null,
    permission:e.permission??null,reason:e.reason??null,code:e.message}));
  process.exitCode=1;
});
