// Shared Edge/bridge input policy. No Google credential acquisition here.
export const applicationActions=Object.freeze(['document','create','again','status','history','download']);
// Canonical preview and owner-scoped metadata reads never create an export,
// reserve Credits, generate a PDF or sign a download.
export const readOnlyActions=Object.freeze(['document','status','history']);
// A closed export gate also permits a free download of an existing completed
// export. The Gateway still enforces ownership, account state and object generation.
export const disabledGateActions=Object.freeze([...readOnlyActions,'download']);
const identityFields=new Set(['actor','user_id','userId','identity','claims','sub','headers']);
const identityHeaders=new Set(['x-actor','x-user-id','x-authenticated-user-id',
  'x-goog-authenticated-user-id','x-goog-authenticated-user-email',
  'x-apigateway-api-userinfo','x-forwarded-authorization','x-serverless-authorization']);
export class TransportError extends Error {
  constructor(code){super(code);this.code=code;}
}
export function rejectIdentityHeaders(headers) {
  for(const [name] of headers) {
    if(identityHeaders.has(name)||/^x-jobix-(actor|user|identity)/.test(name)) {
      throw new TransportError('FORBIDDEN');
    }
  }
}
export async function readCommand(request) {
  rejectIdentityHeaders(request.headers);
  if(request.method!=='POST')throw new TransportError('FORBIDDEN');
  const token=request.headers.get('Authorization');
  if(!token||token.length>8192||!/^Bearer [A-Za-z0-9._~-]+$/.test(token)) {
    throw new TransportError('AUTH_REQUIRED');
  }
  const reader=request.body?.getReader(),chunks=[];let size=0;
  if(!reader)throw new TransportError('VALIDATION_FAILED');
  try {
    for(;;) {
      const {value,done}=await reader.read();if(done)break;
      size+=value.byteLength;
      if(size>32000){await reader.cancel();throw new TransportError('VALIDATION_FAILED');}
      chunks.push(value);
    }
  }finally{reader.releaseLock();}
  const bytes=new Uint8Array(size);let offset=0;
  for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
  const raw=new TextDecoder('utf-8',{fatal:true}).decode(bytes);
  let envelope;try{envelope=JSON.parse(raw);}catch{throw new TransportError('VALIDATION_FAILED');}
  if(!envelope||Array.isArray(envelope)||typeof envelope!=='object') {
    throw new TransportError('VALIDATION_FAILED');
  }
  const stack=[envelope];
  while(stack.length) {
    const value=stack.pop();
    for(const [key,item] of Object.entries(value)) {
      if(identityFields.has(key))throw new TransportError('FORBIDDEN');
      if(item&&typeof item==='object')stack.push(item);
    }
  }
  if(Object.keys(envelope).some(k=>!['action','command'].includes(k))||
    !applicationActions.includes(envelope.action)||!envelope.command||
    typeof envelope.command!=='object'||Array.isArray(envelope.command)) {
    throw new TransportError('VALIDATION_FAILED');
  }
  return {token,envelope,raw};
}
export function gatewayTarget(target) {
  const url=new URL(target);
  if(url.protocol!=='https:'||!/^jobix-dev-export-gateway-[a-z0-9-]+(?:\.a)?\.run\.app$/.test(url.hostname)||
    url.username||url.password||url.search||url.hash||url.pathname!=='/') {
    throw new TransportError('EXPORT_NOT_READY');
  }
  return url.origin;
}
export async function forwardCommand({target,token,raw,fetchImpl=fetch}) {
  return fetchImpl(gatewayTarget(target)+'/resume-export',{
    method:'POST',redirect:'error',signal:AbortSignal.timeout(45000),
    headers:{Authorization:token,'Content-Type':'application/json'},body:raw,
  });
}
