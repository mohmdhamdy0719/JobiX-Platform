// Exactly one owner-approved private gateway revision: diagnostic or tested fix.
import {readFile,writeFile} from 'node:fs/promises';
import {google,project,region} from './phase3_google.mjs';
import {gatewayIdentity} from '../backend/export-gateway/core.mjs';

let operation='PRIVATE_GATEWAY_PRECONDITIONS';
const resource=`projects/${project}/locations/${region}/services/jobix-dev-export-gateway`;
async function main() {
  const diagnostic=process.argv.includes('--approved-one-private-diagnostic-revision');
  const controlledFix=process.argv.includes('--approved-one-development-gateway-fix');
  if(diagnostic===controlledFix)throw Error('EXACTLY_ONE_EXPLICIT_APPROVAL_REQUIRED');
  const result=JSON.parse(await readFile(controlledFix?
    '/tmp/jobix-gateway-fix-image.json':'/tmp/jobix-gateway-diagnostic-image.json','utf8'));
  const image=result.images?.[0];
  if(result.images?.length!==1||
    !image.name.startsWith(`${region}-docker.pkg.dev/${project}/jobix-dev/export-gateway:source-`)||
    !/^sha256:[0-9a-f]{64}$/.test(image.digest))throw Error('GATEWAY_ONLY_PINNED_IMAGE_REQUIRED');
  const g=await google();
  if(g.principal!=='jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com')throw Error('EXPECTED_DEPLOYER_REQUIRED');
  const url='https://run.googleapis.com/v2/'+resource;
  const service=await g.request(url),policy=await g.request(url+':getIamPolicy');
  const expected=controlledFix?'jobix-dev-export-gateway-00002-cf9':'jobix-dev-export-gateway-00001-kqh';
  if(service.latestCreatedRevision?.split('/').at(-1)!==expected) {
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
  operation=controlledFix?'PATCH_ONE_TESTED_DEVELOPMENT_GATEWAY_FIX':'PATCH_ONE_PRIVATE_DIAGNOSTIC_REVISION';
  const op=await g.request(url+'?updateMask=template.containers',{
    method:'PATCH',write:true,body:{name:resource,etag:service.etag,template:{containers}}});
  for(let i=0;i<48;i++) {
    const r=await g.request('https://run.googleapis.com/v2/'+op.name);
    if(r.done) {
      const updated=await g.request(url);
      const evidence={operation,resource,revision:updated.latestCreatedRevision,
        readyRevision:updated.latestReadyRevision??null,image:containers[0].image,
        uri:updated.uri??null,
        private:true,exportsEnabled:false,deletionPolicyApproved:true,
        operationErrorCode:r.error?.code??null,
        terminalReason:updated.terminalCondition?.revisionReason??updated.terminalCondition?.reason??null};
      console.log(JSON.stringify(evidence));
      if(controlledFix) {
        await writeFile('/tmp/jobix-gateway-fix-deployment.json',JSON.stringify(evidence));
        if(r.error||updated.latestReadyRevision!==updated.latestCreatedRevision) {
          process.exitCode=1;
          try {
            const logs=await g.request('https://logging.googleapis.com/v2/entries:list',{method:'POST',
              body:{resourceNames:['projects/'+project],filter:'resource.type="cloud_run_revision" AND '+
                'resource.labels.revision_name="'+updated.latestCreatedRevision.split('/').at(-1)+'"',
                orderBy:'timestamp desc',pageSize:10}});
            console.log(JSON.stringify({startupErrors:(logs.entries??[]).map(e=>e.jsonPayload)
              .filter(e=>e?.event==='DEVELOPMENT_EXPORT_GATEWAY_NOT_READY')
              .map(e=>({stage:e.stage,code:e.code,status:e.status}))}));
          }catch(error){console.log(JSON.stringify({startupLogReadDenied:true,status:error.status??null}));}
        }
      }
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
