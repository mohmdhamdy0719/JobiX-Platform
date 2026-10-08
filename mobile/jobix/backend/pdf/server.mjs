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

export function server({gateway,worker,cleanup,authenticate}) {
  return createServer(async(req,res)=>{
    // Private endpoint; no application logs containing bodies/URLs/tokens.
    res.setHeader('Content-Type','application/json');
    res.setHeader('Cache-Control','no-store');
    try {
      if(req.method!=='POST')throw new ExportError('FORBIDDEN');
      const caller=await authenticate(req.headers.authorization);
      if(caller==='jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com' && req.url!=='/recover') {
        throw new ExportError('FORBIDDEN');
      }
      let bytes=0;const chunks=[];
      for await(const chunk of req) {
        bytes+=chunk.length;if(bytes>32000)throw new ExportError('VALIDATION_FAILED');
        chunks.push(chunk);
      }
      const input=JSON.parse(Buffer.concat(chunks));
      let result;
      if(req.url==='/recover') {
        result=await worker.recover();
        if(cleanup){await cleanup.retention();await cleanup.deletions();}
      }
      else if(req.url==='/dispatch')result=await worker.dispatch();
      else if(req.url==='/command')result=await gateway.handle(input.actor,input.action,input.command);
      else throw new ExportError('NOT_FOUND');
      res.end(JSON.stringify({data:result??null,error:null}));
    } catch(error) {
      const code=error instanceof ExportError?error.code:'SERVICE_UNAVAILABLE';
      res.statusCode=code==='FORBIDDEN'?403:code==='VALIDATION_FAILED'?400:503;
      res.end(JSON.stringify({data:null,error:{code}}));
    }
  });
}
async function main() {
  // Do not start a server or acquire cloud credentials without explicit rollout gates.
  if(process.env.JOBIX_EXPORT_ENABLED!=='true' ||
     process.env.JOBIX_EXPORT_DELETION_POLICY_APPROVED!=='true' ||
     process.env.GCP_PROJECT_ID!=='mhflow-jobix')throw new ExportError('EXPORT_NOT_READY');
  const db=await database(process.env.JOBIX_DEV_EXPORT_DATABASE_URL);
  const storage=new GoogleStorage();
  const gateway=new Gateway({db,storage,canonicalizer:new Canonicalizer(),enabled:true});
  const worker=new Worker({db,storage,renderer:new ChromiumRenderer(),enabled:true});
  const cleanup=new ExportCleanup({db,storage,enabled:true});
  server({gateway,worker,cleanup,authenticate:header=>authenticateInternal(header,
    process.env.JOBIX_DEV_EXPORT_WORKER_URL)}).listen(Number(process.env.PORT??8080),'0.0.0.0');
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  main().catch(()=>{process.stderr.write('EXPORT_NOT_READY\n');process.exitCode=1;});
}
