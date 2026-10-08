import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {Gateway} from '../gateway.mjs';
import {Worker} from '../worker.mjs';
import {bundle,logicalHash,sha256,ExportError,Canonicalizer} from '../document.mjs';
import {containsText} from '../renderer.mjs';
import {GoogleStorage,authenticateInternal} from '../google.mjs';

const command=()=>({request_id:randomUUID(),idempotency_key:randomUUID(),
  expected_profile_version:1,payload:{profile_id:randomUUID(),
    expected_configuration_version:0,expected_document_sha256:sha256('html'),
    renderer_bundle_version:bundle}});
test('same logical hash across transport attempts/key ordering',()=>{
  const a=command(),b={payload:{...a.payload},expected_profile_version:1,
    idempotency_key:a.idempotency_key,request_id:randomUUID()};
  assert.equal(logicalHash(a),logicalHash(b));
  b.payload.expected_configuration_version=2;
  assert.notEqual(logicalHash(a),logicalHash(b));
});
test('gateway disabled by default without database/credential access',async()=>{
  await assert.rejects(new Gateway({}).handle(randomUUID(),'document',{}),
    {code:'EXPORT_NOT_READY'});
});
test('accepted replay precedes stale/current-document reads',async()=>{
  let reads=0;
  const gateway=new Gateway({enabled:true,db:{call:async(name)=>{
    assert.equal(name,'replay');return {operation_id:'original'};}},
    canonicalizer:{prepare:async()=>{reads++;}}});
  assert.deepEqual(await gateway.handle(randomUUID(),'create',command()),
    {operation_id:'original'});
  assert.equal(reads,0);
});
test('version/hash conflict reserves nothing',async()=>{
  const calls=[];
  const gateway=new Gateway({enabled:true,
    db:{call:async(name)=>{calls.push(name);return name==='replay'?null:{};}},
    canonicalizer:{prepare:async()=>({document_sha256:sha256('changed'),
      profile_version:2,configuration_version:0,issues:[]})}});
  await assert.rejects(gateway.handle(randomUUID(),'create',command()),{code:'VERSION_CONFLICT'});
  assert.deepEqual(calls,['replay','source']);
});
test('reject client price/user content injected into payload',async()=>{
  const c=command();c.payload.price=0;
  await assert.rejects(new Gateway({enabled:true}).handle(randomUUID(),'create',c),
    {code:'VALIDATION_FAILED'});
});
test('valid free generation-bound download never invokes create/finalize',async()=>{
  const calls=[];const signed=[];
  const gateway=new Gateway({enabled:true,db:{call:async(name)=>{
    calls.push(name);return {state:'COMPLETED',object_path:'private',
      object_generation:'7',expires_at:new Date(Date.now()+86400000).toISOString()};}},
    storage:{inspect:async()=>({generation:'7'}),sign:async(...args)=>{signed.push(args);return 'ephemeral';}}});
  assert.equal((await gateway.handle(randomUUID(),'download',{export_id:randomUUID()})).url,'ephemeral');
  assert.deepEqual(calls,['status','status']);assert.equal(signed[0][1],'7');assert.equal(signed[0][2],600);
});
test('confirmed missing download marks metadata, never regenerates/debits',async()=>{
  const calls=[];
  const gateway=new Gateway({enabled:true,db:{call:async(name)=>{
    calls.push(name);return {state:'COMPLETED',object_path:'private',object_generation:'7',
      expires_at:new Date(Date.now()+86400000).toISOString()};}},
    storage:{inspect:async()=>null}});
  await assert.rejects(gateway.handle(randomUUID(),'download',{export_id:randomUUID()}),
    {code:'EXPORT_OBJECT_MISSING'});assert.deepEqual(calls,['status','missing']);
});
test('transient object probe does not label a file missing',async()=>{
  const calls=[];
  const gateway=new Gateway({enabled:true,db:{call:async(name)=>{calls.push(name);
    return {state:'COMPLETED',expires_at:new Date(Date.now()+86400000).toISOString()};}},
    storage:{inspect:async()=>{throw new ExportError('SERVICE_UNAVAILABLE');}}});
  await assert.rejects(gateway.handle(randomUUID(),'download',{export_id:randomUUID()}),
    {code:'SERVICE_UNAVAILABLE'});assert.deepEqual(calls,['status']);
});
function job(){return {id:randomUUID(),user_id:randomUUID(),lease_token:randomUUID(),
  deadline:new Date(Date.now()+1800000).toISOString(),
  snapshot:{canonical_html:'html',document_sha256:sha256('html'),source_sha256:sha256('source'),bundle}};}
test('worker verifies uploaded bytes before successful finalization',async()=>{
  const j=job(),calls=[];let bytes;
  const storage={inspect:async()=>null,create:async(path,pdf,metadata)=>{
    bytes=pdf;return {generation:'1',contentType:'application/pdf',metadata,timeCreated:new Date().toISOString()};},
    read:async()=>bytes};
  const worker=new Worker({enabled:true,storage,db:{call:async(name,args)=>{calls.push([name,args]);}},
    renderer:{render:async()=>Buffer.from('%PDF-fixture'),validate:async()=>1}});
  await worker.run(j);
  const finish=calls.find(([name])=>name==='finish')[1];
  assert.equal(finish.proof.pdf_sha256,sha256(bytes));assert.equal(finish.proof.pages,1);
  assert.deepEqual(calls.filter(([name])=>name==='stage').map(([,a])=>a.stage),['GENERATING','UPLOADING']);
});
test('20-page overflow is terminal with no upload/debit proof',async()=>{
  let upload=false;const calls=[];
  const worker=new Worker({enabled:true,
    storage:{inspect:async()=>null,create:async()=>{upload=true;}},
    db:{call:async(name,args)=>{calls.push([name,args]);}},
    renderer:{render:async()=>Buffer.from('%PDF-fixture'),validate:async()=>21}});
  await worker.run(job());assert.equal(upload,false);
  const finish=calls.find(([name])=>name==='finish')[1];
  assert.equal(finish.proof,null);assert.equal(finish.terminal,true);
});
test('stale worker cannot finalize or release',async()=>{
  const calls=[];
  const worker=new Worker({enabled:true,db:{call:async(name)=>{calls.push(name);
    throw new ExportError('STALE_LEASE');}},storage:{}});
  await worker.run(job());assert.deepEqual(calls,['stage']);
});
test('dispatch capacity is reserved before concurrent claims',async()=>{
  let finishClaim;const blocked=new Promise(resolve=>{finishClaim=resolve;});let claims=0;
  const worker=new Worker({enabled:true,db:{call:async()=>{
    claims++;await blocked;return [];}}});
  const first=worker.dispatch();await worker.dispatch();finishClaim();await first;
  assert.equal(claims,1);assert.equal(worker.active,0);
});
test('source text preservation handles Arabic shaping but rejects missing text',()=>{
  assert.ok(containsText('العربية SQL •','العربية SQL'));
  assert.ok(!containsText('العربية SQ','العربية SQL'));
});
test('private OIDC rejects missing user/foreign bearer without fetching Google keys',async()=>{
  await assert.rejects(authenticateInternal(null,'https://service.run.app'),{code:'FORBIDDEN'});
  await assert.rejects(authenticateInternal('Bearer not-valid','https://service.run.app'),{code:'FORBIDDEN'});
});
test('server refuses startup gates without any listener/cloud call',async()=>{
  const source=await readFile(new URL('../server.mjs',import.meta.url),'utf8');
  assert.ok(source.includes("JOBIX_EXPORT_DELETION_POLICY_APPROVED!=='true'"));
  assert.ok(source.includes("JOBIX_EXPORT_ENABLED!=='true'"));
});
test('signer rejects unbounded TTL before accessing identity',async()=>{
  await assert.rejects(new GoogleStorage().sign('opaque','1',601),{code:'VALIDATION_FAILED'});
});
test('expired download rejects before object/signing calls and never regenerates',async()=>{
  const gateway=new Gateway({enabled:true,db:{call:async()=>({
    state:'COMPLETED',expires_at:new Date(0).toISOString()})},
    storage:{inspect:async()=>{throw new Error('must not inspect');}}});
  await assert.rejects(gateway.handle(randomUUID(),'download',{export_id:randomUUID()}),
    {code:'EXPORT_EXPIRED'});
});
test('Export Again requires explicit historical identity and has a distinct logical payload',async()=>{
  const c=command();
  await assert.rejects(new Gateway({enabled:true}).handle(randomUUID(),'again',c),
    {code:'VALIDATION_FAILED'});
  const original=logicalHash(c);c.payload.historical_export_id=randomUUID();
  assert.notEqual(original,logicalHash(c));
});
test('history projection hides private object fields and uses opaque pagination',async()=>{
  const id=randomUUID();
  const gateway=new Gateway({enabled:true,db:{call:async(name,args)=>{
    assert.equal(args.before_id,id);
    return Array.from({length:25},()=>({id:randomUUID(),object_path:'private',object_generation:'9',
      pdf_sha256:'hash',user_id:'owner',state:'EXPIRED'}));}}});
  const result=await gateway.handle(randomUUID(),'history',{cursor:id});
  assert.ok(result.next_cursor);assert.equal(result.jobs[0].object_path,undefined);
  assert.equal(result.jobs[0].object_generation,undefined);
});
test('normalized UTF-8 overflow is rejected before invoking HTML/font rendering',async()=>{
  let calls=0;
  const canonicalizer=new Canonicalizer({execute:async(_program,args)=>{
    calls++;assert.equal(args.at(-1),'source');
    // NFC expands this combining character: raw length below limit, normalized above.
    return JSON.stringify({bundle,source_text:'\u0344'.repeat(50001)});
  }});
  await assert.rejects(canonicalizer.prepare({source:{}}),{code:'VALIDATION_FAILED'});
  assert.equal(calls,1);
});
