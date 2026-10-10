import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {Worker} from '../worker.mjs';
import {ExportCleanup} from '../cleanup.mjs';
import {ExportError,bundle,sha256} from '../document.mjs';

class Clock {
  constructor(){this.time=Date.parse('2026-10-08T12:00:00Z');this.callbacks=new Map();this.id=0;}
  now=()=>this.time;
  setTimeout=(callback,ms)=>{const id=++this.id;this.callbacks.set(id,{callback,at:this.time+ms});return id;};
  clearTimeout=id=>this.callbacks.delete(id);
  setInterval=(callback,ms)=>{const id=++this.id;this.callbacks.set(id,{callback,at:this.time+ms,ms});return id;};
  clearInterval=this.clearTimeout;
  async advance(ms) {
    this.time+=ms;
    for(const [id,timer] of [...this.callbacks])if(timer.at<=this.time) {
      if(timer.ms)timer.at=this.time+timer.ms;else this.callbacks.delete(id);
      await timer.callback();
    }
    await flush();
  }
}
const flush=async()=>{for(let i=0;i<100;i++)await Promise.resolve();};
function fixture() {
  const clock=new Clock(),calls=[],objects=new Map();
  const job={id:randomUUID(),user_id:randomUUID(),lease_token:randomUUID(),
    max_pdf_bytes:10485760,
    deadline:new Date(clock.now()+1800000).toISOString(),
    snapshot:{canonical_html:'html',document_sha256:sha256('html'),source_sha256:sha256('source'),bundle}};
  const path=`exports/${job.user_id}/${job.id}/${job.snapshot.source_sha256}.pdf`;
  const bytes=Buffer.from('%PDF-synthetic');
  const object={generation:'1',contentType:'application/pdf',
    timeCreated:new Date(clock.now()).toISOString(),metadata:{
      document_sha256:job.snapshot.document_sha256,source_sha256:job.snapshot.source_sha256,
      pdf_sha256:sha256(bytes)},bytes};
  const storage={inspect:async p=>objects.get(p)??null,
    listPrefix:async()=>[...objects].map(([name,object])=>({name,...object})),
    create:async(p,b,metadata)=>{objects.set(p,{...object,bytes:b,metadata});return objects.get(p);},
    read:async p=>objects.get(p).bytes};
  const db={call:async(name,args)=>{calls.push([name,args]);return 'COMPLETED';}};
  const renderer={render:async()=>bytes,validate:async()=>1};
  const worker=new Worker({clock,db,storage,renderer,enabled:true});
  return {clock,calls,objects,job,path,object,storage,db,renderer,worker};
}
test('disabled export recovery reconciles reservations without claiming or dispatching work',async()=>{
  const calls=[];
  const worker=new Worker({enabled:false,db:{call:async name=>{calls.push(name);return 1;}}});
  await worker.recover();
  assert.deepEqual(calls,['recover','cost_reconcile']);
  await assert.rejects(worker.dispatch(),{code:'EXPORT_NOT_READY'});
  assert.deepEqual(calls,['recover','cost_reconcile']);
});
test('independent heartbeat during a stalled browser; hard deadline releases local slots',async()=>{
  const f=fixture();let rendering=false;
  f.renderer.render=()=>{rendering=true;return new Promise(()=>{});};
  f.db.call=async(name,args)=>{f.calls.push([name,args]);return name==='claim'?[f.job]:null;};
  const running=f.worker.dispatch();await flush();assert.ok(rendering);assert.equal(f.worker.active,2);
  await f.clock.advance(60000);
  assert.equal(f.calls.filter(([n])=>n==='heartbeat').length,1);
  await f.clock.advance(1800000);await running;
  assert.equal(f.worker.active,0);assert.equal(f.clock.callbacks.size,0);
  assert.ok(!f.calls.some(([n])=>n==='finish')); // Authoritative reaper, not timeout-as-failure.
});
test('lease loss aborts upload; late result cannot debit/release a newer worker',async()=>{
  const f=fixture();let resolveUpload;
  f.storage.create=()=>new Promise(resolve=>{resolveUpload=resolve;});
  const running=f.worker.run(f.job);await flush();assert.ok(resolveUpload);
  f.db.call=async(name,args)=>{f.calls.push([name,args]);throw new ExportError('STALE_LEASE');};
  await f.clock.advance(60000);await running;
  resolveUpload(f.object);await flush();
  assert.ok(!f.calls.some(([n])=>n==='finish'));
});
test('ambiguous upload leaves reservation pending; next worker adopts same verified object',async()=>{
  const f=fixture();let rendered=0;
  f.renderer.render=async()=>{rendered++;return f.object.bytes;};
  f.storage.create=async()=>{f.objects.set(f.path,f.object);throw new ExportError('SERVICE_UNAVAILABLE');};
  await f.worker.run(f.job);
  assert.equal(f.calls.find(([n])=>n==='finish')[1].terminal,false);
  f.calls.length=0;f.job.lease_token=randomUUID();
  await f.worker.run(f.job);
  assert.equal(rendered,1);
  assert.ok(f.calls.find(([n,a])=>n==='finish'&&a.proof));
});
test('conditional-create conflict adopts matching generation without overwrite',async()=>{
  const f=fixture();
  f.storage.create=async()=>{f.objects.set(f.path,f.object);throw new ExportError('OBJECT_EXISTS');};
  await f.worker.run(f.job);
  assert.equal(f.calls.find(([n])=>n==='finish')[1].proof.generation,'1');
});
test('wrong-source existing object terminates without consume proof',async()=>{
  const f=fixture();f.object.metadata.source_sha256=sha256('wrong');f.objects.set(f.path,f.object);
  await f.worker.run(f.job);
  const finish=f.calls.find(([n])=>n==='finish')[1];
  assert.equal(finish.proof,null);assert.equal(finish.terminal,true);
});
test('non-integer/read-back page count cannot finalize',async()=>{
  const f=fixture();let validation=0;
  f.renderer.validate=async()=>++validation===1?1:NaN;
  await f.worker.run(f.job);
  assert.equal(f.calls.find(([n])=>n==='finish')[1].proof,null);
});
test('ambiguous completion reconciles durable terminal result, never retries as a new job',async()=>{
  const f=fixture();let consumed=0;
  f.db.call=async(name,args)=>{
    f.calls.push([name,args]);
    if(name==='finish' && args.proof){consumed++;throw new ExportError('SERVICE_UNAVAILABLE');}
    return 'COMPLETED'; // Failure callback sees already committed completion.
  };
  await f.worker.run(f.job);assert.equal(consumed,1);
  assert.deepEqual(f.calls.filter(([n])=>n==='finish').map(([,a])=>!!a.proof),[true,false]);
});
test('snapshot asset digest tampering is terminal before any render/upload',async()=>{
  const f=fixture();f.job.snapshot.asset_manifest={font_checksums:['wrong']};
  await f.worker.run(f.job);
  assert.equal(f.objects.size,0);
  assert.equal(f.calls.find(([n])=>n==='finish')[1].terminal,true);
});

function cleanupFixture() {
  const objects=new Map([['path',{generation:'7'}]]),calls=[];
  const job={id:randomUUID(),path:'path',generation:'7'};
  const db={call:async(name,args)=>{calls.push([name,args]);return name==='cleaned'?null:
    name==='quiescent'?false:name==='purge'?{state:'EXPORT_DATA_REMOVED',objects_verified:true,snapshots_verified:true}:[job];}};
  const storage={inspect:async p=>objects.get(p)??null,
    listPrefix:async()=>[...objects].map(([name,object])=>({name,...object})),
    remove:async(p,g)=>{assert.equal(g,'7');objects.delete(p);}};
  return {objects,calls,job,db,storage};
}
test('deletion hook waits for quiescence and never guesses snapshot retention',async()=>{
  const f=cleanupFixture();
  const result=await new ExportCleanup({...f,enabled:true}).freeze(randomUUID());
  assert.equal(result.state,'DELETION_PENDING');assert.equal(result.objects_verified,false);
  assert.equal(f.objects.size,1);assert.equal(result.reason,'UPLOAD_QUIESCENCE_UNVERIFIED');
});
test('quiescent deletion verifies objects then purges export data without claiming account deletion',async()=>{
  const f=cleanupFixture();
  const result=await new ExportCleanup({...f,enabled:true,barrier:{quiescent:async()=>true}}).freeze(randomUUID());
  assert.equal(result.objects_verified,true);assert.equal(result.state,'EXPORT_DATA_REMOVED');
  assert.equal(result.snapshots_verified,true);
  assert.deepEqual(f.calls.map(([n])=>n),['freeze','purge']);
});
test('late upload racing deletion verification cannot be declared clean',async()=>{
  const f=cleanupFixture();let probes=0;
  f.storage.inspect=async()=>++probes>1?{generation:'8'}:{generation:'7'};
  await assert.rejects(new ExportCleanup({...f,enabled:true,
    barrier:{quiescent:async()=>true}}).freeze(randomUUID()),{code:'CLEANUP_UNVERIFIED'});
});
test('retention removes only expired exact generation and records verification, not a refund',async()=>{
  const f=cleanupFixture();
  assert.equal((await new ExportCleanup({...f,enabled:true}).retention()).verified,1);
  assert.deepEqual(f.calls.map(([n])=>n),['retention','cleaned']);
});
test('replacement generation is not removed by an old expiry callback',async()=>{
  const f=cleanupFixture();f.objects.set('path',{generation:'8'});
  await assert.rejects(new ExportCleanup({...f,enabled:true}).retention(),{code:'CLEANUP_UNVERIFIED'});
  assert.equal(f.objects.get('path').generation,'8');
  assert.ok(!f.calls.some(([n])=>n==='cleaned'));
});
test('account export cleanup removes orphan objects as well as canonical paths before purge',async()=>{
  const f=cleanupFixture();f.objects.set('orphan',{generation:'7'});
  const result=await new ExportCleanup({...f,enabled:true,barrier:{quiescent:async()=>true}}).freeze(randomUUID());
  assert.equal(result.state,'EXPORT_DATA_REMOVED');assert.equal(f.objects.size,0);
});
test('stored unique upload marker reconciles a lost response before distributed deletion barrier',async()=>{
  const f=cleanupFixture(),fence=randomUUID();let settled=false;
  Object.assign(f.job,{document_sha256:'doc',source_sha256:'source'});
  f.objects.get('path').metadata={upload_fence:fence,document_sha256:'doc',source_sha256:'source'};
  f.db.call=async(name,args)=>{
    f.calls.push([name,args]);
    if(name==='freeze')return [f.job];
    if(name==='upload_settle'){assert.equal(args.fence,fence);settled=true;return;}
    if(name==='quiescent')return settled;
    if(name==='purge')return {state:'EXPORT_DATA_REMOVED',snapshots_verified:true};
  };
  const result=await new ExportCleanup({...f,enabled:true}).freeze(randomUUID());
  assert.equal(result.state,'EXPORT_DATA_REMOVED');assert.equal(f.objects.size,0);
  assert.deepEqual(f.calls.map(([n])=>n),['freeze','upload_settle','quiescent','quiescent','purge']);
});
test('wrong snapshot metadata cannot settle an ambiguous upload or permit purge',async()=>{
  const f=cleanupFixture();
  Object.assign(f.job,{document_sha256:'doc',source_sha256:'source'});
  f.objects.get('path').metadata={upload_fence:randomUUID(),document_sha256:'wrong',source_sha256:'source'};
  const result=await new ExportCleanup({...f,enabled:true}).freeze(randomUUID());
  assert.equal(result.state,'DELETION_PENDING');assert.equal(f.objects.size,1);
  assert.ok(!f.calls.some(([n])=>['upload_settle','purge'].includes(n)));
});
