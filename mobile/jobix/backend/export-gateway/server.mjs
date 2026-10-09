import {createServer} from 'node:http';
import {createBridge,callWorker,gatewayIdentity,response} from './core.mjs';
import {GatewayIdentity} from './identity.mjs';

// Read-only boot verification uses an absent fixture actor. It cannot create
// work, reserve/debit Credits, sign a URL or touch GCS. Not a user-auth bypass.
async function verifyPrivateWorker(target,identity) {
  const checked=await callWorker({target,identity,actor:'00000000-0000-4000-8000-000000000001',
    action:'history',command:{}});
  const body=await checked.json();
  if(body.error?.code!=='ACCOUNT_DELETING')throw Error('PRIVATE_WORKER_CHECK_FAILED');
  for(const path of ['/recover','/dispatch']) {
    const result=await fetch(target+path,{method:'POST',redirect:'error',
      signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+await identity(),
        'Content-Type':'application/json'},body:'{}'});
    const denied=await result.json();
    if(result.status!==403||denied.error?.code!=='FORBIDDEN')throw Error('WORKER_PATH_CHECK_FAILED');
  }
}
async function main() {
  if(process.env.GCP_PROJECT_ID!=='mhflow-jobix'||process.env.K_SERVICE!=='jobix-dev-export-gateway'||
    !['false','true'].includes(process.env.JOBIX_EXPORT_ENABLED))throw Error('DEVELOPMENT_CONFIGURATION_REQUIRED');
  const target=process.env.JOBIX_DEV_EXPORT_WORKER_URL;
  const identity=new GatewayIdentity(target),token=()=>identity.token();
  const bridge=createBridge({clientKey:process.env.JOBIX_DEV_SUPABASE_CLIENT_KEY,
    target,identity:token,exportsEnabled:process.env.JOBIX_EXPORT_ENABLED==='true'&&
      process.env.JOBIX_EXPORT_DELETION_POLICY_APPROVED==='true'});
  await verifyPrivateWorker(target,token);
  const server=createServer({maxHeaderSize:16384},async(req,res)=>{
    let result;
    try {
      if(req.method==='GET'&&req.url==='/ready') {
        result=new Response(JSON.stringify({ready:true,workerAuthenticationVerified:true,
          workerOnlyPathsDenied:true,exportsEnabled:process.env.JOBIX_EXPORT_ENABLED==='true'&&
            process.env.JOBIX_EXPORT_DELETION_POLICY_APPROVED==='true',identity:gatewayIdentity}),
        {headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
      }else {
        let size=0;const chunks=[];
        for await(const chunk of req) {
          size+=chunk.length;if(size>32000){result=response('VALIDATION_FAILED',400);break;}
          chunks.push(chunk);
        }
        if(!result) {
          const headers=new Headers();
          for(const [name,value] of Object.entries(req.headers)) {
            if(value!=null)headers.set(name,Array.isArray(value)?value.join(','):value);
          }
          result=await bridge(new Request('http://bridge.local'+req.url,{
            method:req.method,headers,
            ...(['GET','HEAD'].includes(req.method)?{}:{body:Buffer.concat(chunks)}),
          }));
        }
      }
    }catch{result=response('SERVICE_UNAVAILABLE');}
    res.writeHead(result.status,Object.fromEntries(result.headers));
    res.end(Buffer.from(await result.arrayBuffer()));
  });
  server.requestTimeout=15000;server.headersTimeout=10000;
  server.listen(Number(process.env.PORT??8080),'0.0.0.0');
  console.log('DEVELOPMENT_EXPORT_GATEWAY_READY_FLAGS_CLOSED');
}
main().catch(()=>{console.error('DEVELOPMENT_EXPORT_GATEWAY_NOT_READY');process.exitCode=1;});
