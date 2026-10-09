import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createSign,generateKeyPairSync} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {createBridge,origin,gatewayIdentity,workerTarget,publicClientKey} from '../../export-gateway/core.mjs';
import {GatewayIdentity} from '../../export-gateway/identity.mjs';
import {readCommand,forwardCommand,gatewayTarget} from '../../../supabase/functions/resume-export/transport.mjs';
import {Gateway} from '../gateway.mjs';
import {server} from '../server.mjs';
import {authenticateInternal} from '../google.mjs';
import {ExportError,bundle,sha256} from '../document.mjs';

const actor='11111111-1111-4111-8111-111111111111';
const other='22222222-2222-4222-8222-222222222222';
const profile='33333333-3333-4333-8333-333333333333';
const target='https://jobix-dev-pdf-export-fixture.a.run.app';
const clientKey='sb_publishable_fixture';
const json=(body,status=200)=>new Response(JSON.stringify(body),{status});
function bearer(changes={}) {
  const b64=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
  return 'Bearer '+b64({alg:'ES256'})+'.'+b64({
    iss:origin+'/auth/v1',aud:'authenticated',sub:actor,exp:Math.floor(Date.now()/1000)+3600,
    ...changes,
  })+'.fixture';
}
function request(envelope={action:'history',command:{}},options={}) {
  return new Request('https://bridge.test/resume-export',{method:'POST',
    headers:{Authorization:bearer(),'Content-Type':'application/json',...options.headers},
    body:JSON.stringify(envelope)});
}
function setup({user={id:actor},authStatus=200,authFailure,worker,enabled=true}={}) {
  const authCalls=[],workerCalls=[];let identities=0;
  const handle=createBridge({target,clientKey,exportsEnabled:enabled,
    identity:async()=>{identities++;return 'google-id-token';},
    fetchImpl:async(url,options)=>{
      if(url===origin+'/auth/v1/user') {
        authCalls.push(options);
        if(authFailure)throw authFailure;
        return json(user,authStatus);
      }
      assert.equal(url,target+'/command');
      const body=JSON.parse(options.body);workerCalls.push(body);
      assert.equal(options.headers.Authorization,'Bearer google-id-token');
      return worker?worker(body,options):json({data:{jobs:[]},error:null});
    }});
  return {handle,authCalls,workerCalls,identities:()=>identities};
}
test('bridge independently verifies identity and derives the only actor',async()=>{
  const f=setup(),result=await f.handle(request());
  assert.equal(result.status,200);assert.equal(f.authCalls.length,1);
  assert.equal(f.authCalls[0].redirect,'error');
  assert.equal(f.authCalls[0].headers.apikey,clientKey);
  assert.deepEqual(f.workerCalls,[{actor,action:'history',command:{}}]);
  assert.equal(result.headers.get('Cache-Control'),'no-store');
});
for(const [name,token] of [
  ['expired',bearer({exp:1})],['wrong-project',bearer({iss:'https://other.supabase.co/auth/v1'})],
  ['wrong-audience',bearer({aud:'service_role'})],['invalid','Bearer malformed'],
])test(name+' bearer fails before any privileged call',async()=>{
  const f=setup(),result=await f.handle(request(undefined,{headers:{Authorization:token}}));
  assert.equal(result.status,401);assert.equal(f.workerCalls.length,0);assert.equal(f.identities(),0);
});
test('missing bearer fails closed',async()=>{
  const f=setup();const r=request();r.headers.delete('Authorization');
  assert.equal((await f.handle(r)).status,401);assert.equal(f.workerCalls.length,0);
});
for(const authStatus of [401,403,500])test('Auth verification rejection '+authStatus+' fails closed',async()=>{
  const f=setup({authStatus}),result=await f.handle(request());
  assert.equal(result.status,authStatus===500?503:401);assert.equal(f.workerCalls.length,0);
  assert.equal((await result.json()).error.code,authStatus===500?'SERVICE_UNAVAILABLE':'AUTH_REQUIRED');
  assert.equal(f.identities(),0);
});
for(const [name,authFailure] of [
  ['network outage',new TypeError('fixture network failure')],
  ['timeout',new DOMException('fixture verification timeout','TimeoutError')],
])test('genuine Supabase verification '+name+' fails closed as SERVICE_UNAVAILABLE',async()=>{
  const f=setup({authFailure}),result=await f.handle(request());
  assert.equal(result.status,503);
  assert.equal((await result.json()).error.code,'SERVICE_UNAVAILABLE');
  assert.equal(f.authCalls.length,1);assert.equal(f.workerCalls.length,0);assert.equal(f.identities(),0);
});
test('valid-looking unverified claims cannot override the Auth response',async()=>{
  const f=setup({user:{id:other}});
  assert.equal((await f.handle(request())).status,401);assert.equal(f.workerCalls.length,0);
});
test('Auth-deleted user cannot reach worker',async()=>{
  const f=setup({user:{id:actor,deleted_at:'2026-01-01'}});
  assert.equal((await f.handle(request())).status,403);assert.equal(f.workerCalls.length,0);
});
test('authenticated but disabled Auth account is ACCOUNT_DELETING, not a verification outage',async()=>{
  const f=setup({user:{id:actor,disabled:true}}),result=await f.handle(request());
  assert.equal(result.status,403);assert.equal((await result.json()).error.code,'ACCOUNT_DELETING');
  assert.equal(f.authCalls.length,1);assert.equal(f.workerCalls.length,0);assert.equal(f.identities(),0);
});
for(const forged of [
  {action:'history',command:{},actor:other},
  {action:'history',command:{actor:other}},
  {action:'create',command:{payload:{user_id:other}}},
])test('caller identity override is rejected '+JSON.stringify(forged),async()=>{
  const f=setup();assert.equal((await f.handle(request(forged))).status,403);
  assert.equal(f.workerCalls.length,0);
});
for(const header of ['X-User-Id','X-Jobix-Actor','X-Apigateway-Api-Userinfo',
  'X-Goog-Authenticated-User-Email','X-Serverless-Authorization']) {
  test('forged identity header '+header+' is rejected',async()=>{
    const f=setup();assert.equal((await f.handle(request(undefined,{headers:{[header]:other}}))).status,403);
    assert.equal(f.workerCalls.length,0);
  });
}
test('closed export gate verifies Auth but never acquires Google credentials or calls worker',async()=>{
  const f=setup({enabled:false});assert.equal((await f.handle(request())).status,503);
  assert.equal(f.authCalls.length,1);assert.equal(f.identities(),0);assert.equal(f.workerCalls.length,0);
});
for(const action of ['recover','dispatch','cleanup','retention','freeze','purge','delete']) {
  test('worker-only action '+action+' is rejected at public bridge',async()=>{
    const f=setup();assert.equal((await f.handle(request({action,command:{}}))).status,400);
    assert.equal(f.workerCalls.length,0);
  });
}
test('oversized input rejected without privileged calls',async()=>{
  const f=setup(),r=request({action:'history',command:{padding:'a'.repeat(33000)}});
  assert.equal((await f.handle(r)).status,400);assert.equal(f.workerCalls.length,0);
});
test('unexpected upstream error body is never reflected',async()=>{
  const f=setup({worker:async()=>json({secret:'must-not-be-returned'},500)});
  const result=await f.handle(request());assert.equal(result.status,503);
  assert.ok(!(await result.text()).includes('must-not-be-returned'));
});
test('cross-account access and inactive app account fail through authoritative Gateway checks',async()=>{
  let active=true,renderCalls=0;const dbCalls=[];
  const gateway=new Gateway({enabled:true,canonicalizer:{prepare:async()=>{
    renderCalls++;assert.fail('Unauthorized/inactive requests must not reach canonicalization');
  }},db:{call:async(name,args)=>{
    dbCalls.push({name,args});
    if(!active)throw new ExportError('ACCOUNT_DELETING');
    if(name==='source'&&(args.actor!==actor||args.profile!==profile))throw new ExportError('FORBIDDEN');
    return {};
  }}});
  const f=setup({worker:async(body)=>{
    try{return json({data:await gateway.handle(body.actor,body.action,body.command),error:null});}
    catch(error){return json({data:null,error:{code:error.code}},error.code==='FORBIDDEN'?403:503);}
  }});
  const denied=await f.handle(request({action:'document',command:{profile_id:other}}));
  assert.equal(denied.status,403);
  assert.equal((await denied.json()).error.code,'FORBIDDEN');
  assert.deepEqual(dbCalls,[{name:'source',args:{actor,profile:other}}]);
  assert.equal(renderCalls,0);
  active=false;const deleted=await f.handle(request());
  // Preserve the existing worker's HTTP mapping, while retaining the specific
  // application-account error instead of mislabelling it a verification outage.
  assert.equal(deleted.status,503);
  assert.equal((await deleted.json()).error.code,'ACCOUNT_DELETING');
  assert.equal(dbCalls[1].name,'history');assert.equal(dbCalls[1].args.actor,actor);
  assert.equal(f.authCalls.length,2);assert.equal(f.workerCalls.length,2);assert.equal(renderCalls,0);
});
test('timeout after commit replays unchanged command/key with one fixture reservation',async()=>{
  let reservations=0,loseResponse=true;const records=new Map();
  const command={request_id:'44444444-4444-4444-8444-444444444444',
    idempotency_key:'55555555-5555-4555-8555-555555555555',expected_profile_version:1,
    payload:{profile_id:profile,expected_configuration_version:0,
      expected_document_sha256:sha256('html'),renderer_bundle_version:bundle}};
  const gateway=new Gateway({enabled:true,canonicalizer:{prepare:async()=>({
    html:'html',source_sha256:sha256('source'),document_sha256:sha256('html'),
    profile_version:1,configuration_version:0,issues:[],
  })},db:{call:async(name,args)=>{
    if(name==='source')return {};
    const key=args.actor+':'+args.command;
    if(name==='replay')return records.get(key)??null;
    assert.equal(name,'create');reservations++;
    const result={operation_id:'same-operation',state:'QUEUED'};records.set(key,result);return result;
  }}});
  const f=setup({worker:async(body)=>{
    const data=await gateway.handle(body.actor,body.action,body.command);
    if(loseResponse){loseResponse=false;throw new DOMException('fixture timeout','TimeoutError');}
    return json({data,error:null});
  }});
  const envelope={action:'create',command};
  assert.equal((await f.handle(request(envelope))).status,503);
  const retry=await f.handle(request(envelope));
  assert.equal(retry.status,200);assert.equal((await retry.json()).data.operation_id,'same-operation');
  assert.equal(reservations,1);assert.deepEqual(f.workerCalls[0],f.workerCalls[1]);
});
test('Edge forwarding preserves exact body and original user token without adding actor',async()=>{
  const r=request({action:'history',command:{request_id:'unchanged'}});
  const parsed=await readCommand(r);let sent;
  await forwardCommand({target:'https://jobix-dev-export-gateway-fixture.a.run.app',...parsed,
    fetchImpl:async(url,options)=>{sent={url,options};return json({data:null,error:null});}});
  assert.equal(sent.options.body,parsed.raw);
  assert.equal(sent.options.headers.Authorization,parsed.token);
  assert.ok(!Object.hasOwn(JSON.parse(sent.options.body),'actor'));
});
test('runtime targets and client keys reject substitutions and privileged keys',()=>{
  assert.throws(()=>workerTarget('https://evil.test'));
  assert.throws(()=>gatewayTarget('https://jobix-dev-pdf-export-fixture.run.app'));
  assert.throws(()=>publicClientKey('not-a-public-key'));
  assert.throws(()=>publicClientKey('a.'+Buffer.from('{"role":"service_role"}').toString('base64url')+'.c'));
});
test('actual managed Cloud Run hostname format passes gateway configuration without acquiring credentials',()=>{
  const actualWorker='https://jobix-dev-pdf-export-mnvzhiynwa-ww.a.run.app';
  assert.equal(workerTarget(actualWorker),actualWorker);
  assert.doesNotThrow(()=>new GatewayIdentity(actualWorker));
  assert.doesNotThrow(()=>createBridge({target:actualWorker,clientKey,
    exportsEnabled:false,identity:async()=>assert.fail('No startup credentials may be acquired here')}));
  const gateway='https://jobix-dev-export-gateway-fixture.a.run.app';
  assert.equal(gatewayTarget(gateway),gateway);
});
for(const [name,validate,prefix] of [
  ['worker',workerTarget,'jobix-dev-pdf-export'],
  ['gateway',gatewayTarget,'jobix-dev-export-gateway'],
])test(name+' managed-hostname fix preserves fail-closed URL restrictions',()=>{
  const host=prefix+'-fixture.a.run.app';
  for(const invalid of [
    'http://'+host,'https://'+host+'.evil.example',
    'https://'+prefix+'-fixture.evil.run.app',
    'https://unrelated-service-fixture.a.run.app',
    'https://jobix-production-fixture.a.run.app',
    'https://user@'+host,'https://user:password@'+host,
    'https://'+host+'?redirect=evil','https://'+host+'#fragment',
    'https://'+host+'/unexpected-path',
  ])assert.throws(()=>validate(invalid),{code:'EXPORT_NOT_READY'});
});
test('existing accepted hostname format remains compatible',()=>{
  assert.equal(workerTarget('https://jobix-dev-pdf-export-fixture.run.app'),
    'https://jobix-dev-pdf-export-fixture.run.app');
  assert.equal(gatewayTarget('https://jobix-dev-export-gateway-fixture.run.app'),
    'https://jobix-dev-export-gateway-fixture.run.app');
});
test('metadata identity uses attached gateway account, not downloaded keys or impersonation',async()=>{
  const previous={project:process.env.GCP_PROJECT_ID,service:process.env.K_SERVICE};
  process.env.GCP_PROJECT_ID='mhflow-jobix';process.env.K_SERVICE='jobix-dev-export-gateway';
  try {
    const urls=[];const identity=new GatewayIdentity(target,{fetchImpl:async(url,options)=>{
      urls.push(url);assert.equal(options.headers['Metadata-Flavor'],'Google');
      return new Response(url.endsWith('/email')?gatewayIdentity:'google.id.token');
    }});
    assert.equal(await identity.token(),'google.id.token');
    assert.equal(new URL(urls[1]).searchParams.get('audience'),target);
    const denied=new GatewayIdentity(target,{fetchImpl:async()=>new Response('wrong-account')});
    await assert.rejects(denied.token(),{code:'FORBIDDEN'});
  }finally{
    if(previous.project===undefined)delete process.env.GCP_PROJECT_ID;else process.env.GCP_PROJECT_ID=previous.project;
    if(previous.service===undefined)delete process.env.K_SERVICE;else process.env.K_SERVICE=previous.service;
  }
});
test('Google-signed bridge ID token is accepted; anonymous worker and forbidden paths are denied',async()=>{
  const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
  const kid='bridge-fixture',key={...publicKey.export({format:'jwk'}),kid};
  const part=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
  const content=part({alg:'RS256',kid})+'.'+part({iss:'https://accounts.google.com',aud:target,
    iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+600,
    email:gatewayIdentity,email_verified:true});
  const token=content+'.'+createSign('RSA-SHA256').update(content).sign(privateKey,'base64url');
  const original=globalThis.fetch;
  let s;
  try {
    globalThis.fetch=async url=>{assert.equal(url,'https://www.googleapis.com/oauth2/v3/certs');return json({keys:[key]});};
    assert.equal(await authenticateInternal('Bearer '+token,target),gatewayIdentity);
    await assert.rejects(authenticateInternal(undefined,target),{code:'FORBIDDEN'});
    await assert.rejects(authenticateInternal('Bearer '+token,'https://wrong.run.app'),{code:'FORBIDDEN'});
    globalThis.fetch=original;
    let mutations=0;
    s=server({authenticate:header=>authenticateInternal(header,target),
      gateway:{handle:async()=>({jobs:[]})},worker:{
        recover:async()=>{mutations++;},dispatch:async()=>{mutations++;}},
      cleanup:{retention:async()=>{mutations++;},deletions:async()=>{mutations++;}}});
    s.listen(0,'127.0.0.1');await once(s,'listening');
    const base='http://127.0.0.1:'+s.address().port;
    for(const path of ['/recover','/dispatch','/cleanup','/retention','/deletion']) {
      const r=await original(base+path,{method:'POST',headers:{Authorization:'Bearer '+token},body:'{}'});
      assert.equal(r.status,403);assert.equal((await r.json()).error.code,'FORBIDDEN');
    }
    const allowed=await original(base+'/command',{method:'POST',headers:{Authorization:'Bearer '+token},
      body:JSON.stringify({actor,action:'history',command:{}})});
    assert.equal(allowed.status,200);assert.equal(mutations,0);
    const injected=await original(base+'/command',{method:'POST',headers:{Authorization:'Bearer '+token},
      body:JSON.stringify({actor,action:'purge',command:{}})});
    assert.equal(injected.status,403);
    const anonymous=await original(base+'/command',{method:'POST',body:'{}'});
    assert.equal(anonymous.status,403);
  }finally{globalThis.fetch=original;if(s)await new Promise(resolve=>s.close(resolve));}
});
test('Edge source has no Google private-key path and keeps both rollout gates',async()=>{
  const source=await readFile(new URL('../../../supabase/functions/resume-export/index.ts',import.meta.url),'utf8');
  for(const forbidden of ['private_key','IDENTITY_JSON','oauth2.googleapis.com','importKey','generateIdToken']) {
    assert.ok(!source.includes(forbidden));
  }
  assert.ok(source.includes('JOBIX_EXPORT_ENABLED'));
  assert.ok(source.includes('JOBIX_EXPORT_DELETION_POLICY_APPROVED'));
  assert.ok(source.includes('JOBIX_DEV_EXPORT_GATEWAY_URL'));
});
