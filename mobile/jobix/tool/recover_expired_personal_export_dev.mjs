// Approved expiry-only cleanup. Native RPC only; no gate opening or wallet edits.
import {readFile,writeFile} from 'node:fs/promises';
import pg from '../backend/pdf/node_modules/pg/esm/index.mjs';
const assert=(value,code)=>{if(!value)throw Error(code);};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function main(){
  assert(process.argv.includes('--approved-expired-reservation-cleanup'),'EXPLICIT_APPROVAL_REQUIRED');
  const baseline=JSON.parse(await readFile('/tmp/jobix-personal-export-baseline.json','utf8'));
  const stopped=JSON.parse(await readFile('/tmp/jobix-personal-export-post-stop.json','utf8'));
  const target=stopped.jobs.find(j=>j.state==='QUEUED');
  assert(target&&stopped.jobs.filter(j=>j.state==='QUEUED').length===1,'EXACT_EXTRA_QUEUED_JOB_REQUIRED');
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  assert(uri.username.endsWith('.lmouxhbjhtqdtiqijcee')&&uri.hostname.endsWith('.pooler.supabase.com')&&
    uri.port==='5432'&&uri.pathname==='/postgres','DEVELOPMENT_DATABASE_GUARD');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  const pool=new pg.Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,
    statement_timeout:15000,ssl:{rejectUnauthorized:true,
      ca:await readFile('mobile/jobix/assets/certs/supabase-root-2021.crt','utf8')}});
  try{
    let due;
    do{
      const result=(await pool.query(`SELECT state,deadline,deadline<=now() AS due
        FROM public.export_jobs WHERE id=$1 AND user_id=$2`,[target.id,baseline.actor])).rows[0];
      assert(result?.state==='QUEUED','TARGET_NO_LONGER_QUEUED_STOP');
      due=result.due;
      if(!due){
        console.log(JSON.stringify({event:'WAITING_FOR_APPROVED_NATIVE_EXPIRY',deadline:result.deadline}));
        await sleep(Math.min(30000,Math.max(1000,Date.parse(result.deadline)-Date.now()+1000)));
      }
    }while(!due);
    const client=await pool.connect();
    try{
      await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ');
      const gate=(await client.query('SELECT enabled,deletion_policy_approved FROM public.export_settings')).rows;
      assert(gate.length===1&&!gate[0].enabled&&gate[0].deletion_policy_approved,'CLOSED_GATE_APPROVED_POLICY_REQUIRED');
      // Same eligibility predicate as native recover. Guard all rows it can
      // affect, including its separate completed-object expiry update.
      const eligible=(await client.query(`SELECT j.id,j.user_id,j.state,j.deadline<=now() AS due
        FROM public.export_jobs j WHERE
        (j.state IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE') AND
          (j.deadline<=now() OR j.lease_expires_at<=now() OR
           NOT EXISTS(SELECT FROM public.users u WHERE u.id=j.user_id AND u.status='ACTIVE') OR
           NOT EXISTS(SELECT FROM public.career_profiles p WHERE p.id=j.profile_id AND p.status='ACTIVE')))
        OR (j.state='COMPLETED' AND j.expires_at<=now())
        FOR UPDATE`)).rows;
      assert(eligible.length===1&&eligible[0].id===target.id&&eligible[0].user_id===baseline.actor&&
        eligible[0].state==='QUEUED'&&eligible[0].due,'RECOVERY_SCOPE_DIFFERS_STOP_WITHOUT_CHANGES');
      const outstanding=(await client.query(`SELECT count(*)::int AS count FROM public.export_upload_flights
        WHERE operation=$1 AND state='SENT'`,[target.id])).rows[0].count;
      assert(outstanding===0,'UNRESOLVED_UPLOAD_STOP');
      const native=(await client.query('SELECT public.jobix_export_recover() AS count')).rows[0].count;
      assert(native===1,'UNEXPECTED_NATIVE_RECOVERY_COUNT_ROLLBACK');
      const job=(await client.query(`SELECT j.state,j.error_code,r.state AS reservation_state
        FROM public.export_jobs j JOIN public.credit_reservations r ON r.id=j.reservation_id
        WHERE j.id=$1 AND j.user_id=$2`,[target.id,baseline.actor])).rows[0];
      const wallet=(await client.query(`SELECT finalized_balance,reserved_balance FROM public.credit_accounts
        WHERE user_id=$1`,[baseline.actor])).rows[0];
      const debits=(await client.query(`SELECT delta,reference_id FROM public.credit_transactions
        WHERE user_id=$1 AND reference_type='RESUME_EXPORT'`,[baseline.actor])).rows;
      const completed=(await client.query(`SELECT id,pdf_sha256,state FROM public.export_jobs
        WHERE user_id=$1 AND state='COMPLETED'`,[baseline.actor])).rows;
      const first=stopped.jobs.find(j=>j.state==='COMPLETED');
      assert(job?.state==='FAILED'&&job.error_code==='RESERVATION_EXPIRED'&&job.reservation_state==='RELEASED',
        'NATIVE_EXPIRY_STATE_MISMATCH_ROLLBACK');
      assert(Number(wallet.finalized_balance)===baseline.finalizedCredits-2&&Number(wallet.reserved_balance)===0&&
        debits.length===1&&Number(debits[0].delta)===-2&&debits[0].reference_id===first.id&&
        completed.length===1&&completed[0].id===first.id&&completed[0].pdf_sha256===first.pdf_sha256,
        'ACCOUNTING_OR_SUCCESSFUL_OBJECT_CHANGED_ROLLBACK');
      await client.query('COMMIT');
      const evidence={event:'EXPIRED_EXTRA_RESERVATION_RELEASED',jobState:job.state,errorCode:job.error_code,
        reservationState:job.reservation_state,finalizedCredits:Number(wallet.finalized_balance),
        reservedCredits:0,availableCredits:Number(wallet.finalized_balance),exportDebits:1,
        completedExports:1,firstPdfPreserved:true,gatesReopened:false,manualWalletChanges:false,
        checkedAt:new Date().toISOString()};
      await writeFile('/tmp/jobix-personal-export-cleanup-result.json',JSON.stringify(evidence,null,2),{mode:0o600});
      console.log(JSON.stringify(evidence));
    }catch(error){await client.query('ROLLBACK');throw error;}
    finally{client.release();}
  }finally{await pool.end();}
}
main().catch(error=>{
  console.error(JSON.stringify({event:'APPROVED_EXPIRY_CLEANUP_BLOCKED',code:error.code??error.message}));
  process.exitCode=1;
});
