// Owner-approved removal of ONE principal's obsolete development bucket role.
import {google,project,projectNumber,bucket,backend} from './phase3_google.mjs';
const member=`serviceAccount:${backend}`;
const custom=`projects/${project}/roles/jobixExportObjectAccess`;
export function narrow(policy) {
 if(!policy.bindings?.some(b=>b.role===custom&&!b.condition&&b.members?.includes(member)))
  throw Error('RETAINED_CUSTOM_BINDING_REQUIRED');
 return {...policy,bindings:policy.bindings.flatMap(binding=>{
  if(binding.role!=='roles/storage.objectUser'||!binding.members.includes(member))return [binding];
  const members=binding.members.filter(value=>value!==member);
  return members.length?[{...binding,members}]:[];
 })};
}
function canonical(value) {
 if(Array.isArray(value))return value.map(canonical).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
 if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])]));
 return value;
}
const bindingsMatch=(left,right)=>JSON.stringify(canonical(left.bindings))===JSON.stringify(canonical(right.bindings));
async function main() {
 if(!process.argv.includes('--approved-backend-objectuser-removal')) {
  console.error('EXPLICIT_OWNER_GRANT_REMOVAL_APPROVAL_REQUIRED');process.exitCode=1;return;
 }
 const g=await google();
 const metadata=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}`);
 if(String(metadata.projectNumber)!==projectNumber||!metadata.iamConfiguration?.uniformBucketLevelAccess?.enabled)
  throw Error('DEV_PRIVATE_BUCKET_GUARD');
 const url=`https://storage.googleapis.com/storage/v1/b/${bucket}/iam`;
 const original=await g.request(url+'?optionsRequestedPolicyVersion=3');
 if(!original.etag||original.bindings?.some(b=>b.members.some(m=>['allUsers','allAuthenticatedUsers'].includes(m))))
  throw Error('POLICY_PRIVATE_ETAG_REQUIRED');
 const desired=narrow(original);
 if(!bindingsMatch(original,desired)){
  // Preserve the fetched etag/version/conditions and reject concurrent changes.
  await g.request(url+`?ifMetagenerationMatch=${metadata.metageneration}`,
   {method:'PUT',write:true,body:desired});
 }
 const after=await g.request(url+'?optionsRequestedPolicyVersion=3');
 if(!bindingsMatch(desired,after))throw Error('POLICY_READBACK_DIFFERENCE');
 console.log('PASS: ONLY_BACKEND_OBSOLETE_OBJECTUSER_MEMBERSHIP_REMOVED_OTHER_BINDINGS_PRESERVED');
 const token=await g.impersonate();
 const r=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/iam/testPermissions?`+
 ['create','get','list','delete','update','restore','move'].map(p=>'permissions=storage.objects.'+p).join('&'),{token});
 const permissions=[...(r.permissions??[])].sort();
 const required=['create','get','list','delete'].map(p=>'storage.objects.'+p).sort();
 console.log(JSON.stringify({check:'BACKEND_EFFECTIVE_BUCKET_SCOPE_READBACK',permissions,
  exact_approved_four:JSON.stringify(permissions)===JSON.stringify(required)}));
 if(!required.every(p=>permissions.includes(p)))throw Error('REQUIRED_PERMISSION_MISSING_NO_WORKER_START');
}
if(process.argv[1]===import.meta.filename)main().catch(error=>{
 console.error(JSON.stringify({check:'SCOPED_BUCKET_IAM_CLEANUP_BLOCKED',status:error.status??0,
  code:['RETAINED_CUSTOM_BINDING_REQUIRED','DEV_PRIVATE_BUCKET_GUARD','POLICY_PRIVATE_ETAG_REQUIRED',
   'POLICY_READBACK_DIFFERENCE','REQUIRED_PERMISSION_MISSING_NO_WORKER_START'].includes(error.message)?error.message:null}));
 process.exitCode=1;
});
