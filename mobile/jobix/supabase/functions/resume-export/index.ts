// Public application entry point; no Google keys or service-token minting.
import {readCommand,forwardCommand,TransportError} from './transport.mjs';
const project='lmouxhbjhtqdtiqijcee';
Deno.serve(async request=>{
  const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
  try {
    const {token,raw}=await readCommand(request);
    const origin=Deno.env.get('SUPABASE_URL');
    if(origin!==`https://${project}.supabase.co`)throw new TransportError('FORBIDDEN');
    const verified=await fetch(origin+'/auth/v1/user',{
      headers:{Authorization:token,apikey:Deno.env.get('SUPABASE_ANON_KEY')??''},
      redirect:'error',signal:AbortSignal.timeout(10000),
    });
    if(verified.status===401||verified.status===403)throw new TransportError('AUTH_REQUIRED');
    if(!verified.ok)throw new TransportError('SERVICE_UNAVAILABLE');
    const user=await verified.json();
    if(!user.id||user.deleted_at)throw new TransportError('AUTH_REQUIRED');
    if(Deno.env.get('JOBIX_EXPORT_ENABLED')!=='true'||
      Deno.env.get('JOBIX_EXPORT_DELETION_POLICY_APPROVED')!=='true') {
      throw new TransportError('EXPORT_NOT_READY');
    }
    const result=await forwardCommand({
      target:Deno.env.get('JOBIX_DEV_EXPORT_GATEWAY_URL')??'',token,raw,
    });
    return new Response(await result.text(),{status:result.status,headers});
  }catch(error) {
    const allowed=['EXPORT_NOT_READY','FORBIDDEN','AUTH_REQUIRED','VALIDATION_FAILED','SERVICE_UNAVAILABLE'];
    const code=error instanceof TransportError&&allowed.includes(error.code)?error.code:'SERVICE_UNAVAILABLE';
    return new Response(JSON.stringify({data:null,error:{code}}),{
      status:code==='AUTH_REQUIRED'?401:code==='FORBIDDEN'?403:code==='VALIDATION_FAILED'?400:503,headers,
    });
  }
});
