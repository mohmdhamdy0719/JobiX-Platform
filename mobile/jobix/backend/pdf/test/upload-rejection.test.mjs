import test from 'node:test';
import assert from 'node:assert/strict';
import {GoogleStorage,isDefinitiveUploadRejection} from '../google.mjs';
import {ExportError} from '../document.mjs';
const path='exports/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222/source.pdf';
const fence='33333333-3333-4333-8333-333333333333';
const storage=()=>new GoogleStorage({token:async()=>'synthetic-fixture-only'});
async function errorFromCreate(adapter=storage()) {
  try {await adapter.create(path,Buffer.from('%PDF-fixture-only'),{upload_fence:fence},
    new AbortController().signal);}
  catch(error){return error;}
  assert.fail('Expected injected error');
}
for(const status of [401,403])test(`HTTP ${status} has exact-attempt no-write evidence`,async t=>{
  t.mock.method(globalThis,'fetch',async(url,options)=>{
    const target=new URL(url);
    assert.equal(target.hostname,'storage.googleapis.com');
    assert.equal(target.searchParams.get('ifGenerationMatch'),'0');
    assert.equal(options.method,'POST');
    assert.equal(options.redirect,'error');
    return new Response('{}',{status});
  });
  const error=await errorFromCreate();
  assert.equal(error.code,'UPLOAD_HTTP_'+status);
  assert.equal(error.httpStatus,status);
  assert.ok(isDefinitiveUploadRejection(error,path,fence));
  assert.equal(isDefinitiveUploadRejection(error,path,'another-fence'),false);
  assert.equal(isDefinitiveUploadRejection(error,path+'/another-object',fence),false);
  const forged=Object.assign(new ExportError(error.code),{httpStatus:status,path,fence});
  assert.equal(isDefinitiveUploadRejection(forged,path,fence),false);
});
for(const status of [408,429,500,503])test(`HTTP ${status} preserves classification but remains ambiguous`,async t=>{
  t.mock.method(globalThis,'fetch',async()=>new Response('{}',{status}));
  const error=await errorFromCreate();
  assert.equal(error.code,'UPLOAD_HTTP_'+status);
  assert.equal(error.httpStatus,status);
  assert.equal(isDefinitiveUploadRejection(error,path,fence),false);
});
for(const name of ['TimeoutError','TypeError'])test(`${name} cannot settle a possibly committed upload`,async t=>{
  t.mock.method(globalThis,'fetch',async()=>{const error=new Error('Synthetic transport loss');error.name=name;throw error;});
  const error=await errorFromCreate();
  assert.equal(isDefinitiveUploadRejection(error,path,fence),false);
});
test('success response lost after write remains unresolved',async t=>{
  let written=false;
  t.mock.method(globalThis,'fetch',async()=>{
    written=true;return {ok:true,status:201,json:async()=>{throw new Error('Synthetic response-body loss');}};
  });
  const error=await errorFromCreate();
  assert.ok(written);assert.equal(isDefinitiveUploadRejection(error,path,fence),false);
});
test('token failure before physical create proves no request sent',async t=>{
  t.mock.method(globalThis,'fetch',async()=>assert.fail('No upload may be issued'));
  const error=await errorFromCreate(new GoogleStorage({token:async()=>{throw new Error('Synthetic metadata failure');}}));
  assert.equal(error.code,'UPLOAD_NOT_SENT');
  assert.ok(isDefinitiveUploadRejection(error,path,fence));
});
test('attempt identity is captured before awaiting the provider',async t=>{
  const metadata={upload_fence:fence};
  const other='44444444-4444-4444-8444-444444444444';
  t.mock.method(globalThis,'fetch',async()=>{metadata.upload_fence=other;return new Response('{}',{status:403});});
  let error;
  try{await storage().create(path,Buffer.from('%PDF-fixture'),metadata);}
  catch(result){error=result;}
  assert.ok(isDefinitiveUploadRejection(error,path,fence));
  assert.equal(isDefinitiveUploadRejection(error,path,other),false);
});
