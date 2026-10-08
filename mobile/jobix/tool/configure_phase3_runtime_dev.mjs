// Development-only runtime binding/readiness. Never invokes the worker entrypoint.
import {google,project,projectNumber,region,backend,bucket} from './phase3_google.mjs';
export const serviceId='jobix-dev-pdf-export';
export const image='me-central1-docker.pkg.dev/mhflow-jobix/jobix-dev/pdf-worker@sha256:670a21879bd42deae556d2208b83571e5c0d145c10a58c51423027956412347d';
export const readiness=`
import {readFile} from 'node:fs/promises';
import {createServer} from 'node:http';
import {X509Certificate} from 'node:crypto';
import {database} from './database.mjs';
try {
 const assert=c=>{if(!c)throw Error('READINESS_FAILED');};
 assert(process.env.GCP_PROJECT_ID==='mhflow-jobix'&&process.env.JOBIX_EXPORT_ENABLED==='false');
 const identity=await fetch('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email',
  {headers:{'Metadata-Flavor':'Google'},signal:AbortSignal.timeout(5000)});
 assert(identity.ok&&(await identity.text())==='jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com');
 const path=process.env.JOBIX_DEV_DATABASE_CA_FILE;
 assert(path==='/opt/jobix/assets/certs/supabase-root-2021.crt');
 const cert=new X509Certificate(await readFile(path));
 assert(cert.fingerprint256==='80:70:25:AD:50:D4:ED:21:9D:2C:9C:7D:29:9C:00:4F:82:4E:B0:0C:F7:F6:5A:FE:F6:07:D0:7B:72:E6:CA:FA');
 const uri=new URL(process.env.JOBIX_DEV_EXPORT_DATABASE_URL);
 assert(decodeURIComponent(uri.username)==='jobix_export_runtime.lmouxhbjhtqdtiqijcee'&&!!uri.password&&uri.port==='5432');
 const db=await database(process.env.JOBIX_DEV_EXPORT_DATABASE_URL),client=await db.pool.connect();
 try {
  assert(client.connection.stream.encrypted===true&&client.connection.stream.authorized===true);
  await client.query('BEGIN READ ONLY');
  const role=(await client.query("SELECT current_user AS name,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=current_user")).rows[0];
  assert(role.name==='jobix_export_runtime'&&!Object.entries(role).some(([k,v])=>k!=='name'&&v));
  const expected=['source','replay','create','status','history','missing','claim','heartbeat','stage','finish','recover',
   'freeze','retention','cleaned','upload_begin','upload_settle','quiescent','purge','deletions'].map(n=>'jobix_export_'+n);
  const funcs=(await client.query("SELECT p.proname,has_function_privilege(current_user,p.oid,'EXECUTE') AS allowed FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=ANY($1::text[])",[expected])).rows;
  assert(expected.every(n=>funcs.some(f=>f.proname===n&&f.allowed)));
  await client.query('ROLLBACK');
 }finally{client.release();await db.pool.end();}
 const result={secretResolved:true,secretVersion:1,caPresent:true,tlsVerified:true,
  databaseRole:'jobix_export_runtime',requiredFunctionsReachable:true,exportProcessing:false};
 createServer((req,res)=>{
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  if(req.method!=='GET'||req.url!=='/ready'){res.statusCode=503;res.end('{"error":"EXPORT_NOT_READY"}');return;}
  res.end(JSON.stringify(result));
 }).listen(Number(process.env.PORT??8080),'0.0.0.0');
 console.log('READ_ONLY_DEVELOPMENT_RUNTIME_READY');
}catch{console.error('READ_ONLY_RUNTIME_CHECK_FAILED');process.exitCode=1;}
`;
export const configuration={
 labels:{product:'jobix',environment:'development',component:'pdf-export'},
 ingress:'INGRESS_TRAFFIC_ALL',invokerIamDisabled:false,
 template:{serviceAccount:backend,timeout:'300s',maxInstanceRequestConcurrency:1,
  scaling:{minInstanceCount:0,maxInstanceCount:1},containers:[{
   image,command:['node'],args:['--input-type=module','-e',readiness],
   env:[
    {name:'JOBIX_DEV_EXPORT_DATABASE_URL',valueSource:{secretKeyRef:{secret:'jobix-dev-export-database',version:'1'}}},
    {name:'JOBIX_DEV_DATABASE_CA_FILE',value:'/opt/jobix/assets/certs/supabase-root-2021.crt'},
    {name:'GCP_PROJECT_ID',value:project},
    {name:'JOBIX_EXPORT_ENABLED',value:'false'},
    {name:'JOBIX_EXPORT_DELETION_POLICY_APPROVED',value:'false'},
   ],ports:[{containerPort:8080}],resources:{limits:{cpu:'1',memory:'512Mi'},cpuIdle:true},
   startupProbe:{httpGet:{path:'/ready',port:8080},periodSeconds:5,timeoutSeconds:2,failureThreshold:24},
  }]},
};
async function main(){
 if(!process.argv.includes('--approved-development-runtime-configuration'))throw Error('EXPLICIT_APPROVAL_REQUIRED');
 const g=await google(),metadata=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}`);
 if(String(metadata.projectNumber)!==projectNumber)throw Error('DEV_PROJECT_GUARD');
 const parent=`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services`;
 let existing;
 try{existing=await g.request(parent+'/'+serviceId);}catch(e){if(e.status!==404)throw e;}
 // Never replace an already-running normal worker or another owner's revision.
 if(existing)throw Error('EXISTING_SERVICE_REQUIRES_CONFIGURATION_RECONCILIATION');
 const result=await g.request(parent+'?serviceId='+serviceId,{method:'POST',write:true,body:configuration});
 console.log(JSON.stringify({check:'DEVELOPMENT_READINESS_RUNTIME_CONFIGURATION_SUBMITTED',
  operation:result.name,serviceId,secretVersion:'1',workerProcessing:false}));
}
if(process.argv[1]===import.meta.filename)main().catch(e=>{
 console.error(JSON.stringify({check:'RUNTIME_CONFIGURATION_BLOCKED',status:e.status??0,
  permission:e.permission??null,code:['EXPLICIT_APPROVAL_REQUIRED','DEV_PROJECT_GUARD',
   'EXISTING_SERVICE_REQUIRES_CONFIGURATION_RECONCILIATION'].includes(e.message)?e.message:null}));
 process.exitCode=1;
});
