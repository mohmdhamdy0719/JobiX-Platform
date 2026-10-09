import {callWorker} from './core.mjs';

const stages=new Set(['configuration','metadata_identity','worker_history',
  'worker_recover_denial','worker_dispatch_denial','listen']);
const codes=new Set(['AUTH_REQUIRED','FORBIDDEN','ACCOUNT_DELETING','EXPORT_NOT_READY',
  'VALIDATION_FAILED','NOT_FOUND','SERVICE_UNAVAILABLE','DEVELOPMENT_CONFIGURATION_REQUIRED',
  'UNEXPECTED_WORKER_RESPONSE','INVALID_WORKER_RESPONSE']);
class StartupFailure extends Error {
  constructor(stage,code,status) {
    super('STARTUP_CHECK_FAILED');
    this.stage=stage;this.code=code;this.status=status;
  }
}
export function startupDiagnostic(error,stage='configuration') {
  const phase=error instanceof StartupFailure?error.stage:stage;
  const code=error?.code??error?.message;
  return {event:'DEVELOPMENT_EXPORT_GATEWAY_NOT_READY',
    stage:stages.has(phase)?phase:'configuration',
    code:codes.has(code)?code:'UNCLASSIFIED_STARTUP_FAILURE',
    ...(Number.isInteger(error?.status)&&error.status>=100&&error.status<=599
      ?{status:error.status}:{})};
}
function failed(stage,error,status) {
  return new StartupFailure(stage,error?.code??error?.message,status);
}
// All startup requests are read-only or explicitly forbidden to this identity.
export async function verifyPrivateWorker(target,identity,{fetchImpl=fetch,callWorkerImpl=callWorker}={}) {
  let token;
  try{token=await identity();}
  catch(error){throw failed('metadata_identity',error);}
  let checked,body;
  try {
    checked=await callWorkerImpl({target,identity:async()=>token,
      actor:'00000000-0000-4000-8000-000000000001',action:'history',command:{},fetchImpl});
    body=await checked.json();
  }catch(error){throw failed('worker_history',error);}
  if(body.error?.code!=='ACCOUNT_DELETING') {
    throw new StartupFailure('worker_history',body.error?.code??'UNEXPECTED_WORKER_RESPONSE',checked.status);
  }
  for(const path of ['/recover','/dispatch']) {
    const stage=path==='/recover'?'worker_recover_denial':'worker_dispatch_denial';
    let result,denied;
    try {
      result=await fetchImpl(target+path,{method:'POST',redirect:'error',
        signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+token,
          'Content-Type':'application/json'},body:'{}'});
      denied=await result.json();
    }catch(error){throw failed(stage,result?{code:'INVALID_WORKER_RESPONSE'}:error,result?.status);}
    if(result.status!==403||denied.error?.code!=='FORBIDDEN') {
      throw new StartupFailure(stage,denied.error?.code??'UNEXPECTED_WORKER_RESPONSE',result.status);
    }
  }
}
