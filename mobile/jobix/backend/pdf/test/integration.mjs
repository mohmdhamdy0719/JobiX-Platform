// Requires the guarded disposable runner. Never takes a live connection string.
import {spawnSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {Gateway} from '../gateway.mjs';
import {Worker} from '../worker.mjs';
import {Database} from '../database.mjs';
import {Canonicalizer,subprocess} from '../document.mjs';
import {containsText} from '../renderer.mjs';

const socket=process.env.JOBIX_DISPOSABLE_PG_SOCKET;
if(!socket?.startsWith('/tmp/jobix-rls.') || !socket.endsWith('/socket'))throw new Error('Disposable guard');
const environment={PATH:process.env.PATH,HOME:process.env.HOME,LANG:'C.UTF-8'};
function sql(statement) {
  const result=spawnSync('psql',['-X','-q','-A','-t','-U','runner','-h',socket,
    '-p','55439','-d','postgres','-v','ON_ERROR_STOP=1'],{
      input:statement,encoding:'utf8',env:environment,maxBuffer:16000000});
  if(result.status!==0)throw new Error(result.stderr.match(/ERROR:\s+([A-Z_]+)/)?.[1]??'DISPOSABLE_SQL_FAILURE');
  return result.stdout.trim();
}
const quote=value=>value==null?'NULL':"'"+String(value).replaceAll("'","''")+"'";
const db=new Database({query:async(statement,params)=>{
  const text=statement.replace(/\$(\d+)/g,(_,i)=>quote(params[Number(i)-1]));
  const json=text.replace('select public.','select to_jsonb(public.')
    .replace(' as result',') as result');
  return {rows:[{result:JSON.parse(sql(json)||'null')}]};
}});
const actor=randomUUID();
sql(`insert into auth.users(id,email) values(${quote(actor)},'synthetic@example.invalid');
 update export_settings set enabled=true,deletion_policy_approved=true;
 update profile_personal_data set full_name='Synthetic العربية',email='synthetic@example.invalid',
 phone='+20 100 000 0000' where profile_id=(select id from career_profiles where user_id=${quote(actor)});
 insert into profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current)
 select '${randomUUID()}',id,'Community مجموعة','Helper متطوع','2025-01-01',true from career_profiles where user_id=${quote(actor)};`);
const profile=sql(`select id from career_profiles where user_id=${quote(actor)}`);
const storageMap=new Map();let generation=0;
const storage={
 inspect:async(path,version)=>{const object=storageMap.get(path);return object&&(!version||object.generation===version)?object:null;},
 create:async(path,pdf,metadata)=>{
  assert.ok(!storageMap.has(path));
  const object={generation:String(++generation),contentType:'application/pdf',
    metadata,timeCreated:new Date().toISOString(),bytes:pdf};
  storageMap.set(path,object);return object;
 },
 read:async(path)=>storageMap.get(path).bytes,
 sign:async(path,version)=>`https://example.invalid/synthetic?generation=${version}`,
};
let expected;
const renderer={
 render:async html=>{
  const result=JSON.parse(await subprocess('python3',
    [resolve(import.meta.dirname,'print_fixture.py')],html,{maxBytes:8000000}));
  expected=result.text;return Buffer.from(result.pdf,'base64');
 },
 validate:async pdf=>{
  const dir=await mkdtemp(tmpdir()+'/jobix-verify-');
  try {
   await writeFile(dir+'/doc.pdf',pdf);
   const info=(await subprocess('pdfinfo',[dir+'/doc.pdf'])).toString();
   const actual=(await subprocess('pdftotext',['-enc','UTF-8',dir+'/doc.pdf','-'])).toString();
   assert.ok(containsText(actual,expected));
   return Number(info.match(/^Pages:\s+(\d+)/m)[1]);
  }finally{await rm(dir,{recursive:true,force:true});}
 },
};
const gateway=new Gateway({enabled:true,db,storage,canonicalizer:new Canonicalizer()});
const document=await gateway.handle(actor,'document',{profile_id:profile});
assert.deepEqual(document.issues,[]);
assert.ok(document.html.includes('Volunteer Experience'));
const packet={request_id:randomUUID(),idempotency_key:randomUUID(),
 expected_profile_version:document.profile_version,payload:{profile_id:profile,
 expected_configuration_version:document.configuration_version,
 expected_document_sha256:document.document_sha256,renderer_bundle_version:document.bundle}};
const ack=await gateway.handle(actor,'create',packet);
await new Worker({enabled:true,db,storage,renderer}).dispatch();
assert.equal((await gateway.handle(actor,'status',{export_id:ack.operation_id})).state,'COMPLETED');
assert.deepEqual(await gateway.handle(actor,'create',{...packet,request_id:randomUUID()}),ack);
await gateway.handle(actor,'download',{export_id:ack.operation_id});
await gateway.handle(actor,'download',{export_id:ack.operation_id});
assert.equal(sql(`select finalized_balance||','||reserved_balance from credit_accounts where user_id=${quote(actor)}`),'3,0');
assert.equal(sql(`select count(*) from credit_transactions where user_id=${quote(actor)} and delta=-2`),'1');
assert.equal(sql(`select count(*) from ai_allowance_accounts where user_id=${quote(actor)}`),'0');
sql('update export_settings set enabled=false,deletion_policy_approved=false');
console.log('PASS: real disposable SQL + server canonical Dart HTML + actual local Chromium PDF + verified text + one debit + free repeat download. Storage is an explicit in-memory test adapter, not GCS.');
