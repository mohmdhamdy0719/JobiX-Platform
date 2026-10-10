import {createServer} from 'node:http';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {database} from './database.mjs';
import {Canonicalizer,ExportError} from './document.mjs';
import {Gateway} from './gateway.mjs';
import {Worker} from './worker.mjs';
import {ChromiumRenderer} from './renderer.mjs';
import {GoogleStorage,authenticateInternal} from './google.mjs';
import {ExportCleanup} from './cleanup.mjs';
import {disabledGateActions} from '../../supabase/functions/resume-export/transport.mjs';

export function server({gateway,worker,cleanup,authenticate,exportsEnabled=true}) {
  return createServer(async(req,res)=>{
    // Private endpoint; no application logs containing bodies/URLs/tokens.
    res.setHeader('Content-Type','application/json');
    res.setHeader('Cache-Control','no-store');
    try {
      if(req.method!=='POST')throw new ExportError('FORBIDDEN');
      const caller=await authenticate(req.headers.authorization);
      if(caller==='jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com' && req.url!=='/command') {
        throw new ExportError('FORBIDDEN');
      }
      if(caller==='jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com' && req.url!=='/recover') {
        throw new ExportError('FORBIDDEN');
      }
      let bytes=0;const chunks=[];
      for await(const chunk of req) {
        bytes+=chunk.length;if(bytes>32000)throw new ExportError('VALIDATION_FAILED');
        chunks.push(chunk);
      }
      const input=JSON.parse(Buffer.concat(chunks));
      if(caller==='jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com' &&
        !['document','create','again','status','history','download'].includes(input.action)) {
        throw new ExportError('FORBIDDEN');
      }
      let result;
      if(req.url==='/recover') {
        // Disabling exports must not disable the approved deletion/retention contract.
        await worker.recover();
        if(!exportsEnabled)result={exportsEnabled:false};
        if(cleanup){await cleanup.retention();await cleanup.deletions();}
      }
      else if(req.url==='/dispatch') {
        if(!exportsEnabled)throw new ExportError('EXPORT_NOT_READY');
        result=await worker.dispatch();
      }
      else if(req.url==='/command') {
        // Canonical preview is a profile read, not PDF rendering or a persisted
        // export snapshot. No signing, reservations or export work while closed.
        if(!exportsEnabled&&!disabledGateActions.includes(input.action)) {
          throw new ExportError('EXPORT_NOT_READY');
        }
        result=await gateway.handle(input.actor,input.action,input.command);
      }
      else throw new ExportError('NOT_FOUND');
      res.end(JSON.stringify({data:result??null,error:null}));
    } catch(error) {
      const code=error instanceof ExportError?error.code:'SERVICE_UNAVAILABLE';
      const retryAfter=error instanceof ExportError?error.retryAfterSeconds:null;
      res.statusCode=code==='FORBIDDEN'?403:code==='VALIDATION_FAILED'?400:
        code==='RATE_LIMITED'?429:code==='EXPORT_IN_PROGRESS'?409:503;
      if(retryAfter!==null)res.setHeader('Retry-After',String(retryAfter));
      res.end(JSON.stringify({data:null,error:{code,
        ...(code==='SERVICE_UNAVAILABLE'
          ?{message:'Service is temporarily unavailable. Please try again later.'}:{}),
        ...(retryAfter===null?{}:{retry_after_seconds:retryAfter})}}));
    }
  });
}
async function main() {
  // A private runtime can verify read-only integration with export processing off.
  if(!['true','false'].includes(process.env.JOBIX_EXPORT_ENABLED) ||
     process.env.JOBIX_EXPORT_DELETION_POLICY_APPROVED!=='true' ||
     process.env.GCP_PROJECT_ID!=='mhflow-jobix')throw new ExportError('EXPORT_NOT_READY');
  const exportsEnabled=process.env.JOBIX_EXPORT_ENABLED==='true';
  const db=await database(process.env.JOBIX_DEV_EXPORT_DATABASE_URL);
  const storage=new GoogleStorage();
  const gateway=new Gateway({db,storage,canonicalizer:new Canonicalizer(),enabled:true});
  const worker=new Worker({db,storage,renderer:new ChromiumRenderer(),enabled:exportsEnabled});
  const cleanup=new ExportCleanup({db,storage,enabled:true});
  server({gateway,worker,cleanup,exportsEnabled,authenticate:header=>authenticateInternal(header,
    process.env.JOBIX_DEV_EXPORT_WORKER_URL)}).listen(Number(process.env.PORT??8080),'0.0.0.0');
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  main().catch(()=>{process.stderr.write('EXPORT_NOT_READY\n');process.exitCode=1;});
}
