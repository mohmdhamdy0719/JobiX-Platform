// Requires the guarded disposable runner. Never takes a live connection string.
import {spawnSync,spawn} from 'node:child_process';
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
import {ExportCleanup} from '../cleanup.mjs';

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
const frozen=JSON.parse(sql(`select to_jsonb(s) from export_snapshots s
 where id=${quote(ack.data.snapshot_id)}`));
assert.equal(frozen.asset_manifest.font_checksums.length,2);
assert.equal(frozen.asset_manifest.licenses.length,2);
assert.equal(frozen.canonical_html,document.html);

// True concurrent connections (not a sequential JavaScript mock).
function concurrent(statement) {
 return new Promise((resolve,reject)=>{
  const child=spawn('psql',['-X','-q','-A','-t','-U','runner','-h',socket,
   '-p','55439','-d','postgres','-v','ON_ERROR_STOP=1'],{env:environment});
  const chunks=[];child.stdout.on('data',chunk=>chunks.push(chunk));child.stderr.resume();
  child.on('error',reject);child.on('close',code=>code===0?resolve(Buffer.concat(chunks).toString().trim()):
   reject(new Error('DISPOSABLE_CONCURRENT_SQL_FAILURE')));
  child.stdin.end(statement);
 });
}
const retryKey=randomUUID(),requestHash='d'.repeat(64);
const source=await db.call('source',{actor,profile});
const createSQL=`select public.jobix_export_create(${[
 actor,retryKey,randomUUID(),profile,document.profile_version,document.configuration_version,
 source.source_sha256,document.document_sha256,requestHash,document.html,document.bundle,
 null,JSON.stringify(document.asset_manifest)].map(quote).join(',')})`;
const raced=await Promise.all([concurrent(createSQL),concurrent(createSQL)]);
assert.deepEqual(JSON.parse(raced[0]),JSON.parse(raced[1]));
const second=JSON.parse(raced[0]);
assert.equal(sql(`select count(*) from export_jobs where user_id=${quote(actor)}`),'2');
assert.equal(sql(`select finalized_balance||','||reserved_balance from credit_accounts where user_id=${quote(actor)}`),'3,2');
let claimed=await db.call('claim',{capacity:1});
await db.call('finish',{operation:second.operation_id,fence:claimed[0].lease_token,proof:null,terminal:true});
await db.call('finish',{operation:second.operation_id,fence:claimed[0].lease_token,proof:null,terminal:true});
assert.equal(sql(`select finalized_balance||','||reserved_balance from credit_accounts where user_id=${quote(actor)}`),'3,0');

// Inject failure halfway through finalization to prove job/ledger atomic rollback.
const again=await gateway.handle(actor,'again',{...packet,request_id:randomUUID(),idempotency_key:randomUUID(),
 payload:{...packet.payload,historical_export_id:ack.operation_id}});
claimed=await db.call('claim',{capacity:1});
const live=claimed[0],fence=live.lease_token;
await db.call('stage',{operation:live.id,fence,stage:'GENERATING'});
await db.call('stage',{operation:live.id,fence,stage:'UPLOADING'});
const proof={path:`exports/${actor}/${live.id}/${source.source_sha256}.pdf`,generation:'99',
 pdf_sha256:'e'.repeat(64),document_sha256:document.document_sha256,pages:1,size:100,
 content_type:'application/pdf',created_at:new Date().toISOString()};
sql(`create function public.test_export_rollback() returns trigger language plpgsql as $$
 begin if NEW.state='COMPLETED' then raise exception 'SYNTHETIC_ROLLBACK';end if;return NEW;end $$;
 create trigger test_export_rollback before update on export_jobs for each row execute function public.test_export_rollback();`);
await assert.rejects(db.call('finish',{operation:live.id,fence,proof,terminal:false}));
assert.equal(sql(`select count(*) from credit_transactions where user_id=${quote(actor)} and delta=-2`),'1');
assert.equal(sql(`select state from credit_reservations where id=${quote(live.reservation_id)}`),'PENDING');
assert.equal((await db.call('status',{actor,operation:live.id})).state,'UPLOADING');
sql('drop trigger test_export_rollback on export_jobs;drop function public.test_export_rollback()');
await db.call('finish',{operation:live.id,fence,proof,terminal:false});
await db.call('finish',{operation:live.id,fence,proof,terminal:false});
assert.equal(sql(`select count(*) from credit_transactions where user_id=${quote(actor)} and delta=-2`),'2');

// Verified seven-day expiry removes the PDF only, preserving history/snapshot/dedupe.
sql(`update export_jobs set expires_at=now()-interval '1 second' where id=${quote(ack.operation_id)}`);
storage.remove=async(path,generation)=>{
 assert.equal(storageMap.get(path).generation,generation);storageMap.delete(path);
};
await new ExportCleanup({db,storage,enabled:true}).retention();
assert.equal((await gateway.handle(actor,'status',{export_id:ack.operation_id})).state,'EXPIRED');
assert.equal(sql(`select count(*) from export_snapshots where user_id=${quote(actor)}`),'3');
assert.deepEqual(await gateway.handle(actor,'create',packet),ack);
assert.equal(sql(`select count(*) from credit_transactions where user_id=${quote(actor)} and delta=-2`),'2');
// A real canonical long CV exceeds twenty pages: fail before upload or debit.
const largeActor=randomUUID();
sql(`insert into auth.users(id,email) values(${quote(largeActor)},'large@example.invalid');
 update profile_personal_data set full_name='Long Fixture',email='large@example.invalid',
 phone='+20 100 000 0000' where profile_id=(select id from career_profiles where user_id=${quote(largeActor)});
 insert into profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current,description,sort_order)
 select gen_random_uuid(),p.id,'Community','Helper','2025-01-01',true,
 repeat('Meaningful synthetic evidence with searchable text. ',24),n
 from career_profiles p cross join generate_series(1,90) n where p.user_id=${quote(largeActor)};`);
const largeProfile=sql(`select id from career_profiles where user_id=${quote(largeActor)}`);
const largeDocument=await gateway.handle(largeActor,'document',{profile_id:largeProfile});
assert.deepEqual(largeDocument.issues,[]);
const largeAck=await gateway.handle(largeActor,'create',{request_id:randomUUID(),idempotency_key:randomUUID(),
 expected_profile_version:largeDocument.profile_version,payload:{
 profile_id:largeProfile,expected_configuration_version:largeDocument.configuration_version,
 expected_document_sha256:largeDocument.document_sha256,renderer_bundle_version:largeDocument.bundle}});
const uploadsBefore=storageMap.size;
await new Worker({enabled:true,db,storage,renderer}).dispatch();
assert.equal((await gateway.handle(largeActor,'status',{export_id:largeAck.operation_id})).state,'FAILED');
assert.equal(storageMap.size,uploadsBefore);
assert.equal(sql(`select finalized_balance||','||reserved_balance from credit_accounts where user_id=${quote(largeActor)}`),'5,0');
assert.equal(sql(`select count(*) from credit_transactions where user_id=${quote(largeActor)} and delta=-2`),'0');
sql('update export_settings set enabled=false,deletion_policy_approved=false');
console.log('PASS: disposable SQL + canonical Dart/Chromium PDF + concurrent replay + atomic rollback + duplicate callback + Export Again + retention + real >20-page rejection before upload/debit. Storage is in-memory, not GCS.');
