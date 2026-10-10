import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {Worker} from '../worker.mjs';
import {server} from '../server.mjs';
import {response} from '../../export-gateway/core.mjs';
import {ExportError,bundle,sha256} from '../document.mjs';

const unavailable='Service is temporarily unavailable. Please try again later.';
function job(maxPdfBytes=1024) {
  const html='<html><body>cost fixture</body></html>';
  return {id:'93000000-0000-0000-0000-000000000001',
    user_id:'93000000-0000-0000-0000-000000000002',
    lease_token:'93000000-0000-0000-0000-000000000003',
    max_pdf_bytes:maxPdfBytes,
    deadline:new Date(Date.now()+1800000).toISOString(),
    snapshot:{canonical_html:html,document_sha256:sha256(html),
      source_sha256:sha256('source'),bundle}};
}
function workerFixture({pdf=Buffer.from('%PDF-cost'),create=async(_path,bytes,metadata)=>({
  generation:'1',contentType:'application/pdf',metadata,timeCreated:new Date().toISOString(),bytes,
}),dbCall=async name=>name==='finish'?'COMPLETED':null}={}) {
  const calls=[],storageCalls=[];
  const storage={
    inspect:async()=>{storageCalls.push('inspect');return null;},
    create:async(...args)=>{storageCalls.push('create');return create(...args);},
    read:async()=>{storageCalls.push('read');return pdf;},
  };
  const db={call:async(name,args)=>{calls.push([name,args]);return dbCall(name,args);}};
  const renderer={render:async()=>pdf,validate:async()=>1};
  return {calls,storageCalls,worker:new Worker({db,storage,renderer,enabled:true}),job:job()};
}

test('private worker request returns the exact HTTP 503 service-unavailable contract',async()=>{
  const s=server({exportsEnabled:true,
    authenticate:async()=> 'jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com',
    gateway:{handle:async()=>{throw new ExportError('SERVICE_UNAVAILABLE');}},
    worker:{recover:async()=>{},dispatch:async()=>{}},cleanup:null});
  s.listen(0,'127.0.0.1');await once(s,'listening');
  try {
    const result=await fetch(`http://127.0.0.1:${s.address().port}/command`,{
      method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},
      body:JSON.stringify({action:'create'}),
    });
    assert.equal(result.status,503);
    assert.deepEqual((await result.json()).error,{code:'SERVICE_UNAVAILABLE',message:unavailable});
  } finally {await new Promise(resolve=>s.close(resolve));}
  assert.deepEqual(await response('SERVICE_UNAVAILABLE').json(),{
    data:null,error:{code:'SERVICE_UNAVAILABLE',message:unavailable},
  });
});

test('worker records bounded runtime, output bytes, and storage operations before settling',async()=>{
  const f=workerFixture();
  await f.worker.run(f.job);
  const started=f.calls.find(([name])=>name==='cost_attempt_start');
  const measured=f.calls.find(([name])=>name==='cost_attempt_finish');
  assert.ok(started);
  assert.equal(measured[1].operation,f.job.id);
  assert.equal(measured[1].fence,f.job.lease_token);
  assert.equal(measured[1].pdf_bytes,Buffer.byteLength('%PDF-cost'));
  assert.equal(measured[1].storage_operations,3);
  assert.ok(measured[1].runtime_ms>=0);
  assert.ok(f.calls.some(([name])=>name==='cost_settle'));
});

test('PDF size ceiling is enforced before upload and terminal accounting is settled',async()=>{
  const tooLarge=Buffer.from('%PDF-'+('x'.repeat(20)));
  let uploaded=false;
  const f=workerFixture({pdf:tooLarge,create:async()=>{uploaded=true;},
    dbCall:async name=>name==='finish'?'FAILED':null});
  f.job.max_pdf_bytes=10;
  await f.worker.run(f.job);
  assert.equal(uploaded,false);
  assert.equal(f.calls.find(([name])=>name==='cost_attempt_finish')[1].pdf_bytes,tooLarge.length);
  assert.equal(f.calls.find(([name,args])=>name==='finish')[1].terminal,true);
  assert.ok(f.calls.some(([name])=>name==='cost_settle'));
});

test('ambiguous provider failure leaves the logical reservation unsettled for retry',async()=>{
  const f=workerFixture({create:async()=>{throw new ExportError('SERVICE_UNAVAILABLE');},
    dbCall:async name=>name==='finish'?'RETRYABLE_FAILURE':null});
  await f.worker.run(f.job);
  assert.ok(f.calls.some(([name])=>name==='cost_attempt_start'));
  assert.ok(f.calls.some(([name])=>name==='cost_attempt_finish'));
  assert.ok(!f.calls.some(([name])=>name==='cost_settle'));
  assert.ok(!f.calls.some(([name])=>name==='cost_reserve'));
});
