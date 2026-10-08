// Isolated development storage/signing test under the actual backend identity.
// This is not proof of Cloud Run metadata identity or PDF generation.
import {randomUUID,createHash} from 'node:crypto';
import {google,bucket,projectNumber} from './phase3_google.mjs';
import {GoogleStorage} from '../backend/pdf/google.mjs';
if(!process.argv.includes('--approved-isolated-runtime-storage-fixture')) {
 console.error('EXPLICIT_ISOLATED_FIXTURE_APPROVAL_REQUIRED');process.exit(1);
}
const g=await google(),b=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}`);
if(String(b.projectNumber)!==projectNumber)throw Error('DEV_PROJECT_REJECTED');
const token=await g.impersonate();
const storage=new GoogleStorage({token:async()=>token});
const actor=randomUUID(),operation=randomUUID();
const bytes=Buffer.from('%PDF-synthetic-backend-protocol-fixture');
const hash=createHash('sha256').update(bytes).digest('hex');
const path=`exports/${actor}/${operation}/${hash}.pdf`,purpose='phase3-isolated-runtime-storage-test';
const assert=condition=>{if(!condition)throw Error('ASSERTION_FAILED');};
let generation,stage='create';
try {
 const object=await storage.create(path,bytes,{purpose,fixture_id:operation});
 generation=String(object.generation);
 let duplicate=false;try{await storage.create(path,bytes,{purpose,fixture_id:operation});}
 catch(error){duplicate=error.code==='OBJECT_EXISTS';}assert(duplicate);
 stage='inspect-and-read';
 assert((await storage.inspect(path,generation)).metadata.fixture_id===operation);
 assert((await storage.read(path,generation)).equals(bytes));
 stage='self-sign-and-download';
 const signed=await storage.sign(path,generation,30);
 const response=await fetch(signed,{redirect:'error',signal:AbortSignal.timeout(15000)});
 assert(response.status===200&&Buffer.from(await response.arrayBuffer()).equals(bytes));
 const tampered=new URL(signed);tampered.searchParams.set('generation',String(BigInt(generation)+1n));
 const invalid=await fetch(tampered,{redirect:'error',signal:AbortSignal.timeout(15000)});
 assert(invalid.status===403);
 stage='anonymous-denial';
 const publicRead=await fetch(`https://storage.googleapis.com/${bucket}/${path}`,{signal:AbortSignal.timeout(15000)});
 assert([401,403].includes(publicRead.status));
 console.log('PASS: ACTUAL_BACKEND_CONDITIONAL_CREATE_READ_SELF_SIGN_PRIVATE_DOWNLOAD_GENERATION_BINDING');
 // Never print or persist the signed URL/token/signature.
}catch(error){
 console.error(JSON.stringify({check:'BACKEND_STORAGE_FIXTURE_FAILED',stage,
 code:['OBJECT_EXISTS','SERVICE_UNAVAILABLE','FORBIDDEN','ASSERTION_FAILED'].includes(error.code??error.message)?
 error.code??error.message:'SUPPRESSED'}));process.exitCode=1;
}finally{
 try{
  const object=await storage.inspect(path);
  if(object){
   assert(object.metadata?.purpose===purpose&&object.metadata?.fixture_id===operation);
   generation=String(object.generation);await storage.remove(path,generation);
  }
  assert((await storage.listPrefix(`exports/${actor}/`)).length===0);
  console.log('PASS: OWNED_RUNTIME_FIXTURE_EXACT_GENERATION_CLEANUP_AND_ABSENCE');
 }catch{console.error('FAIL: RUNTIME_FIXTURE_CLEANUP_UNVERIFIED');process.exitCode=1;}
}
