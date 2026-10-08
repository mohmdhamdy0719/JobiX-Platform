// Explicitly approved DEVELOPMENT expiry only. Preserve unrelated bucket rules.
import {google,project,bucket,backend} from './phase3_google.mjs';
if(!process.argv.includes('--approved-scoped-expiry')) {
  console.error('SCOPED_EXPIRY_APPROVAL_REQUIRED');process.exit(1);
}
const g=await google();
try {
  const metadata=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}`);
  const policy=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/iam`);
  if(!metadata.iamConfiguration?.uniformBucketLevelAccess?.enabled||
    policy.bindings?.some(binding=>binding.members?.some(member=>['allUsers','allAuthenticatedUsers'].includes(member)))) {
    throw Error('PRIVATE_BUCKET_VERIFICATION_FAILED');
  }
  const rule={action:{type:'Delete'},condition:{age:7,matchesPrefix:['exports/'],matchesSuffix:['.pdf']}};
  const matches=item=>item.action?.type==='Delete'&&item.condition?.age===7&&
    item.condition.matchesPrefix?.length===1&&item.condition.matchesPrefix[0]==='exports/'&&
    item.condition.matchesSuffix?.length===1&&item.condition.matchesSuffix[0]==='.pdf';
  const rules=metadata.lifecycle?.rule??[];
  if(!rules.some(matches)) {
    await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}?ifMetagenerationMatch=${metadata.metageneration}`,
      {method:'PATCH',write:true,body:{lifecycle:{rule:[...rules,rule]}}});
  }
  const verified=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}`);
  if(!verified.lifecycle?.rule?.some(matches))throw Error('EXPIRY_READBACK_FAILED');
  console.log('DEV_PRIVATE_BUCKET_SCOPED_SEVEN_DAY_PDF_EXPIRY_VERIFIED');
  // Necessary four-permission custom role; never grant a broader predefined role.
  const roleId='jobixDevPdfObjects',name=`projects/${project}/roles/${roleId}`;
  let role;
  try {role=await g.request(`https://iam.googleapis.com/v1/${name}`);}
  catch(error) {
    if(error.status!==404&&error.status!==403)throw error;
    role=await g.request(`https://iam.googleapis.com/v1/projects/${project}/roles`,
      {method:'POST',write:true,body:{roleId,role:{title:'Jobix development PDF objects',
        description:'Only the private development PDF worker object operations',
        includedPermissions:['storage.objects.create','storage.objects.get','storage.objects.list','storage.objects.delete'],stage:'GA'}}});
  }
  const required=['storage.objects.create','storage.objects.get','storage.objects.list','storage.objects.delete'];
  if(role.deleted||JSON.stringify([...(role.includedPermissions??[])].sort())!==JSON.stringify(required.sort()))throw Error('ROLE_SCOPE_REJECTED');
  const existing=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/iam`);
  const bindings=existing.bindings??[];
  const target=bindings.find(binding=>binding.role===name&&!binding.condition);
  if(target)target.members=[...new Set([...target.members,`serviceAccount:${backend}`])];
  else bindings.push({role:name,members:[`serviceAccount:${backend}`]});
  await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/iam`,
    {method:'PUT',write:true,body:{...existing,bindings}});
  console.log('DEV_BACKEND_EXACT_FOUR_PERMISSION_BUCKET_ROLE_CONFIGURED');
}catch(error) {
  console.error(JSON.stringify({operation:'DEV_BUCKET_SETUP_BLOCKED',status:error.status??0,
    permission:error.permission??null,code:['PRIVATE_BUCKET_VERIFICATION_FAILED','EXPIRY_READBACK_FAILED','ROLE_SCOPE_REJECTED'].includes(error.message)?error.message:null}));
  process.exitCode=1;
}
