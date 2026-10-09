import test from 'node:test';
import assert from 'node:assert/strict';
import {GoogleStorage} from '../google.mjs';

test('production storage adapter loses definitive HTTP rejection classification',async t=>{
  let requests=0;
  t.mock.method(globalThis,'fetch',async(url,options)=>{
    const target=new URL(url);
    assert.equal(target.hostname,'storage.googleapis.com');
    assert.equal(target.pathname,'/upload/storage/v1/b/mhflow-jobix-dev-pdfs/o');
    assert.equal(target.searchParams.get('ifGenerationMatch'),'0');
    assert.equal(options.method,'POST');
    requests++;
    // Definitive provider denial, not a timeout or possibly committed write.
    return new Response(JSON.stringify({error:{code:403,message:'Fixture-only denial'}}),{status:403});
  });
  const storage=new GoogleStorage({token:async()=>'synthetic-fixture-only'});
  await assert.rejects(storage.create('exports/fixture/operation/source.pdf',
    Buffer.from('%PDF-fixture-only'),{},new AbortController().signal),
    {code:'SERVICE_UNAVAILABLE'});
  assert.equal(requests,1);
});
