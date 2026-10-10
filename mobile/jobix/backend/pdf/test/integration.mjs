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
import {ExportError} from '../document.mjs';
import {GoogleStorage} from '../google.mjs';

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
assert.equal(sql(`select count(*) from export_cost_reservations where operation=${quote(ack.operation_id)}`),'1');
const replay=await gateway.handle(actor,'create',packet);
assert.equal(replay.operation_id,ack.operation_id);
assert.equal(sql(`select count(*) from export_cost_reservations where operation=${quote(ack.operation_id)}`),'1');
await new Worker({enabled:true,db,storage,renderer}).dispatch();
const costState=sql(`select json_build_object('reservation',r.state,
 'unknown_prior_attempts',r.unknown_prior_attempts,'model_version',r.model_version,
 'policy_version',p.model_version,'job',j.state,
 'attempts',(select json_agg(json_build_object('finished',a.finished_at,
   'runtime_ms',a.runtime_ms,'pdf_bytes',a.pdf_bytes,'storage_operations',a.storage_operations))
  from export_cost_attempts a where a.operation=r.operation),
 'uploads',(select json_agg(f.state) from export_upload_flights f where f.operation=r.operation))
 from export_cost_reservations r cross join export_cost_budget_policy p
 join export_jobs j on j.id=r.operation where p.singleton and r.operation=${quote(ack.operation_id)}`);
assert.match(sql(`select state||':'||settled_microusd from export_cost_reservations where operation=${quote(ack.operation_id)}`),
  /^SETTLED:[1-9][0-9]*$/,`worker settlement failed; state=${costState}`);
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
   const chunks=[],errors=[];child.stdout.on('data',chunk=>chunks.push(chunk));
   child.stderr.on('data',chunk=>errors.push(chunk));
   child.on('error',reject);child.on('close',code=>code===0?resolve(Buffer.concat(chunks).toString().trim()):
    reject(new Error(`DISPOSABLE_CONCURRENT_SQL_FAILURE: ${Buffer.concat(errors).toString().trim()}`)));
  child.stdin.end(statement);
 });
}
// Isolate the concurrency/replay fixture from the earlier completed test job;
// admission behavior itself is exercised with dedicated SQL window fixtures.
sql(`update export_admission_events set accepted_at=now()-interval '8 days' where user_id=${quote(actor)}`);
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

// Distinct simultaneous intents for one profile must accept only one request.
// Move earlier fixture events out of the windows so this checks active exclusion.
sql(`update export_admission_events set accepted_at=now()-interval '8 days' where user_id=${quote(actor)}`);
sql(`create function public.test_export_admission_create(k uuid,r uuid) returns text
 language plpgsql as $$
 declare ack jsonb; message text; detail text;
 begin
  begin
   ack:=public.jobix_export_create(${quote(actor)},k,r,${quote(profile)},
    ${document.profile_version},${document.configuration_version},
    ${quote(source.source_sha256)},${quote(document.document_sha256)},${quote('e'.repeat(64))},
    ${quote(document.html)},${quote(document.bundle)},null,
    ${quote(JSON.stringify(document.asset_manifest??{}))}::jsonb);
   return 'ACCEPTED:'||(ack->>'operation_id');
  exception when others then
   get stacked diagnostics message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL;
   return 'REJECTED:'||message||':'||coalesce(detail,'');
  end;
 end $$`);
 const createAttempt=()=>`select public.test_export_admission_create(${quote(randomUUID())},${quote(randomUUID())})`;
 const activeIntentRace=await Promise.all([concurrent(createAttempt()),concurrent(createAttempt())]);
 assert.equal(activeIntentRace.filter(x=>x.startsWith('ACCEPTED:')).length,1);
 assert.equal(activeIntentRace.filter(x=>x.startsWith('REJECTED:EXPORT_IN_PROGRESS:')).length,1);
 assert.equal(sql(`select count(*) from export_admission_events where user_id=${quote(actor)}
  and accepted_at>now()-interval '7 days'`),'1');
 assert.equal(sql(`select finalized_balance||','||reserved_balance from credit_accounts where user_id=${quote(actor)}`),'3,2');
 sql('drop function public.test_export_admission_create(uuid,uuid)');
claimed=await db.call('claim',{capacity:1});
await db.call('finish',{operation:claimed[0].id,fence:claimed[0].lease_token,proof:null,terminal:true});

// Inject failure halfway through finalization to prove job/ledger atomic rollback.
// This is a separate Export Again lifecycle assertion, so age the accepted test
// event past all windows instead of weakening admission for actual requests.
sql(`update export_admission_events set accepted_at=now()-interval '8 days' where user_id=${quote(actor)}`);
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
assert.equal(sql(`select count(*) from export_snapshots where user_id=${quote(actor)}`),'4');
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

// Focused acceptance fixtures: actual lifecycle/ledger SQL, injected renderer
// and storage failures only. No live credentials, GCS or paid export are used.
async function acceptanceFixture() {
 const a=randomUUID();
 sql(`insert into auth.users(id,email) values(${quote(a)},'fault-${a}@example.invalid');
 update export_settings set enabled=true,deletion_policy_approved=true;
 update profile_personal_data set full_name='Fault Fixture',email='fixture@example.invalid',
 phone='+12025550147' where profile_id=(select id from career_profiles where user_id=${quote(a)});
 insert into profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current)
 select '${randomUUID()}',id,'Fictional Group','Volunteer','2025-01-01',true from career_profiles where user_id=${quote(a)};`);
 const p=sql(`select id from career_profiles where user_id=${quote(a)}`);
 const doc=await gateway.handle(a,'document',{profile_id:p});
 const command={request_id:randomUUID(),idempotency_key:randomUUID(),expected_profile_version:doc.profile_version,
  payload:{profile_id:p,expected_configuration_version:doc.configuration_version,
   expected_document_sha256:doc.document_sha256,renderer_bundle_version:doc.bundle}};
 const accepted=await gateway.handle(a,'create',command);
 const [j]=await db.call('claim',{capacity:1});
 assert.equal(j.id,accepted.operation_id);
 const r={render:async()=>Buffer.from('%PDF-fixture-only'),validate:async()=>1};
 const row=()=>JSON.parse(sql(`select to_jsonb(j) from export_jobs j where id=${quote(j.id)}`));
 const balance=()=>sql(`select finalized_balance||','||reserved_balance from credit_accounts where user_id=${quote(a)}`);
 const charges=()=>Number(sql(`select count(*) from credit_transactions where user_id=${quote(a)} and reference_type='RESUME_EXPORT'`));
 return {a,p,doc,command,accepted,j,r,row,balance,charges};
}
{
 const f=await acceptanceFixture();
 f.r.render=async()=>{throw new ExportError('VALIDATION_FAILED');};
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(f.j);
 assert.equal(f.row().state,'FAILED');assert.equal(f.balance(),'5,0');assert.equal(f.charges(),0);
 console.log('PASS acceptance: terminal renderer failure releases reservation; no object/debit');
}
{
 const f=await acceptanceFixture();
 f.r.render=async()=>{throw new ExportError('SERVICE_UNAVAILABLE');};
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(f.j);
 assert.equal(f.row().state,'RETRYABLE_FAILURE');assert.equal(f.balance(),'5,2');
 sql(`update export_jobs set next_attempt_at=now() where id=${quote(f.j.id)}`);
 const [retry]=await db.call('claim',{capacity:1});
 assert.equal(retry.id,f.j.id);assert.notEqual(retry.lease_token,f.j.lease_token);
 f.r.render=async()=>Buffer.from('%PDF-fixture-only');
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(retry);
 assert.equal(f.row().state,'COMPLETED');assert.equal(f.balance(),'3,0');assert.equal(f.charges(),1);
 assert.deepEqual(await gateway.handle(f.a,'create',f.command),f.accepted);
 console.log('PASS acceptance: transient renderer retry uses same job/new fence; exactly one debit');
}
{
 const f=await acceptanceFixture();let responseLost=false;
 const interrupted={call:async(method,args)=>{
  const result=await db.call(method,args);
  if(method==='finish'&&args.proof&&!responseLost) {
   responseLost=true;throw new ExportError('SERVICE_UNAVAILABLE');
  }
  return result;
 }};
 await new Worker({db:interrupted,storage,renderer:f.r,enabled:true}).run(f.j);
 assert.ok(responseLost);assert.equal(f.row().state,'COMPLETED');
 assert.equal(f.balance(),'3,0');assert.equal(f.charges(),1);
 assert.deepEqual(await gateway.handle(f.a,'create',f.command),f.accepted);
 console.log('PASS acceptance: response timeout after committed finish reconciles without new job/debit');
}
{
 const f=await acceptanceFixture();
 // Clock injection fires the existing hard deadline without sleeping 30m.
 // SQL fixture timestamps simulate the same elapsed deadline, not new policy.
 let now=Date.now();const callbacks=new Map();let next=0;
 const clock={now:()=>now,setTimeout:(fn,ms)=>{callbacks.set(++next,{fn,at:now+ms});return next;},
  clearTimeout:id=>callbacks.delete(id),setInterval:fn=>{callbacks.set(++next,{fn,at:Infinity});return next;},
  clearInterval:id=>callbacks.delete(id)};
 let rendering=false;
 f.r.render=async()=>{rendering=true;return new Promise(()=>{});};
 const running=new Worker({db,storage,renderer:f.r,enabled:true,clock}).run(f.j);
 for(let i=0;i<200&&!rendering;i++)await new Promise(resolve=>setTimeout(resolve,1));
 assert.ok(rendering);
 now=Date.parse(f.j.deadline)+1;
 for(const timer of [...callbacks.values()])if(timer.at<=now)await timer.fn();
 await running;
 assert.equal(f.balance(),'5,2');assert.equal(f.charges(),0);
 sql(`update export_jobs set deadline=now()-interval '1 second' where id=${quote(f.j.id)}`);
 await db.call('recover');await db.call('recover');
 assert.equal(f.row().state,'FAILED');assert.equal(f.balance(),'5,0');assert.equal(f.charges(),0);
 console.log('PASS acceptance: stalled worker deadline + authoritative recovery releases once; no debit');
}
{
 const f=await acceptanceFixture();let renderCount=0,createCount=0;
 const lost={...storage,create:async(...args)=>{
  createCount++;await storage.create(...args);
  throw new ExportError('SERVICE_UNAVAILABLE');
 }};
 f.r.render=async()=>{renderCount++;return Buffer.from('%PDF-fixture-only');};
 await new Worker({db,storage:lost,renderer:f.r,enabled:true}).run(f.j);
 assert.equal(f.row().state,'RETRYABLE_FAILURE');assert.equal(f.balance(),'5,2');
 sql(`update export_jobs set next_attempt_at=now() where id=${quote(f.j.id)}`);
 const [retry]=await db.call('claim',{capacity:1});
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(retry);
 assert.equal(f.row().state,'COMPLETED');assert.equal(f.charges(),1);
 assert.equal(renderCount,1);assert.equal(createCount,1);
 console.log('PASS acceptance: upload committed/response lost adopts verified object; no rerender/second debit');
}
{
 const f=await acceptanceFixture();
 // Expiry must reject before storage signing and must leave snapshot/ledger.
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(f.j);
 sql(`update export_jobs set expires_at=now()-interval '1 second' where id=${quote(f.j.id)}`);
 await assert.rejects(gateway.handle(f.a,'download',{export_id:f.j.id}),{code:'EXPORT_EXPIRED'});
 assert.equal(f.charges(),1);assert.equal(f.balance(),'3,0');
 assert.equal(sql(`select count(*) from export_snapshots where id=${quote(f.accepted.data.snapshot_id)}`),'1');
 sql(`update profile_summaries set text='changed source' where profile_id=${quote(f.p)};
 insert into profile_summaries(profile_id,text) values(${quote(f.p)},'changed current source')
 on conflict(profile_id) do update set text=excluded.text;
 update career_profiles set profile_version=profile_version+1 where id=${quote(f.p)}`);
 const current=await gateway.handle(f.a,'document',{profile_id:f.p});
  // This is a separate history/new-source lifecycle fixture, not a quota
  // bypass; expire the synthetic accepted intent before exercising Export Again.
  sql(`update export_admission_events set accepted_at=now()-interval '8 days' where user_id=${quote(f.a)}`);
 const again=await gateway.handle(f.a,'again',{request_id:randomUUID(),idempotency_key:randomUUID(),
  expected_profile_version:current.profile_version,payload:{...f.command.payload,
   expected_document_sha256:current.document_sha256,expected_configuration_version:current.configuration_version,
   historical_export_id:f.j.id}});
 assert.notEqual(again.operation_id,f.j.id);assert.equal(again.data.reserved_credits,2);
 assert.notEqual(again.data.document_sha256,f.accepted.data.document_sha256);
 assert.equal(f.balance(),'3,2');
 const [claimedAgain]=await db.call('claim',{capacity:1});
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(claimedAgain);
 assert.equal(f.balance(),'1,0');assert.equal(f.charges(),2);
 console.log('PASS acceptance: expired download no debit/regeneration; explicit Again uses current source and new 2-Credit job');
}
{
 const f=await acceptanceFixture();
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(f.j);
 const before=storageMap.size,original=f.row();
 const peerPath=`exports/${randomUUID()}/peer.pdf`;storageMap.set(peerPath,{generation:'700'});
 const ownerOrphan=`exports/${f.a}/orphan.pdf`;storageMap.set(ownerOrphan,{generation:'701'});
 storage.listPrefix=async prefix=>[...storageMap].filter(([name])=>name.startsWith(prefix))
  .map(([name,object])=>({name,...object}));
 sql(`update users set status='DELETING' where id=${quote(f.a)}`);
 await assert.rejects(gateway.handle(f.a,'create',f.command),{code:'ACCOUNT_DELETING'});
 const cleaned=await new ExportCleanup({db,storage,enabled:true}).freeze(f.a);
 assert.equal(cleaned.state,'EXPORT_DATA_REMOVED');assert.equal(cleaned.snapshots_verified,true);
 for(const table of ['export_jobs','export_snapshots','credit_reservations'])
  assert.equal(sql(`select count(*) from ${table} where user_id=${quote(f.a)}`),'0');
 assert.equal(sql(`select count(*) from idempotency_records where operation_id=${quote(f.j.id)}`),'0');
 assert.equal(sql(`select count(*) from export_upload_flights where operation=${quote(f.j.id)}`),'0');
 assert.ok(!storageMap.has(original.object_path)&&!storageMap.has(ownerOrphan)&&storageMap.has(peerPath));
 assert.equal(storageMap.size,before); // one owner PDF + orphan removed; peer added
 assert.equal(f.charges(),1); // immutable completed ledger remains until account deletion
 console.log('PASS acceptance: account freeze denies replay; exact object/orphan removal and zero export rows; peer object/ledger preserved');
}
{
 const f=await acceptanceFixture();let calls=0;
 // Use the production adapter and an intercepted provider response, not forged
 // error properties. No real HTTP/credential/cloud operation is performed.
 const rejectedStorage=new GoogleStorage({token:async()=>'synthetic-only'});
 const denied={...storage,create:async(...args)=>{
  const original=globalThis.fetch;
  globalThis.fetch=async(url,options)=>{
   assert.equal(new URL(url).hostname,'storage.googleapis.com');
   assert.equal(options.method,'POST');calls++;
   return new Response('{}',{status:403});
  };
  try{return await rejectedStorage.create(...args);}
  finally{globalThis.fetch=original;}
 }};
 await new Worker({db,storage:denied,renderer:f.r,enabled:true}).run(f.j);
 assert.equal(f.row().state,'RETRYABLE_FAILURE');assert.equal(f.balance(),'5,2');
 assert.equal(sql(`select state from export_upload_flights where operation=${quote(f.j.id)}`),'SETTLED');
 sql(`update export_jobs set next_attempt_at=now() where id=${quote(f.j.id)}`);
 const [retry]=await db.call('claim',{capacity:1});
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(retry);
 console.log(JSON.stringify({acceptance:'definitive_upload_rejection_retry',
  state:f.row().state,attempts:f.row().attempt_count,providerCreateCalls:calls,charges:f.charges(),
  unresolvedFlights:Number(sql(`select count(*) from export_upload_flights where operation=${quote(f.j.id)} and state='SENT'`))}));
 assert.equal(f.row().state,'COMPLETED','Definitively rejected upload must allow safe same-job retry after provider recovery');
 assert.equal(f.balance(),'3,0');assert.equal(f.charges(),1);
 const objectsBefore=storageMap.size;
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(f.j); // old fence
 await new Worker({db,storage,renderer:f.r,enabled:true}).run(retry); // duplicate callback
 assert.equal(storageMap.size,objectsBefore);assert.equal(f.balance(),'3,0');assert.equal(f.charges(),1);
 assert.equal(sql(`select count(*) from export_upload_flights where operation=${quote(f.j.id)} and state='SENT'`),'0');
 assert.deepEqual(await gateway.handle(f.a,'create',f.command),f.accepted);
 console.log('PASS acceptance: real adapter HTTP403 settles exact flight; retry completes, stale/duplicate runs preserve object and one debit');
}
