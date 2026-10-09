// Approved one-intent personal phone test. No funding, export creation or profile edits.
import {readFile,writeFile,access} from 'node:fs/promises';
import {isDeepStrictEqual} from 'node:util';
import pg from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {exportGates} from './phase3_export_gate_dev.mjs';
const assert=(condition,code)=>{if(!condition)throw Error(code);};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let gates,pool,opened=false,stop=false,stage='preconditions';
process.on('SIGTERM',()=>{stop=true;});
process.on('SIGINT',()=>{stop=true;});
async function main(){
  assert(process.argv.includes('--approved-one-personal-export'),'EXPLICIT_APPROVAL_REQUIRED');
  const baseline=JSON.parse(await readFile('/tmp/jobix-personal-export-baseline.json','utf8'));
  assert(baseline.matchedAccounts===1&&baseline.accountStatus==='ACTIVE'&&baseline.emailConfirmed&&
    baseline.activeProfiles===1&&baseline.availableCredits>=2&&baseline.reservedCredits===0&&
    baseline.existingExportJobs===0&&baseline.existingExportDebits===0,'VERIFIED_ACCOUNT_BALANCE_REQUIRED');
  assert(Date.now()-Date.parse(baseline.checkedAt)<15*60*1000,'RECENT_READ_ONLY_BASELINE_REQUIRED');
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  assert(uri.username.endsWith('.lmouxhbjhtqdtiqijcee')&&uri.hostname.endsWith('.pooler.supabase.com')&&
    uri.port==='5432'&&uri.pathname==='/postgres','DEVELOPMENT_DATABASE_GUARD');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  pool=new pg.Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,
    statement_timeout:15000,ssl:{rejectUnauthorized:true,
      ca:await readFile('mobile/jobix/assets/certs/supabase-root-2021.crt','utf8')}});
  const account=(await pool.query(`SELECT u.status,w.finalized_balance,w.reserved_balance
    FROM public.users u JOIN public.credit_accounts w ON w.user_id=u.id WHERE u.id=$1`,
    [baseline.actor])).rows[0];
  assert(account?.status==='ACTIVE'&&Number(account.finalized_balance)===baseline.finalizedCredits&&
    Number(account.reserved_balance)===0,'ACCOUNT_OR_BALANCE_CHANGED');
  const settings=(await pool.query('SELECT enabled,deletion_policy_approved FROM public.export_settings')).rows;
  assert(settings.length===1&&settings[0].enabled===false&&settings[0].deletion_policy_approved===true,
    'CLOSED_DATABASE_GATE_APPROVED_POLICY_REQUIRED');
  gates=await exportGates();
  stage='open_approved_existing_development_gates';
  // Set before first mutation so partial-open failures also trigger closure.
  opened=true;
  await gates.open();
  const updated=await pool.query(`UPDATE public.export_settings SET enabled=true
    WHERE singleton=true AND enabled=false AND deletion_policy_approved=true RETURNING enabled`);
  assert(updated.rowCount===1,'EXACT_DATABASE_GATE_UPDATE_REQUIRED');
  const expiresAt=new Date(Date.now()+15*60*1000).toISOString();
  await writeFile('/tmp/jobix-personal-export-window.json',JSON.stringify({
    open:true,expiresAt,actor:baseline.actor,availableBefore:baseline.availableCredits,
    closeSignal:'/tmp/jobix-personal-export-close-requested',
  },null,2),{mode:0o600});
  console.log(JSON.stringify({event:'PERSONAL_EXPORT_WINDOW_OPEN',expiresAt,
    availableCredits:baseline.availableCredits,reservedCredits:0,oneExportOnly:true}));
  stage='observe_phone_initiated_export';
  let previous='',completionVerified=false;
  while(!stop&&Date.now()<Date.parse(expiresAt)){
    try{await access('/tmp/jobix-personal-export-close-requested');break;}catch(error){
      if(error.code!=='ENOENT')throw error;
    }
    const jobs=(await pool.query(`SELECT j.id,j.state,j.error_code,j.profile_id,j.snapshot_id,
      j.reservation_id,j.idempotency_key,j.request_sha256,j.acknowledgement,j.object_path,
      j.object_generation,j.pdf_sha256,j.page_count,j.object_size,j.completed_at,j.expires_at
      FROM public.export_jobs j WHERE j.user_id=$1 ORDER BY j.created_at`,[baseline.actor])).rows;
    assert(jobs.length<=1,'MORE_THAN_ONE_EXPORT_STOP_NO_AUTOMATIC_REFUND');
    if(jobs.length){
      const job=jobs[0];
      const wallet=(await pool.query(`SELECT finalized_balance,reserved_balance
        FROM public.credit_accounts WHERE user_id=$1`,[baseline.actor])).rows[0];
      const reservation=(await pool.query(`SELECT state,amount FROM public.credit_reservations
        WHERE user_id=$1 AND id=$2 AND operation_id=$3`,[baseline.actor,job.reservation_id,job.id])).rows[0];
      const debits=(await pool.query(`SELECT delta,reference_id FROM public.credit_transactions
        WHERE user_id=$1 AND reference_type='RESUME_EXPORT'`,[baseline.actor])).rows;
      const summary={event:'PERSONAL_EXPORT_STATUS',state:job.state,errorCode:job.error_code,
        finalizedCredits:Number(wallet.finalized_balance),reservedCredits:Number(wallet.reserved_balance),
        reservationState:reservation?.state,debitCount:debits.length};
      const text=JSON.stringify(summary);
      if(text!==previous){console.log(text);previous=text;}
      if(job.state==='COMPLETED'&&!completionVerified){
        assert(debits.length===1&&Number(debits[0].delta)===-2&&debits[0].reference_id===job.id&&
          reservation?.state==='CONSUMED'&&Number(reservation.amount)===2&&
          Number(wallet.finalized_balance)===baseline.finalizedCredits-2&&
          Number(wallet.reserved_balance)===0,'COMPLETION_CREDIT_CONTRACT_FAILED');
        // Real operation's established replay RPC, rolled back. No new create
        // request/token/identity and no second export or charge is introduced.
        const client=await pool.connect();
        let replay;
        try{
          await client.query('BEGIN');
          replay=(await client.query('SELECT public.jobix_export_replay($1,$2,$3) AS value',
            [baseline.actor,job.idempotency_key,job.request_sha256])).rows[0].value;
        }finally{await client.query('ROLLBACK');client.release();}
        assert(isDeepStrictEqual(replay,job.acknowledgement),'REAL_OPERATION_REPLAY_MISMATCH');
        const evidence={...summary,event:'PERSONAL_EXPORT_COMPLETED',job,actor:baseline.actor,
          replayAcknowledgementMatches:true,replayScope:'authoritative_database_RPC_not_phone_HTTP',
          phoneDownloadOpenVerified:false,expiresAt};
        await writeFile('/tmp/jobix-personal-export-result.json',JSON.stringify(evidence,null,2),{mode:0o600});
        console.log(JSON.stringify({event:'PERSONAL_EXPORT_COMPLETED',debitCount:1,debitCredits:2,
          finalizedCredits:Number(wallet.finalized_balance),reservedCredits:0,
          reservationState:'CONSUMED',databaseReplayMatches:true,
          waitingForPhoneDownloadOpen:true}));
        completionVerified=true;
      }
      if(['FAILED','EXPIRED','MISSING_OBJECT'].includes(job.state))break;
    }
    await sleep(3000);
  }
  console.log(JSON.stringify({event:'PERSONAL_EXPORT_WINDOW_ENDING',
    reason:stop?'process_stop':Date.now()>=Date.parse(expiresAt)?'time_limit':'phone_confirmation_or_terminal_failure'}));
}
main().catch(error=>{
  console.error(JSON.stringify({event:'PERSONAL_EXPORT_WINDOW_ERROR',stage,
    code:error.code??error.message,status:error.status??null,permission:error.permission??null}));
  process.exitCode=1;
}).finally(async()=>{
  if(opened){
    const errors=[];
    try{
      await pool.query('UPDATE public.export_settings SET enabled=false WHERE singleton=true');
    }catch{errors.push('DATABASE_GATE_CLOSE_UNVERIFIED');}
    try{await gates.close();}catch{errors.push('CLOUD_EDGE_GATES_CLOSE_UNVERIFIED');}
    await writeFile('/tmp/jobix-personal-export-window-closed.json',JSON.stringify({
      closed:errors.length===0,closedAt:new Date().toISOString(),errors,
    },null,2),{mode:0o600});
    console.log(JSON.stringify({event:errors.length?'PERSONAL_GATE_CLOSE_BLOCKED':'PERSONAL_EXPORT_GATES_CLOSED',
      errors,noFunding:true,noExportCreatedByScript:true}));
    if(errors.length)process.exitCode=1;
  }
  await pool?.end();
});
