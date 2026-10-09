// Exactly one owner-approved private diagnostic gateway revision.
import {readFile} from 'node:fs/promises';
import {google,project,region} from './phase3_google.mjs';
import {gatewayIdentity} from '../backend/export-gateway/core.mjs';

let operation='PRIVATE_DIAGNOSTIC_PRECONDITIONS';
const resource=`projects/${project}/locations/${region}/services/jobix-dev-export-gateway`;
async function main() {
  if(!process.argv.includes('--approved-one-private-diagnostic-revision'))throw Error('EXPLICIT_APPROVAL_REQUIRED');
  const result=JSON.parse(await readFile('/tmp/jobix-gateway-diagnostic-image.json','utf8'));
  const image=result.images?.[0];
  if(result.images?.length!==1||
    !image.name.startsWith(`${region}-docker.pkg.dev/${project}/jobix-dev/export-gateway:source-`)||
    !/^sha256:[0-9a-f]{64}$/.test(image.digest))throw Error('GATEWAY_ONLY_PINNED_IMAGE_REQUIRED');
  const g=await google();
  if(g.principal!=='jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com')throw Error('EXPECTED_DEPLOYER_REQUIRED');
  const url='https://run.googleapis.com/v2/'+resource;
  const service=await g.request(url),policy=await g.request(url+':getIamPolicy');
  if(service.latestCreatedRevision?.split('/').at(-1)!=='jobix-dev-export-gateway-00001-kqh') {
    throw Error('EXPECTED_FAILED_REVISION_CHANGED');
  }
  if(service.invokerIamDisabled||policy.bindings?.some(b=>b.members?.some(m=>
    ['allUsers','allAuthenticatedUsers'].includes(m))))throw Error('PRIVATE_GATEWAY_REQUIRED');
  if(service.template.serviceAccount!==gatewayIdentity)throw Error('ATTACHED_IDENTITY_CHANGED');
  const containers=structuredClone(service.template.containers);
  const flags=Object.fromEntries(containers[0].env.map(e=>[e.name,e.value]));
  if(flags.JOBIX_EXPORT_ENABLED!=='false'||flags.JOBIX_EXPORT_DELETION_POLICY_APPROVED!=='true') {
    throw Error('EXPECTED_CLOSED_GATE_AND_APPROVED_POLICY_REQUIRED');
  }
  containers[0].image=image.name.split(':')[0]+'@'+image.digest;
  operation='PATCH_ONE_PRIVATE_DIAGNOSTIC_REVISION';
  const op=await g.request(url+'?updateMask=template.containers',{
    method:'PATCH',write:true,body:{name:resource,etag:service.etag,template:{containers}}});
  for(let i=0;i<48;i++) {
    const r=await g.request('https://run.googleapis.com/v2/'+op.name);
    if(r.done) {
      const updated=await g.request(url);
      console.log(JSON.stringify({operation,resource,revision:updated.latestCreatedRevision,
        readyRevision:updated.latestReadyRevision??null,image:containers[0].image,
        private:true,exportsEnabled:false,deletionPolicyApproved:true,
        operationErrorCode:r.error?.code??null,
        terminalReason:updated.terminalCondition?.revisionReason??updated.terminalCondition?.reason??null}));
      return;
    }
    await new Promise(resolve=>setTimeout(resolve,5000));
  }
  throw Error('DIAGNOSTIC_OPERATION_PENDING_DO_NOT_RETRY');
}
main().catch(error=>{
  console.error(JSON.stringify({operation,resource,principal:'jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com',
    code:error.message,status:error.status??null,permission:error.permission??null}));
  process.exitCode=1;
});
