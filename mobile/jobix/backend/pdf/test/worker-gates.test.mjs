import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {server} from '../server.mjs';
import {ExportError} from '../document.mjs';

async function fixture(run) {
  const calls=[];
  const s=server({exportsEnabled:false,
    authenticate:async header=>{
      if(header!=='Bearer fixture')throw new ExportError('FORBIDDEN');
      return 'jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com';
    },
    gateway:{handle:async(actor,action)=>{calls.push(action);return {actor};}},
    worker:{recover:async()=>calls.push('recover'),dispatch:async()=>calls.push('dispatch')},
    cleanup:{retention:async()=>calls.push('retention'),deletions:async()=>calls.push('deletions')}});
  s.listen(0,'127.0.0.1');await once(s,'listening');
  const post=(path,body={},authenticated=true)=>fetch(
    'http://127.0.0.1:'+s.address().port+path,{method:'POST',
      headers:authenticated?{Authorization:'Bearer fixture'}:{},body:JSON.stringify(body)});
  try{await run(post,calls);}finally{await new Promise(resolve=>s.close(resolve));}
}
test('disabled worker blocks export creation and dispatch but permits free downloads and metadata reads',async()=>{
  await fixture(async(post,calls)=>{
    for(const action of ['create','again']) {
      const r=await post('/command',{action});
      assert.equal((await r.json()).error.code,'EXPORT_NOT_READY');
    }
    assert.equal((await (await post('/dispatch')).json()).error.code,'EXPORT_NOT_READY');
    assert.deepEqual(calls,[]);
    for(const action of ['document','history','status','download'])assert.equal((await post('/command',{action})).status,200);
    assert.deepEqual(calls,['document','history','status','download']);
  });
});
test('disabled exports run reservation recovery without dispatch, preserving retention/deletion cleanup',async()=>{
  await fixture(async(post,calls)=>{
    const r=await post('/recover');
    assert.deepEqual((await r.json()).data,{exportsEnabled:false});
    assert.deepEqual(calls,['recover','retention','deletions']);
  });
});
test('disabled-mode reads remain authenticated and anonymous requests fail closed',async()=>{
  await fixture(async(post,calls)=>{
    assert.equal((await post('/command',{action:'history'},false)).status,403);
    assert.deepEqual(calls,[]);
  });
});
