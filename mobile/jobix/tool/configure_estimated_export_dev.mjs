// Owner-approved Development configuration only; never submits an export.
import {readFile,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {exportGates} from './phase3_export_gate_dev.mjs';
import {google,project,region} from './phase3_google.mjs';

const ref='lmouxhbjhtqdtiqijcee';
const assert=(value,code)=>{if(!value)throw Error(code);};
const sha=value=>createHash('sha256').update(value).digest('hex');
export const estimates=Object.freeze({
  shared_cost_reserve_microusd:3000000,
  runtime_cost_microusd_per_second:100,
  output_cost_microusd_per_gib_7d:12000,
  storage_operation_cost_microusd:7,
  per_export_overhead_microusd:25000,
});
const fields=Object.keys(estimates);
const expected021='147a14c1acb399237a831a994163ebf4006f82d718363e1c370ba937a838fae6';

async function sourceLedger() {
  const dir=resolve(import.meta.dirname,'../supabase/migrations');
  const files=(await readdir(dir)).filter(name=>/^\d{8}00(1[2-9]|2[01])_.*\.sql$/.test(name)).sort();
  assert(files.length===10,'SOURCE_MIGRATION_SET_REQUIRED');
  const rows=await Promise.all(files.map(async name=>({
    version:name.slice(0,-4),sha256:sha(await readFile(resolve(dir,name))),
  })));
  assert(rows.at(-1).version==='202610100021_resume_export_cost_output_unit'&&
    rows.at(-1).sha256===expected021,'MIGRATION_021_SOURCE_CHECKSUM_REQUIRED');
  return rows;
}

async function ledgerMatches(client) {
  const expected=await sourceLedger();
  const actual=(await client.query(
    'SELECT version,sha256 FROM public.jobix_export_migrations ORDER BY version')).rows;
  assert(isDeepStrictEqual(actual,expected),'MIGRATION_LEDGER_CHECKSUM_CONFLICT');
}

async function policy(client,lock=false) {
  const rows=(await client.query(`SELECT *,rolling_window=interval '7 days' AS seven_days
    FROM public.export_cost_budget_policy WHERE singleton${lock?' FOR UPDATE':''}`)).rows;
  assert(rows.length===1,'EXACT_POLICY_ROW_REQUIRED');
  const p=rows[0];
  assert(Number(p.budget_microusd)===10000000&&p.seven_days&&
    Number(p.max_runtime_ms)===1800000&&Number(p.max_pdf_bytes)===10485760&&
    p.max_storage_operations===24,'UNCHANGED_BUDGET_AND_CAPS_REQUIRED');
  return p;
}

async function gates(client,lock=false) {
  const rows=(await client.query(`SELECT enabled,deletion_policy_approved
    FROM public.export_settings WHERE singleton${lock?' FOR UPDATE':''}`)).rows;
  assert(rows.length===1&&rows[0].deletion_policy_approved===true,'APPROVED_DELETION_POLICY_REQUIRED');
  return rows[0];
}

async function noOutstandingWork(client) {
  const r=(await client.query(`SELECT
    EXISTS(SELECT FROM public.export_jobs WHERE state IN
      ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE','DELETION_PENDING')) AS active,
    EXISTS(SELECT FROM public.export_upload_flights WHERE state<>'SETTLED') AS flights,
    EXISTS(SELECT FROM public.export_cost_reservations WHERE state='HELD') AS held,
    EXISTS(SELECT FROM public.export_jobs j JOIN public.credit_reservations r
      ON r.id=j.reservation_id WHERE r.state='PENDING') AS credits`)).rows[0];
  assert(Object.values(r).every(value=>value===false),'OUTSTANDING_EXPORT_WORK_BLOCKS_CONFIGURATION');
}

function configured(p) {
  return p.accounting_ready===true&&p.model_version===2&&
    fields.every(key=>Number(p[key])===estimates[key]);
}

export async function configureCosts(client) {
  await ledgerMatches(client);
  const p=await policy(client,true),g=await gates(client,true);
  assert(!g.enabled,'DATABASE_GATE_MUST_REMAIN_CLOSED_DURING_CONFIGURATION');
  await noOutstandingWork(client);
  if(configured(p))return false;
  assert(!p.accounting_ready&&p.model_version===1&&fields.every(key=>p[key]===null),
    'INITIAL_UNCONFIGURED_MODEL_REQUIRED');
  await client.query(`UPDATE public.export_cost_budget_policy SET
    ${fields.map((key,i)=>`${key}=$${i+1}`).join(',')},
    model_version=2,accounting_ready=true,updated_at=clock_timestamp() WHERE singleton`,
  fields.map(key=>estimates[key]));
  assert(configured(await policy(client)),'ESTIMATED_ACCOUNTING_READBACK_FAILED');
  return true;
}

async function begin(client,readOnly=false) {
  await client.query(readOnly?'BEGIN TRANSACTION READ ONLY':'BEGIN');
  if(!readOnly) {
    await client.query("SET LOCAL lock_timeout='10s'");
    await client.query("SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))");
  }
}

async function transaction(client,callback,readOnly=false) {
  await begin(client,readOnly);
  try {const result=await callback();await client.query('COMMIT');return result;}
  catch(error){await client.query('ROLLBACK').catch(()=>{});throw error;}
}

// Supabase returns hashes from its secret-metadata endpoint. Only approved
// feature-flag comparisons are surfaced; no response body or hash is logged.
async function edgeGate(expected) {
  assert(process.env.JOBIX_DEV_SUPABASE_ACCESS_TOKEN,'EXISTING_EDGE_ACCESS_REQUIRED');
  const response=await fetch(`https://api.supabase.com/v1/projects/${ref}/secrets`,{
    headers:{Authorization:'Bearer '+process.env.JOBIX_DEV_SUPABASE_ACCESS_TOKEN},
    redirect:'error',signal:AbortSignal.timeout(20000),
  });
  assert(response.ok,'EDGE_GATE_METADATA_UNAVAILABLE');
  const metadata=await response.json();
  assert(Array.isArray(metadata),'EDGE_GATE_METADATA_INVALID');
  for(const [name,value] of [['JOBIX_EXPORT_ENABLED',String(expected)],
    ['JOBIX_EXPORT_DELETION_POLICY_APPROVED','true']]) {
    const item=metadata.find(row=>row.name===name);
    assert(item?.value===sha(value),'EDGE_GATE_METADATA_MISMATCH');
  }
}

const services=['jobix-dev-pdf-export','jobix-dev-export-gateway'];
async function cloudSnapshot(g) {
  const result=[];
  for(const name of services) {
    const url=`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services/${name}`;
    const s=await g.request(url),iam=await g.request(url+':getIamPolicy');
    assert(s.terminalCondition?.state==='CONDITION_SUCCEEDED'&&
      s.latestCreatedRevision===s.latestReadyRevision,'READY_EXISTING_SERVICE_REQUIRED');
    assert(!s.invokerIamDisabled,'INVOKER_AUTHENTICATION_REQUIRED');
    assert(s.traffic?.length===1&&s.traffic[0].type==='TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST'&&
      s.traffic[0].percent===100,'UNCHANGED_LATEST_TRAFFIC_REQUIRED');
    if(name===services[0])assert(!(iam.bindings??[]).some(b=>
      b.members?.some(m=>['allUsers','allAuthenticatedUsers'].includes(m))),'PRIVATE_WORKER_REQUIRED');
    result.push({service:s,iam});
  }
  return result;
}

function compareCloud(before,after) {
  return after.map(({service:s,iam},i)=>{
    const previous=before[i].service;
    const expected=structuredClone(previous.template),actual=structuredClone(s.template);
    // Revision names necessarily change when the environment gate changes.
    delete expected.revision;delete actual.revision;
    assert(expected.containers.length===1&&actual.containers.length===1,'SINGLE_EXISTING_CONTAINER_REQUIRED');
    const flag=expected.containers[0].env.find(e=>e.name==='JOBIX_EXPORT_ENABLED');
    assert(flag?.value==='false','CLOSED_BASELINE_REQUIRED');
    flag.value='true';
    assert(isDeepStrictEqual(actual,expected),'UNEXPECTED_REVISION_CONFIGURATION_CHANGE');
    for(const field of ['traffic','ingress','invokerIamDisabled','scaling','customAudiences',
      'defaultUriDisabled','iapEnabled','binaryAuthorization']) {
      assert(isDeepStrictEqual(s[field],previous[field]),'UNEXPECTED_SERVICE_CONFIGURATION_CHANGE');
    }
    assert(isDeepStrictEqual(iam.bindings,before[i].iam.bindings)&&
      iam.version===before[i].iam.version,'INVOKER_POLICY_CHANGED');
    return {service:services[i],revision:s.latestReadyRevision.split('/').at(-1),
      image:s.template.containers[0].image,ready:true,configurationPreserved:true,
      exportsEnabled:true,deletionPolicyApproved:true,iamPreserved:true};
  });
}

async function connectDevelopment(caFile) {
  assert(caFile&&process.env.JOBIX_DEV_DATABASE_URL,'EXISTING_DEV_CONNECTION_AND_CA_REQUIRED');
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  assert(['postgres:','postgresql:'].includes(uri.protocol)&&uri.username==='postgres.'+ref&&
    uri.hostname.endsWith('.pooler.supabase.com')&&uri.port==='5432'&&uri.pathname==='/postgres',
  'APPROVED_DEV_OBJECT_OWNER_TARGET_REQUIRED');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  const pool=new Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,
    statement_timeout:30000,ssl:{rejectUnauthorized:true,ca:await readFile(caFile,'utf8')}});
  try {
    const client=await pool.connect();
    try {
      const identity=(await client.query(`SELECT current_database()='postgres' AS database_ok,
        current_user='postgres' AND session_user='postgres' AS owner_ok,
        (SELECT pg_get_userbyid(relowner)=current_user FROM pg_class
          WHERE oid='public.export_cost_budget_policy'::regclass) AS table_owner,
        (SELECT pg_get_userbyid(proowner)=current_user FROM pg_proc
          WHERE oid='public.jobix_export_cost_estimate(bigint,bigint,integer)'::regprocedure) AS function_owner`)).rows[0];
      assert(Object.values(identity).every(value=>value===true),'APPROVED_OBJECT_OWNER_IDENTITY_REQUIRED');
      return {pool,client};
    }catch(error){client.release();throw error;}
  }catch(error){await pool.end();throw error;}
}

async function verifyDatabase(client,enabled) {
  await ledgerMatches(client);
  const p=await policy(client),g=await gates(client);
  assert(configured(p)&&g.enabled===enabled,'FINAL_ACCOUNTING_AND_GATE_VERIFICATION_FAILED');
  const result=(await client.query(`SELECT
    public.jobix_export_cost_estimate(30000,1048576,3) AS illustrative,
    public.jobix_export_cost_estimate(1800000,10485760,24) AS maximum`)).rows[0];
  assert(result.illustrative==='28033'&&result.maximum==='205286','FINAL_ESTIMATOR_VERIFICATION_FAILED');
  return {project:ref,...estimates,model_version:p.model_version,accounting_ready:p.accounting_ready,
    enabled:g.enabled,deletion_policy_approved:g.deletion_policy_approved,
    budget_microusd:Number(p.budget_microusd),maximum_export_microusd:Number(result.maximum),
    illustrative_export_microusd:Number(result.illustrative),ledgerChecksumsThrough021:true};
}

async function verifyDisposable() {
  const socket=process.env.JOBIX_DISPOSABLE_PG_SOCKET;
  assert(/^\/tmp\/jobix-rls\.[A-Za-z0-9]+\/socket$/.test(socket??''),'DISPOSABLE_LOCAL_SOCKET_REQUIRED');
  const pool=new Pool({host:socket,port:55439,database:'postgres',user:'runner',ssl:false,max:1,
    connectionTimeoutMillis:10000,statement_timeout:30000});
  const client=await pool.connect();
  try {
    const r=(await client.query(`SELECT current_database()='postgres' AND current_user='runner'
      AND inet_server_addr() IS NULL AND current_setting('listen_addresses')=''
      AND current_setting('unix_socket_directories')=$1
      AND current_setting('data_directory')=$2 AS isolated`,[socket,socket.replace(/\/socket$/,'/data')])).rows[0];
    assert(r.isolated,'DISPOSABLE_DATABASE_IDENTITY_REQUIRED');
    await begin(client);
    await client.query('CREATE TABLE public.jobix_export_migrations(version text PRIMARY KEY,sha256 text NOT NULL)');
    for(const row of await sourceLedger())await client.query(
      'INSERT INTO public.jobix_export_migrations VALUES($1,$2)',[row.version,row.sha256]);
    await client.query('UPDATE public.export_settings SET enabled=false,deletion_policy_approved=true WHERE singleton');
    const unchanged=async()=>(await client.query(`SELECT
      (SELECT count(*) FROM public.export_jobs) AS jobs,
      (SELECT count(*) FROM public.credit_transactions) AS transactions,
      (SELECT count(*) FROM public.credit_reservations) AS reservations,
      (SELECT coalesce(sum(finalized_balance),0) FROM public.credit_accounts) AS finalized,
      (SELECT coalesce(sum(reserved_balance),0) FROM public.credit_accounts) AS reserved`)).rows[0];
    const before=await unchanged();
    assert(await configureCosts(client),'INITIAL_CONFIGURATION_EXPECTED');
    assert(!(await configureCosts(client)),'CONFIGURATION_REPLAY_MUST_BE_IDEMPOTENT');
    await verifyDatabase(client,false);
    const rounding=(await client.query(`SELECT
      public.jobix_export_cost_estimate(0,0,0) AS overhead,
      public.jobix_export_cost_estimate(1,1,1) AS rounded,
      public.jobix_export_cost_estimate(1800001,1,1) IS NULL AS runtime_closed,
      public.jobix_export_cost_estimate(1,10485761,1) IS NULL AS size_closed,
      public.jobix_export_cost_estimate(1,1,25) IS NULL AS operations_closed`)).rows[0];
    assert(rounding.overhead==='25000'&&rounding.rounded==='25009'&&rounding.runtime_closed&&
      rounding.size_closed&&rounding.operations_closed,'ESTIMATED_ROUNDING_AND_CAPS_FAILED');
    await client.query('SAVEPOINT held_guard');
    await client.query(`INSERT INTO public.export_cost_reservations
      (operation,reserved_microusd,model_version,max_pdf_bytes) VALUES(gen_random_uuid(),1,2,10485760)`);
    let blocked=false;
    try {await configureCosts(client);}catch(error){blocked=error.message==='OUTSTANDING_EXPORT_WORK_BLOCKS_CONFIGURATION';}
    assert(blocked,'HELD_COST_MUST_BLOCK_CONFIGURATION');
    await client.query('ROLLBACK TO SAVEPOINT held_guard');
    await client.query('SAVEPOINT drift_guard');
    await client.query('UPDATE public.export_cost_budget_policy SET per_export_overhead_microusd=1 WHERE singleton');
    blocked=false;
    try {await configureCosts(client);}catch(error){blocked=error.message==='INITIAL_UNCONFIGURED_MODEL_REQUIRED';}
    assert(blocked,'PARTIAL_OR_DRIFTED_CONFIGURATION_MUST_BLOCK');
    await client.query('ROLLBACK TO SAVEPOINT drift_guard');
    assert(isDeepStrictEqual(await unchanged(),before),'CREDITS_AND_EXPORT_RECORDS_MUST_NOT_CHANGE');
    await client.query('ROLLBACK');
    console.log('PASS: estimated Development accounting: exact rates, model version, checksum ledger, rounding, caps, idempotency, held-cost/drift rejection, unchanged Credits/jobs, fixture rollback');
  }finally {await client.query('ROLLBACK').catch(()=>{});client.release();await pool.end();}
}

async function applyDevelopment(caFile) {
  const g=await google();
  const before=await cloudSnapshot(g);
  await edgeGate(false);
  const cloudGates=await exportGates(); // Existing identity/private-worker/Scheduler guards.
  const {pool,client}=await connectDevelopment(caFile);
  let databaseOpened=false,stage='configure_accounting';
  try {
    await transaction(client,()=>configureCosts(client));
    const configuredEvidence=await transaction(client,()=>verifyDatabase(client,false),true);
    console.log(JSON.stringify({event:'DEVELOPMENT_ESTIMATED_ACCOUNTING_CONFIGURED',...configuredEvidence}));
    stage='open_existing_development_cloud_edge_gates';
    await cloudGates.open(); // Exactly two gate-only revisions; no builds or dispatch.
    const evidence=compareCloud(before,await cloudSnapshot(g));
    await edgeGate(true);
    stage='enable_database_admission_last';
    await transaction(client,async()=>{
      assert(configured(await policy(client,true)),'CONFIGURED_ACCOUNTING_REQUIRED');
      assert(!(await gates(client,true)).enabled,'CLOSED_DATABASE_GATE_REQUIRED');
      await noOutstandingWork(client);
      const update=await client.query('UPDATE public.export_settings SET enabled=true WHERE singleton AND NOT enabled');
      assert(update.rowCount===1,'EXACT_DATABASE_GATE_UPDATE_REQUIRED');
    });
    databaseOpened=true;
    stage='read_only_final_verification';
    const database=await transaction(client,()=>verifyDatabase(client,true),true);
    console.log(JSON.stringify({event:'DEVELOPMENT_NORMAL_EXPORT_ENABLED',database,services:evidence,
      edgeExportsEnabled:true,workerPrivate:true,realExportInvoked:false,automaticTrialRelock:false}));
  }catch(error) {
    // Safety closure is not a one-export timer. Do not create extra Cloud Run
    // revisions on failure: the database admission gate is the final barrier.
    if(databaseOpened)await client.query('UPDATE public.export_settings SET enabled=false WHERE singleton')
      .catch(()=>{console.error('DATABASE_SAFETY_CLOSURE_UNVERIFIED');});
    console.error(JSON.stringify({event:'DEVELOPMENT_ENABLEMENT_BLOCKED',stage,
      code:/^[A-Z0-9_]+$/.test(error.code??'')?error.code:
        /^[A-Z0-9_]+$/.test(error.message??'')?error.message:'SANITIZED_OPERATION_ERROR',
      status:error.status??null,noAutomaticRetry:true}));
    process.exitCode=1;
  }finally {client.release();await pool.end();}
}

if(process.argv[1]&&resolve(process.argv[1])===import.meta.filename) {
  const args=process.argv.slice(2);
  try {
    if(args.length===1&&args[0]==='--verify-disposable')await verifyDisposable();
    else {
      assert(args.length===3&&args[0]==='--apply-development-estimated-accounting-and-enable'&&
        args[1]==='--ca-file'&&args[2],'EXPLICIT_DEVELOPMENT_ENABLEMENT_AND_CA_REQUIRED');
      await applyDevelopment(args[2]);
    }
  }catch(error) {
    console.error(JSON.stringify({event:'DEVELOPMENT_ESTIMATED_ACCOUNTING_BLOCKED',
      code:/^[A-Z0-9_]+$/.test(error.code??'')?error.code:
        /^[A-Z0-9_]+$/.test(error.message??'')?error.message:'SANITIZED_PREFLIGHT_ERROR',
      status:error.status??null}));
    process.exitCode=1;
  }
}
