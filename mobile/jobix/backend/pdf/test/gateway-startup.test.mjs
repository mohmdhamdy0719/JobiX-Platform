import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyPrivateWorker,startupDiagnostic} from '../../export-gateway/startup.mjs';
import {TransportError} from '../../../supabase/functions/resume-export/transport.mjs';

const target='https://jobix-dev-pdf-export-example.a.run.app';
const json=(code,status)=>new Response(JSON.stringify({data:null,error:{code}}),{status});
const fixture=(options={})=>({
  callWorkerImpl:async()=>json('ACCOUNT_DELETING',503),
  fetchImpl:async()=>json('FORBIDDEN',403),...options,
});
test('startup requires actual private-worker account denial and both privileged-path denials',async()=>{
  const paths=[];let identities=0;
  await verifyPrivateWorker(target,async()=>{identities++;return 'fixture-token';},
    fixture({fetchImpl:async(url,options)=>{
      paths.push(url);
      assert.equal(options.headers.Authorization,'Bearer fixture-token');
      return json('FORBIDDEN',403);
    }}));
  assert.deepEqual(paths,[target+'/recover',target+'/dispatch']);
  assert.equal(identities,1);
});
test('metadata identity failure is distinguished and never reaches the worker',async()=>{
  let calls=0;
  await assert.rejects(verifyPrivateWorker(target,async()=>{throw new TransportError('FORBIDDEN');},
    fixture({callWorkerImpl:async()=>{calls++;}})),error=>{
      assert.deepEqual(startupDiagnostic(error),{event:'DEVELOPMENT_EXPORT_GATEWAY_NOT_READY',
        stage:'metadata_identity',code:'FORBIDDEN'});
      return true;
    });
  assert.equal(calls,0);
});
test('unexpected worker history denial records only the safe status and code',async()=>{
  await assert.rejects(verifyPrivateWorker(target,async()=> 'fixture-token',
    fixture({callWorkerImpl:async()=>json('FORBIDDEN',403)})),error=>{
      assert.equal(startupDiagnostic(error).stage,'worker_history');
      assert.equal(startupDiagnostic(error).code,'FORBIDDEN');
      assert.equal(startupDiagnostic(error).status,403);
      return true;
    });
});
test('a Google ingress HTML denial is not mistaken for the required application denial',async()=>{
  await assert.rejects(verifyPrivateWorker(target,async()=> 'fixture-token',
    fixture({fetchImpl:async()=>new Response('<html>forbidden</html>',{status:403})})),error=>{
      assert.equal(startupDiagnostic(error).stage,'worker_recover_denial');
      assert.equal(startupDiagnostic(error).code,'INVALID_WORKER_RESPONSE');
      assert.equal(startupDiagnostic(error).status,403);
      return true;
    });
});
test('dispatch access remains a fatal startup failure, never a successful health check',async()=>{
  await assert.rejects(verifyPrivateWorker(target,async()=> 'fixture-token',
    fixture({fetchImpl:async url=>url.endsWith('/recover')?json('FORBIDDEN',403):
      new Response(JSON.stringify({data:{},error:null}),{status:200})})),error=>{
      assert.equal(startupDiagnostic(error).stage,'worker_dispatch_denial');
      assert.equal(startupDiagnostic(error).code,'UNEXPECTED_WORKER_RESPONSE');
      return true;
    });
});
test('diagnostics never disclose raw errors, tokens, provider bodies or unapproved fields',()=>{
  const error=Object.assign(new Error('fixture-secret-token-and-provider-body'),{
    body:'private',status:500,stage:'arbitrary-caller-stage'});
  const diagnostic=startupDiagnostic(error);
  assert.equal(diagnostic.code,'UNCLASSIFIED_STARTUP_FAILURE');
  assert.equal(diagnostic.stage,'configuration');
  assert.ok(!JSON.stringify(diagnostic).includes('fixture-secret'));
  assert.ok(!Object.hasOwn(diagnostic,'body'));
});
