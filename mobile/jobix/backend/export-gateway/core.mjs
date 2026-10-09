import {readCommand,TransportError,readOnlyActions,disabledGateActions} from '../../supabase/functions/resume-export/transport.mjs';
export const origin='https://lmouxhbjhtqdtiqijcee.supabase.co';
export const gatewayIdentity='jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
const known=new Set(['AUTH_REQUIRED','FORBIDDEN','ACCOUNT_DELETING','EXPORT_NOT_READY',
  'VALIDATION_FAILED','VERSION_CONFLICT','IDEMPOTENCY_KEY_REUSE','CREDIT_INSUFFICIENT',
  'RATE_LIMITED','NOT_FOUND','EXPORT_EXPIRED','EXPORT_OBJECT_MISSING',
  'STALE_LEASE','INVALID_STATE','CLEANUP_UNVERIFIED','SERVICE_UNAVAILABLE']);
export function response(code,status=503) {
  return new Response(JSON.stringify({data:null,error:{code}}),{status,headers});
}
export function workerTarget(target) {
  const url=new URL(target);
  if(url.protocol!=='https:'||!/^jobix-dev-pdf-export-[a-z0-9-]+(?:\.a)?\.run\.app$/.test(url.hostname)||
    url.username||url.password||url.search||url.hash||url.pathname!=='/') {
    throw new TransportError('EXPORT_NOT_READY');
  }
  return url.origin;
}
export function publicClientKey(value) {
  if(value?.startsWith('sb_publishable_'))return value;
  try {
    if(JSON.parse(atob(value.split('.')[1].replaceAll('-','+').replaceAll('_','/'))).role==='anon')return value;
  }catch{}
  throw new TransportError('EXPORT_NOT_READY');
}
export async function verifyUser(token,clientKey,fetchImpl=fetch,now=Date.now()) {
  let claims;
  try {
    const jwt=token.slice(7).split('.');
    if(jwt.length!==3)throw Error();
    claims=JSON.parse(atob(jwt[1].replaceAll('-','+').replaceAll('_','/')));
    if(claims.iss!==origin+'/auth/v1'||claims.aud!=='authenticated'||
      !uuid.test(claims.sub)||!Number.isFinite(claims.exp)||claims.exp<=now/1000)throw Error();
  }catch{throw new TransportError('AUTH_REQUIRED');}
  // JWT parsing above only rejects bad input. Auth verifies its signature and
  // user existence; unverified claims never establish an actor on their own.
  const verified=await fetchImpl(origin+'/auth/v1/user',{
    headers:{Authorization:token,apikey:publicClientKey(clientKey)},
    redirect:'error',signal:AbortSignal.timeout(10000),
  });
  if(verified.status===401||verified.status===403)throw new TransportError('AUTH_REQUIRED');
  if(!verified.ok)throw new TransportError('SERVICE_UNAVAILABLE');
  const user=await verified.json();
  if(!uuid.test(user.id)||user.id!==claims.sub)throw new TransportError('AUTH_REQUIRED');
  if(user.deleted_at||user.disabled===true||
    (user.banned_until&&Date.parse(user.banned_until)>now))throw new TransportError('ACCOUNT_DELETING');
  return user.id;
}
export async function callWorker({target,identity,actor,action,command,fetchImpl=fetch}) {
  const upstream=await fetchImpl(workerTarget(target)+'/command',{
    method:'POST',redirect:'error',signal:AbortSignal.timeout(45000),
    headers:{Authorization:'Bearer '+await identity(),'Content-Type':'application/json'},
    body:JSON.stringify({actor,action,command}),
  });
  const body=await upstream.json();
  if(!body||!Object.hasOwn(body,'data')||!Object.hasOwn(body,'error')||
    (body.error&&!known.has(body.error.code))||(!upstream.ok&&!body.error)) {
    throw new TransportError('SERVICE_UNAVAILABLE');
  }
  return new Response(JSON.stringify(body),{status:upstream.status,headers});
}
export function createBridge({clientKey,target,identity,fetchImpl=fetch,exportsEnabled=false,
  deletionPolicyApproved=true}) {
  publicClientKey(clientKey);workerTarget(target);
  return async request=>{
    try {
      if(new URL(request.url).pathname!=='/resume-export')return response('NOT_FOUND',404);
      const {token,envelope}=await readCommand(request);
      const actor=await verifyUser(token,clientKey,fetchImpl);
      // User identity must be verified even for non-billable owner-scoped reads.
      if((!exportsEnabled&&!disabledGateActions.includes(envelope.action))||
        (!deletionPolicyApproved&&!readOnlyActions.includes(envelope.action))) {
        throw new TransportError('EXPORT_NOT_READY');
      }
      return await callWorker({target,identity,actor,action:envelope.action,
        command:envelope.command,fetchImpl});
    }catch(error) {
      const code=error instanceof TransportError&&known.has(error.code)?error.code:'SERVICE_UNAVAILABLE';
      return response(code,code==='AUTH_REQUIRED'?401:code==='FORBIDDEN'||code==='ACCOUNT_DELETING'?403:
        code==='VALIDATION_FAILED'?400:503);
    }
  };
}
