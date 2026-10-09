// Owner-approved one-export/2-Credit budget. Keep audit rows, close all gates.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID,createHash} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {exportGates} from './phase3_export_gate_dev.mjs';
import {bucket} from './phase3_google.mjs';
const assert=(v,c)=>{if(!v)throw Error(c);};
const hash=v=>createHash('sha256').update(v).digest('hex');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const ref='lmouxhbjhtqdtiqijcee';
let pool,c,gates,token,actor,profile,operation,funded=false,gatesAttempted=false,dbOpened=false;
let stage='preconditions',cfg,originalSettings,passed=false,pdfFacts,closed=false,reconciled=false;
const fundingKey=randomUUID();
let requestKey=randomUUID(),requestId=randomUUID();
async function api(action,command={}) {
  const r=await fetch(cfg.SUPABASE_URL+'/functions/v1/resume-export',{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},
    body:JSON.stringify({action,command}),signal:AbortSignal.timeout(65000),redirect:'error'});
  const body=await r.json().catch(()=>null);
  if(r.status!==200||body?.error){const e=Error('EXPORT_API_FAILED');e.status=r.status;
    e.code=/^[A-Z_]{3,80}$/.test(body?.error?.code??'')?body.error.code:'UPSTREAM_REJECTED';throw e;}
  // Worker /command wraps ALL results as {data:result,error:null}; create's
  // result is itself the durable operation acknowledgement.
  return body.data;
}
async function wallet() {return (await c.query('SELECT finalized_balance,reserved_balance FROM public.credit_accounts WHERE user_id=$1',[actor])).rows[0];}
async function job() {return (await c.query('SELECT * FROM public.export_jobs WHERE user_id=$1 AND idempotency_key=$2',
  [actor,requestKey])).rows[0];}
async function adjust(delta,key,purpose) {
  await c.query('BEGIN');
  try {
    const w=(await c.query('SELECT * FROM public.credit_accounts WHERE user_id=$1 FOR UPDATE',[actor])).rows[0];
    assert(w&&Number(w.reserved_balance)===0,'ADJUSTMENT_REQUIRES_NO_PENDING_RESERVATION');
    await c.query(`INSERT INTO public.credit_transactions(user_id,delta,reference_type,reference_id,idempotency_key,metadata)
      VALUES($1,$2,'ADJUSTMENT',$3,$3,$4)`,[actor,delta,key,{purpose,isolated_development_test:true}]);
    await c.query(`UPDATE public.credit_accounts SET finalized_balance=finalized_balance+$2,
      version=version+1,updated_at=now() WHERE user_id=$1`,[actor,delta]);
    await c.query('COMMIT');
  }catch(e){await c.query('ROLLBACK');throw e;}
}
async function main() {
  assert(process.argv.includes('--approved-one-export-two-credits'),'EXPLICIT_BUDGET_APPROVAL_REQUIRED');
  cfg=JSON.parse(await readFile('mobile/jobix/config/dev.local.json','utf8'));
  assert(cfg.APP_ENV==='dev'&&cfg.SUPABASE_URL===`https://${ref}.supabase.co`,'DEV_AUTH_GUARD');
  const adr=await readFile('mobile/jobix/backend/pdf/ADR-retention-deletion.md','utf8');
  assert(adr.includes('Product decision approved')&&adr.includes('7-day logical retention'),'APPROVED_POLICY_REQUIRED');
  const auth=await fetch(cfg.SUPABASE_URL+'/auth/v1/token?grant_type=password',{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,'Content-Type':'application/json'},
    body:JSON.stringify({email:process.env.JOBIX_DEV_TEST_EMAIL_A,password:process.env.JOBIX_DEV_TEST_PASSWORD_A})});
  const session=await auth.json();assert(auth.ok&&session.access_token,'AUTH_FAILED');
  token=session.access_token;actor=session.user.id;
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  assert(uri.username.endsWith('.'+ref)&&uri.hostname.endsWith('.pooler.supabase.com')&&uri.port==='5432','DEV_DB_GUARD');
  for(const k of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(k);
  pool=new Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,statement_timeout:20000,
    ssl:{rejectUnauthorized:true,ca:await readFile('mobile/jobix/assets/certs/supabase-root-2021.crt','utf8')}});
  c=await pool.connect();
  profile=(await c.query("SELECT id FROM public.career_profiles WHERE user_id=$1 AND status='ACTIVE' ORDER BY slot_number,id LIMIT 1",[actor])).rows[0]?.id;
  assert(profile,'PROFILE_REQUIRED');
  stage='structural_preflight';
  const document=await api('document',{profile_id:profile});
  assert(document.issues?.length===0,'STRUCTURAL_EXPORT_NOT_READY');
  const pending=(await c.query(`SELECT (SELECT count(*) FROM public.export_jobs WHERE state IN
    ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE'))+
    (SELECT count(*) FROM public.credit_reservations WHERE state='PENDING') AS n`)).rows[0];
  assert(Number(pending.n)===0,'UNRELATED_PENDING_WORK_PRESENT');
  const w=await wallet();assert(Number(w.finalized_balance)===0&&Number(w.reserved_balance)===0,'EXPECTED_ZERO_TEST_WALLET');
  const resume=process.argv.includes('--verify-existing-funded-export');
  const funding=(await c.query(`SELECT created_at FROM public.credit_transactions WHERE user_id=$1
    AND delta=2 AND reference_type='ADJUSTMENT'
    AND metadata->>'purpose'='phase3-one-export-fixture-funding'`,[actor])).rows;
  let existing;
  if(resume) {
    assert(funding.length===1,'EXACT_EXISTING_FUNDING_REQUIRED');
    const jobs=(await c.query(`SELECT * FROM public.export_jobs WHERE user_id=$1
      AND profile_id=$2 AND created_at>=$3 AND created_at<$3+interval '1 hour'`,
      [actor,profile,funding[0].created_at])).rows;
    assert(jobs.length===1&&jobs[0].state==='COMPLETED','ONE_COMPLETED_EXISTING_EXPORT_REQUIRED');
    existing=jobs[0];requestKey=existing.idempotency_key;
    requestId=existing.acknowledgement.request_id;operation=existing.id;funded=true;
  }else assert(funding.length===0,'ONE_TEST_BUDGET_ALREADY_USED');
  gates=await exportGates();
  originalSettings=(await c.query('SELECT enabled,deletion_policy_approved FROM public.export_settings')).rows[0];
  assert(originalSettings?.enabled===false,'DB_GATE_MUST_START_CLOSED');
  const actorB=(await c.query('SELECT id FROM auth.users WHERE lower(email)=lower($1)',
    [process.env.JOBIX_DEV_TEST_EMAIL_B])).rows[0]?.id;
  assert(actorB&&actorB!==actor,'ISOLATED_PEER_REQUIRED');
  const bFingerprint=async()=>JSON.stringify((await c.query(`SELECT jsonb_build_object(
    'wallet',(SELECT to_jsonb(w) FROM public.credit_accounts w WHERE user_id=$1),
    'ledger',(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]') FROM public.credit_transactions t WHERE user_id=$1),
    'profile',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.career_profiles p WHERE user_id=$1),
    'ai',(SELECT to_jsonb(a) FROM public.ai_allowance_accounts a WHERE user_id=$1)) AS value`,[actorB])).rows[0].value);
  const bBefore=await bFingerprint();
  stage='approved_fixture_funding';
  if(!resume){await adjust(2,fundingKey,'phase3-one-export-fixture-funding');funded=true;}
  console.log(JSON.stringify({stage,actor:'A',newAdjustmentCredits:resume?0:2,maxExportCharge:2,
    reuseCompletedJob:resume}));
  stage='open_existing_development_gates';
  dbOpened=true;
  // Align the false/default DB approval switch with the verified approved ADR;
  // no retention contract or runtime deletion approval value is changed.
  await c.query('UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true');
  gatesAttempted=true;await gates.open();
  stage='atomic_create_and_concurrent_replay';
  const command={request_id:requestId,idempotency_key:requestKey,
    expected_profile_version:existing?.acknowledgement.data.source_version??document.profile_version,payload:{profile_id:profile,
      expected_configuration_version:existing?.acknowledgement.data.configuration_version??document.configuration_version,
      expected_document_sha256:existing?.acknowledgement.data.document_sha256??document.document_sha256,
      renderer_bundle_version:document.bundle}};
  const [first,replay]=await Promise.all([api('create',command),api('create',command)]);
  assert(first.operation_id&&isDeepStrictEqual(first,replay)&&
    (!existing||isDeepStrictEqual(first,existing.acknowledgement)),'ATOMIC_REPLAY_MISMATCH');
  operation=first.operation_id;
  const queued=await job();assert(queued.id===operation,'JOB_ACK_MISMATCH');
  const reserved=await wallet();
  assert(first.data.reserved_credits===2&&(
    (Number(reserved.finalized_balance)===2&&Number(reserved.reserved_balance)===2)||
    (queued.state==='COMPLETED'&&Number(reserved.finalized_balance)===0&&Number(reserved.reserved_balance)===0)),
    'RESERVATION_NOT_EXACTLY_TWO');
  console.log(JSON.stringify({stage,oneJob:true,reservedCredits:2,duplicateCharge:false}));
  stage='native_scheduler_worker_processing';
  if(queued.state!=='COMPLETED')await gates.dispatch();
  let current,lastState;
  for(let i=0;i<390;i++) {
    current=await job();
    if(current.state!==lastState){console.log(JSON.stringify({stage,state:current.state,attempt:current.attempt_count}));lastState=current.state;}
    if(['COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED'].includes(current.state))break;
    await sleep(5000);
  }
  assert(current?.state==='COMPLETED','EXPORT_DID_NOT_COMPLETE');
  stage='finalization_proof';
  const ledger=(await c.query("SELECT delta FROM public.credit_transactions WHERE user_id=$1 AND reference_type='RESUME_EXPORT' AND reference_id=$2",
    [actor,operation])).rows;
  const reservation=(await c.query('SELECT state,amount FROM public.credit_reservations WHERE id=$1',[current.reservation_id])).rows[0];
  const after=await wallet();
  assert(ledger.length===1&&ledger[0].delta===-2&&reservation.state==='CONSUMED'&&reservation.amount===2&&
    Number(after.finalized_balance)===0&&Number(after.reserved_balance)===0,'CREDIT_FINALIZATION_MISMATCH');
  const snapshot=(await c.query('SELECT document_sha256,source_sha256 FROM public.export_snapshots WHERE id=$1',
    [current.snapshot_id])).rows[0];
  assert(snapshot.document_sha256===document.document_sha256&&snapshot.source_sha256===document.source_sha256,'FROZEN_SNAPSHOT_MISMATCH');
  stage='completed_replay';
  assert(isDeepStrictEqual(await api('create',command),first),'COMPLETED_REPLAY_MISMATCH');
  stage='signed_zero_credit_download';
  const download=await api('download',{export_id:operation}),url=new URL(download.url);
  assert(url.protocol==='https:'&&url.hostname==='storage.googleapis.com'&&
    url.pathname==='/'+bucket+'/'+current.object_path&&
    url.searchParams.get('generation')===current.object_generation,'GENERATION_BOUND_DOWNLOAD_REQUIRED');
  const response=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(60000)});
  const bytes=Buffer.from(await response.arrayBuffer());
  assert(response.status===200&&bytes.subarray(0,5).toString()==='%PDF-'&&
    bytes.subarray(-1024).includes(Buffer.from('%%EOF'))&&hash(bytes)===current.pdf_sha256&&
    bytes.length===Number(current.object_size)&&current.page_count>=1&&current.page_count<=20,'PDF_BYTE_PROOF_FAILED');
  await writeFile('/tmp/jobix-controlled-test-resume.pdf',bytes);
  const anonymous=await fetch('https://storage.googleapis.com/'+bucket+'/'+current.object_path,
    {signal:AbortSignal.timeout(20000)});
  assert([401,403].includes(anonymous.status),'PDF_OBJECT_NOT_PRIVATE');
  const tampered=new URL(url);tampered.searchParams.set('generation',String(BigInt(current.object_generation)+1n));
  assert((await fetch(tampered,{signal:AbortSignal.timeout(20000)})).status===403,'GENERATION_SIGNATURE_NOT_BOUND');
  const gcsBirth=Date.parse(current.expires_at)-7*86400000;
  assert(Math.abs(gcsBirth-Date.parse(current.completed_at))<60000,'SEVEN_DAY_RETENTION_METADATA_MISMATCH');
  assert(JSON.stringify(await wallet())===JSON.stringify(after),'DOWNLOAD_CHANGED_CREDITS');
  assert(await bFingerprint()===bBefore,'ACCOUNT_B_CHANGED');
  pdfFacts={pages:current.page_count,bytes:bytes.length,pdfSha256:current.pdf_sha256,
    privateObject:true,generationBoundSignature:true,retentionDays:7};
  passed=true;
  console.log(JSON.stringify({stage:'CONTROLLED_EXPORT_VERIFIED',chargedCredits:2,
    paidTransactions:1,idempotentReplay:true,downloadCredits:0,accountBUnchanged:true,...pdfFacts}));
}
try{await main();}
catch(e){console.error(JSON.stringify({stage,code:e.code??(/^[A-Z_0-9]{3,80}$/.test(e.message??'')?e.message:'SUPPRESSED'),
  status:e.status??null,permission:e.permission??null}));process.exitCode=1;}
finally {
  if(c&&funded) {
    try {
      const current=await job();
      if(current&&!['COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED'].includes(current.state)) {
        // Do not cancel/reset a live lease. Preserve native recovery until the
        // existing bounded deadline can release its reservation.
        throw Error('LIVE_RESERVATION_REQUIRES_RECOVERY');
      }
      const w=await wallet();
      assert(Number(w.reserved_balance)===0,'PENDING_RESERVATION_REQUIRES_RECOVERY');
      if(Number(w.finalized_balance)===2)await adjust(-2,randomUUID(),'phase3-unused-fixture-funding-return');
      const final=await wallet();assert(Number(final.finalized_balance)===0&&Number(final.reserved_balance)===0,'TEST_CREDITS_NOT_RECONCILED');
      reconciled=true;
    }catch{console.error('CREDIT_RECONCILIATION_UNVERIFIED');process.exitCode=1;}
  }
  if(gatesAttempted) {
    try{await gates.close();closed=true;}catch{console.error('EXPORT_GATE_CLOSE_UNVERIFIED');process.exitCode=1;}
  }else closed=true;
  if(c&&dbOpened) {
    try{await c.query('UPDATE public.export_settings SET enabled=$1,deletion_policy_approved=true',
      [originalSettings.enabled]);}catch{console.error('DB_GATE_RESTORE_UNVERIFIED');process.exitCode=1;}
  }
  if(token)await fetch(cfg.SUPABASE_URL+'/auth/v1/logout?scope=local',{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,Authorization:'Bearer '+token}}).catch(()=>{process.exitCode=1;});
  c?.release();await pool?.end();
  const result={passed,stage,operation:operation??null,pdfFacts:pdfFacts??null,exportsDisabled:closed,
    creditReconciliationVerified:reconciled,fundedCredits:funded?2:0,success:passed&&!process.exitCode};
  await writeFile('/tmp/jobix-controlled-export-results.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify({stage:'CONTROLLED_TEST_DONE',passed,exportsDisabled:closed,
    creditReconciliationVerified:reconciled,success:result.success}));
}
