// Protected additive DEVELOPMENT migration runner. No runtime/admin fallback.
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
const ref='lmouxhbjhtqdtiqijcee';
const versions=[
 '202610080012_resume_export_foundation','202610080013_resume_export_lifecycle',
 '202610080014_resume_configuration_concurrency','202610080015_resume_export_local_hardening',
 '202610080016_resume_export_cleanup_hooks','202610080017_resume_export_deletion',
];
export async function migrate({caFile,approved=false}) {
  if(!approved||!caFile)throw Error('EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED');
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  if(!['postgres:','postgresql:'].includes(uri.protocol)||!uri.username.endsWith('.'+ref)||
    !uri.hostname.endsWith('.pooler.supabase.com')||uri.pathname!='/postgres'||uri.port!=='5432')throw Error('DEV_TARGET_REJECTED');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  const pool=new Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,
    ssl:{rejectUnauthorized:true,ca:await readFile(caFile,'utf8')},statement_timeout:30000});
  const client=await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))");
    const baseline=(await client.query(`SELECT to_regclass('public.profile_volunteer_experiences') IS NOT NULL volunteer,
      to_regclass('public.export_jobs') IS NOT NULL exports,
      to_regclass('public.jobix_export_migrations') IS NOT NULL ledger`)).rows[0];
    if(!baseline.volunteer||baseline.exports&&!baseline.ledger)throw Error('BASELINE_RECONCILIATION_REQUIRED');
    await client.query(`CREATE TABLE IF NOT EXISTS public.jobix_export_migrations
      (version text PRIMARY KEY,sha256 text NOT NULL);
      ALTER TABLE public.jobix_export_migrations ENABLE ROW LEVEL SECURITY;
      REVOKE ALL ON public.jobix_export_migrations FROM PUBLIC,anon,authenticated,service_role`);
    for(const version of versions) {
      const source=await readFile(resolve(import.meta.dirname,'../supabase/migrations',version+'.sql'),'utf8');
      const hash=createHash('sha256').update(source).digest('hex');
      const applied=(await client.query('SELECT sha256 FROM public.jobix_export_migrations WHERE version=$1',[version])).rows[0];
      if(applied){if(applied.sha256!==hash)throw Error('MIGRATION_CHECKSUM_CONFLICT');continue;}
      // Source files have one outer BEGIN/COMMIT. All files share this transaction.
      const body=source.replace(/^BEGIN;\s*$/m,'').replace(/^COMMIT;\s*$/m,'');
      await client.query(body);
      await client.query('INSERT INTO public.jobix_export_migrations VALUES($1,$2)',[version,hash]);
    }
    // Rollout is a separate, deliberate step after identity/runtime/live checks.
    await client.query('COMMIT');
    console.log('DEVELOPMENT_MIGRATIONS_APPLIED_EXPORT_ROLLOUT_UNCHANGED');
  } catch(error) {
    await client.query('ROLLBACK').catch(()=>{});throw error;
  } finally {client.release();await pool.end();}
}
if(process.argv[1]===import.meta.filename) {
  const ca=process.argv.indexOf('--ca-file');
  migrate({caFile:ca>=0?process.argv[ca+1]:undefined,
    approved:process.argv.includes('--apply-development')}).catch(()=>{
      // Never print driver errors/DSNs/user data.
      console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_NO_TLS_OR_ADMIN_FALLBACK');process.exitCode=1;
    });
}
