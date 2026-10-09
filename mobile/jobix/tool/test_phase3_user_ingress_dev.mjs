// Actual Supabase sessions, existing profiles, optional approved terminal fixtures.
// Never reserve/finalize Credits, render PDFs, change profiles or print credentials.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID,createHash} from 'node:crypto';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
const ref='lmouxhbjhtqdtiqijcee';
const assert=(condition,code)=>{if(!condition)throw Error(code);};
const hash=value=>createHash('sha256').update(value).digest('hex');
let stage='preconditions',pool,client,before,baselineSql,owners;
const actors=[],fixtures=[],checks=[];
async function authRequest(path,body,token) {
  const r=await fetch(`https://${ref}.supabase.co/auth/v1/${path}`,{
    method:'POST',headers:{apikey:config.SUPABASE_CLIENT_KEY,'Content-Type':'application/json',
      ...(token?{Authorization:'Bearer '+token}:{})},
    body:body===undefined?undefined:JSON.stringify(body),
    signal:AbortSignal.timeout(30000),redirect:'error',
  });
  const data=await r.json().catch(()=>null);
  if(!r.ok){const e=Error('DEV_TEST_AUTH_FAILED');e.status=r.status;
    e.authCode=/^[a-z_]{1,60}$/.test(data?.error_code??'')?data.error_code:null;throw e;}
  return data;
}
let config;
async function call(actor,target,action,command={}) {
  const r=await fetch(target,{method:'POST',headers:{apikey:config.SUPABASE_CLIENT_KEY,
    Authorization:'Bearer '+actor.token,'Content-Type':'application/json'},
    body:JSON.stringify({action,command}),redirect:'error',signal:AbortSignal.timeout(65000)});
  const data=await r.json().catch(()=>null);
  return {status:r.status,data:data?.data,error:data?.error?.code??null,
    // Safe classification, not provider text or customer data.
    layer:data&&Object.hasOwn(data,'data')?'application':'upstream'};
}
function record(actor,name,result,expected) {
  const pass=expected(result);
  checks.push({actor:actor.label,name,status:result.status,code:result.error,layer:result.layer,pass});
  console.log(JSON.stringify(checks.at(-1)));
  assert(pass,'LIVE_USER_PATH_CHECK_FAILED');
}
async function main() {
  assert(process.argv.includes('--approved-two-user-readonly'),'EXPLICIT_READONLY_TEST_APPROVAL_REQUIRED');
  config=JSON.parse(await readFile('mobile/jobix/config/dev.local.json','utf8'));
  assert(config.APP_ENV==='dev'&&config.SUPABASE_URL===`https://${ref}.supabase.co`,'DEV_AUTH_GUARD');
  const deployed=JSON.parse(await readFile('/tmp/jobix-readonly-deployed.json','utf8'));
  assert(deployed.exportsEnabled===false&&deployed.workerPrivate,'DISABLED_PRIVATE_WORKER_REQUIRED');
  const gateway=deployed.gatewayUri+'/resume-export',edge=config.SUPABASE_URL+'/functions/v1/resume-export';
  const ready=await fetch(deployed.gatewayUri+'/ready',{signal:AbortSignal.timeout(20000)});
  assert(ready.ok&&(await ready.json()).exportsEnabled===false,'EXPORTS_NOT_DISABLED');
  for(const label of ['A','B']) {
    stage='authenticate_'+label;
    const email=process.env['JOBIX_DEV_TEST_EMAIL_'+label],password=process.env['JOBIX_DEV_TEST_PASSWORD_'+label];
    assert(email&&password,'EXISTING_TEST_CREDENTIALS_REQUIRED');
    const session=await authRequest('token?grant_type=password',{email,password});
    assert(session.access_token&&/^[0-9a-f-]{36}$/.test(session.user?.id??''),'AUTH_SESSION_INVALID');
    actors.push({label,id:session.user.id,token:session.access_token});
    console.log(JSON.stringify({actor:label,authenticated:true}));
  }
  owners=actors.map(a=>a.id);assert(new Set(owners).size===2,'TWO_DISTINCT_TEST_ACCOUNTS_REQUIRED');
  stage='connect_verified_development_db';
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  assert(uri.username.endsWith('.'+ref)&&uri.hostname.endsWith('.pooler.supabase.com')&&
    uri.port==='5432'&&uri.pathname==='/postgres','DEV_DATABASE_GUARD');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  pool=new Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,
    statement_timeout:20000,ssl:{rejectUnauthorized:true,
      ca:await readFile('mobile/jobix/assets/certs/supabase-root-2021.crt','utf8')}});
  client=await pool.connect();
  stage='verify_existing_active_app_accounts';
  const accounts=(await client.query('SELECT id,status FROM public.users WHERE id=ANY($1::uuid[])',[owners])).rows;
  assert(accounts.length===2&&accounts.every(a=>a.status==='ACTIVE'),'EXISTING_ACTIVE_APP_ACCOUNTS_REQUIRED_NO_BACKFILL');
  const tables=[['users','id'],['career_profiles','user_id'],['credit_accounts','user_id'],
    ['credit_transactions','user_id'],['credit_reservations','user_id'],['ai_allowance_accounts','user_id'],
    ['export_jobs','user_id'],['export_snapshots','user_id']];
  baselineSql='SELECT jsonb_build_object('+tables.map(([table,column])=>
    `'${table}',(SELECT coalesce(jsonb_agg(fingerprint ORDER BY fingerprint),'[]'::jsonb) FROM
      (SELECT encode(sha256(convert_to(to_jsonb(t)::text,'UTF8')),'hex') AS fingerprint
       FROM public.${table} t WHERE ${column}=ANY($1::uuid[])) s)`).join(',')+
    ",'export_settings',(SELECT jsonb_agg(to_jsonb(s)) FROM public.export_settings s)) AS value";
  before=JSON.stringify((await client.query(baselineSql,[owners])).rows[0].value);
  for(const actor of actors) {
    stage='existing_owned_profile_'+actor.label;
    actor.profile=(await client.query(`SELECT id FROM public.career_profiles
      WHERE user_id=$1 AND status='ACTIVE' ORDER BY slot_number,id LIMIT 1`,[actor.id])).rows[0]?.id;
    assert(actor.profile,'EXISTING_ACTIVE_TEST_PROFILE_REQUIRED_NO_CREATION');
    actor.source=(await client.query('SELECT public.jobix_export_source($1,$2) AS value',
      [actor.id,actor.profile])).rows[0].value;
    stage='owned_preview_'+actor.label;
    const result=await call(actor,edge,'document',{profile_id:actor.profile});
    record(actor,'edge_full_path_owned_preview',result,r=>r.status===200&&r.error===null&&
      r.data?.source_sha256===actor.source.source_sha256&&
      r.data?.document_sha256===hash(r.data?.html??''));
    actor.document=result.data;
    record(actor,'direct_gateway_owned_preview',await call(actor,gateway,'document',
      {profile_id:actor.profile}),r=>r.status===200&&r.error===null&&
      r.data?.source_sha256===actor.source.source_sha256);
  }
  for(const actor of actors) {
    stage='cross_profile_'+actor.label;
    const other=actors.find(a=>a.id!==actor.id);
    for(const [name,target]of [['edge',edge],['direct_gateway',gateway]]) {
      record(actor,name+'_foreign_profile_denied',await call(actor,target,'document',
        {profile_id:other.profile}),r=>r.status===403&&r.error==='FORBIDDEN'&&r.data===null);
    }
    for(const action of ['create','again','download']) {
      for(const [name,target]of [['edge',edge],['direct_gateway',gateway]]) {
        record(actor,name+'_'+action+'_disabled',await call(actor,target,action,{}),
          r=>r.status===503&&r.error==='EXPORT_NOT_READY'&&r.data===null);
      }
    }
  }
  for(const actor of actors) {
    stage='find_reusable_owned_job_'+actor.label;
    actor.job=(await client.query('SELECT id FROM public.export_jobs WHERE user_id=$1 ORDER BY created_at DESC,id DESC LIMIT 1',
      [actor.id])).rows[0]?.id;
    if(actor.job)continue;
    assert(process.argv.includes('--approved-terminal-fixtures'),'TERMINAL_FIXTURE_APPROVAL_REQUIRED');
    stage='seed_terminal_fixture_'+actor.label;
    const f={owner:actor.id,profile:actor.profile,job:randomUUID(),snapshot:randomUUID(),reservation:randomUUID()};
    await client.query('BEGIN');
    try {
      await client.query(`INSERT INTO public.credit_reservations
        (id,user_id,operation_id,purpose,amount,state,expires_at)
        VALUES($1,$2,$3,'RESUME_EXPORT',2,'RELEASED',now())`,[f.reservation,f.owner,f.job]);
      await client.query(`INSERT INTO public.export_snapshots
        (id,user_id,profile_id,source,source_sha256,canonical_html,document_sha256,bundle)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8)`,[f.snapshot,f.owner,f.profile,actor.source.source,
        actor.document.source_sha256,actor.document.html,actor.document.document_sha256,actor.document.bundle]);
      await client.query(`INSERT INTO public.export_jobs
        (id,user_id,profile_id,snapshot_id,reservation_id,idempotency_key,request_sha256,
         acknowledgement,state,deadline,error_code)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,'FAILED',now(),'EXPORT_NOT_READY')`,
        [f.job,f.owner,f.profile,f.snapshot,f.reservation,randomUUID(),hash(f.job),
          {operation_id:f.job,state:'FAILED',isolated_terminal_fixture:true}]);
      await client.query('COMMIT');fixtures.push(f);actor.job=f.job;
    }catch(e){await client.query('ROLLBACK');throw e;}
    console.log(JSON.stringify({actor:actor.label,terminalFixtureCreated:true,creditCharge:false}));
  }
  for(const actor of actors) {
    stage='job_ownership_'+actor.label;
    const other=actors.find(a=>a.id!==actor.id),known=new Set((await client.query(
      'SELECT id FROM public.export_jobs WHERE user_id=$1',[actor.id])).rows.map(j=>j.id));
    for(const [name,target]of [['edge',edge],['direct_gateway',gateway]]) {
      record(actor,name+'_owned_job_status',await call(actor,target,'status',{export_id:actor.job}),
        r=>r.status===200&&r.data?.id===actor.job&&r.error===null);
      record(actor,name+'_foreign_job_hidden',await call(actor,target,'status',{export_id:other.job}),
        r=>r.error==='NOT_FOUND'&&r.data===null&&r.status!==200);
      record(actor,name+'_owned_history',await call(actor,target,'history',{}),
        r=>r.status===200&&Array.isArray(r.data?.jobs)&&r.data.jobs.some(j=>j.id===actor.job)&&
          r.data.jobs.every(j=>known.has(j.id))&&r.error===null);
      record(actor,name+'_foreign_history_cursor_denied',await call(actor,target,'history',{cursor:other.job}),
        r=>r.error==='NOT_FOUND'&&r.data===null&&r.status!==200);
    }
  }
  console.log(JSON.stringify({checksPassed:checks.length,realSupabaseUsers:2,pdfsGenerated:0,creditTransactions:0}));
}
try{await main();}
catch(e){console.error(JSON.stringify({stage,code:/^[A-Z_0-9]{3,80}$/.test(e.message??'')?e.message:
  /^[A-Z0-9]{5}$/.test(e.code??'')?e.code:'SUPPRESSED',status:e.status??null,authCode:e.authCode??null}));
  process.exitCode=1;}
finally {
  let cleanupVerified=fixtures.length===0,baselineUnchanged=false;
  if(client) {
    try {
      await client.query('BEGIN');
      for(const f of fixtures) {
        const job=await client.query(`DELETE FROM public.export_jobs WHERE id=$1 AND user_id=$2 AND
          snapshot_id=$3 AND reservation_id=$4 AND state='FAILED' AND object_path IS NULL RETURNING id`,
          [f.job,f.owner,f.snapshot,f.reservation]);
        assert(job.rowCount===1,'EXACT_TERMINAL_JOB_CLEANUP_FAILED');
        const snapshot=await client.query('DELETE FROM public.export_snapshots WHERE id=$1 AND user_id=$2 RETURNING id',
          [f.snapshot,f.owner]);assert(snapshot.rowCount===1,'EXACT_SNAPSHOT_CLEANUP_FAILED');
        const reservation=await client.query(`DELETE FROM public.credit_reservations WHERE id=$1 AND user_id=$2
          AND operation_id=$3 AND state='RELEASED' RETURNING id`,[f.reservation,f.owner,f.job]);
        assert(reservation.rowCount===1,'EXACT_RELEASED_FIXTURE_CLEANUP_FAILED');
      }
      await client.query('COMMIT');cleanupVerified=true;
      if(before)baselineUnchanged=before===JSON.stringify((await client.query(baselineSql,[owners])).rows[0].value);
      if(before)assert(baselineUnchanged,'EXISTING_ACCOUNT_PROFILE_CREDIT_AI_EXPORT_STATE_CHANGED');
    }catch{await client.query('ROLLBACK').catch(()=>{});console.error('FIXTURE_CLEANUP_OR_BASELINE_CHECK_FAILED');process.exitCode=1;}
    client.release();
  }
  await pool?.end();
  // Logout only these newly created test sessions, never all sessions/devices.
  for(const actor of actors) {
    try{await authRequest('logout?scope=local',undefined,actor.token);}
    catch{console.error('TEST_SESSION_LOGOUT_UNVERIFIED');process.exitCode=1;}
  }
  const result={checks,realTwoUserOwnershipTested:checks.length===36&&checks.every(c=>c.pass),
    fixtureCount:fixtures.length,cleanupVerified,baselineUnchanged,exportsEnabled:false,
    pdfsGenerated:0,creditTransactions:0,success:!process.exitCode};
  await writeFile('/tmp/jobix-real-user-ingress-results.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify({cleanupVerified,baselineUnchanged,fixtureCount:fixtures.length,success:!process.exitCode}));
}
