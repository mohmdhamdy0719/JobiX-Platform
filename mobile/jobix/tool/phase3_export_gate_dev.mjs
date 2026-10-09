// Existing development gates only. No image builds, IAM/identity/secret edits.
import {google,project,region,backend} from './phase3_google.mjs';
const gatewayIdentity='jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const assert=(v,c)=>{if(!v)throw Error(c);};
export async function exportGates() {
  const g=await google(),base=`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services/`;
  async function service(name,identity) {
    const url=base+name,s=await g.request(url);
    assert(s.template.serviceAccount===identity&&!s.invokerIamDisabled,'IDENTITY_IAM_GUARD');
    const env=s.template.containers[0].env;
    assert(env.find(x=>x.name==='JOBIX_EXPORT_DELETION_POLICY_APPROVED')?.value==='true','APPROVED_POLICY_GUARD');
    return {url,s};
  }
  const w=await service('jobix-dev-pdf-export',backend),b=await service('jobix-dev-export-gateway',gatewayIdentity);
  const wp=await g.request(w.url+':getIamPolicy');
  assert(!(wp.bindings??[]).some(x=>x.members?.some(m=>['allUsers','allAuthenticatedUsers'].includes(m))),
    'PRIVATE_WORKER_REQUIRED');
  for(const {s}of [w,b])assert(s.template.containers[0].env.find(e=>e.name==='JOBIX_EXPORT_ENABLED')?.value==='false',
    'GATES_MUST_START_CLOSED');
  async function edge(enabled) {
    const r=await fetch('https://api.supabase.com/v1/projects/lmouxhbjhtqdtiqijcee/secrets',{
      method:'POST',headers:{Authorization:'Bearer '+process.env.JOBIX_DEV_SUPABASE_ACCESS_TOKEN,
        'Content-Type':'application/json'},body:JSON.stringify([{name:'JOBIX_EXPORT_ENABLED',value:String(enabled)}]),
      signal:AbortSignal.timeout(30000),redirect:'error'});
    assert(r.ok,'EDGE_GATE_UPDATE_REJECTED_'+r.status);
  }
  async function change(name,identity,enabled) {
    const {url,s}=await service(name,identity),containers=structuredClone(s.template.containers);
    containers[0].env.find(e=>e.name==='JOBIX_EXPORT_ENABLED').value=String(enabled);
    const op=await g.request(url+'?updateMask=template.containers',{method:'PATCH',write:true,
      body:{name:s.name,etag:s.etag,template:{containers}}});
    let done=false;
    for(let i=0;i<60;i++){
      const status=await g.request('https://run.googleapis.com/v2/'+op.name);
      assert(!status.error,'GATE_REVISION_FAILED');
      if(status.done){done=true;break;}await sleep(5000);
    }
    assert(done,'GATE_OPERATION_TIMEOUT');
    const current=(await service(name,identity)).s;
    assert(current.latestReadyRevision===current.latestCreatedRevision,'GATE_REVISION_NOT_READY');
    assert(current.template.containers[0].env.find(e=>e.name==='JOBIX_EXPORT_ENABLED')?.value===String(enabled),
      'GATE_VALUE_NOT_APPLIED');
    console.log(JSON.stringify({service:name,exportsEnabled:enabled,revision:current.latestReadyRevision.split('/').at(-1)}));
  }
  const scheduler=`https://cloudscheduler.googleapis.com/v1/projects/${project}/locations/${region}/jobs/jobix-dev-pdf-export-recovery`;
  const job=await g.request(scheduler);
  assert(job.state==='ENABLED'&&job.httpTarget?.uri===w.s.uri+'/recover'&&
    job.httpTarget?.oidcToken?.serviceAccountEmail===`jobix-scheduler-dev@${project}.iam.gserviceaccount.com`,
    'EXISTING_SCHEDULER_NOT_READY');
  return {
    gatewayUri:b.s.uri,workerUri:w.s.uri,
    async open(){
      await change('jobix-dev-pdf-export',backend,true);
      await change('jobix-dev-export-gateway',gatewayIdentity,true);
      await edge(true);
    },
    async close(){
      const errors=[];
      for(const fn of [
        ()=>edge(false),()=>change('jobix-dev-export-gateway',gatewayIdentity,false),
        ()=>change('jobix-dev-pdf-export',backend,false),
      ]){try{await fn();}catch{errors.push('GATE_CLOSE_FAILED');}}
      assert(errors.length===0,'GATE_CLOSE_UNVERIFIED');
    },
    async dispatch(){await g.request(scheduler+':run',{method:'POST',write:true,body:{}});},
  };
}
