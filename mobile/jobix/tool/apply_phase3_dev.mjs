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
const resumeExportCostVersions=[
 '202610080018_resume_export_admission',
 '202610100019_resume_export_cost_protection',
 '202610100020_resume_export_cost_purge_recovery',
];
const resumeExportCostOutputUnitVersion='202610100021_resume_export_cost_output_unit';
const resumeLayoutVersion='202610170022_resume_layout';
// Reviewed against the exact checked-in migration source; never derive this
// expected value from the file at execution time.
const resumeLayoutExpectedSha256='d34f6dad4d9edcd301486d9d507bed7330c0fde66cfac3630bee087fa8366473';
const resumeLayoutPrerequisiteVersions=[
  ...versions,...resumeExportCostVersions,resumeExportCostOutputUnitVersion,
];

export function verifyResumeLayoutMigrationSource(source) {
  const actual=createHash('sha256').update(source).digest('hex');
  if(actual!==resumeLayoutExpectedSha256)throw Error('MIGRATION_SOURCE_CHECKSUM_MISMATCH');
  return actual;
}

export async function migrateResumeLayout({
  caFile,approved=false,poolFactory=options=>new Pool(options),
}={}) {
  if(!approved||!caFile)throw Error('EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED');
  const source=await readFile(resolve(import.meta.dirname,
    '../supabase/migrations',resumeLayoutVersion+'.sql'),'utf8');
  const sourceHash=verifyResumeLayoutMigrationSource(source);
  const rawUrl=process.env.JOBIX_DEV_DATABASE_URL;
  if(!rawUrl)throw Error('DEV_TARGET_REJECTED');
  const uri=new URL(rawUrl);
  if(!['postgres:','postgresql:'].includes(uri.protocol)||
    !uri.username.endsWith('.'+ref)||
    !uri.hostname.endsWith('.pooler.supabase.com')||
    uri.pathname!='/postgres'||uri.port!=='5432')throw Error('DEV_TARGET_REJECTED');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  const pool=poolFactory({connectionString:uri.toString(),max:1,
    connectionTimeoutMillis:15000,ssl:{rejectUnauthorized:true,ca:await readFile(caFile,'utf8')},
    statement_timeout:30000});
  let client,transactionOpen=false;
  try {
    client=await pool.connect();
    await client.query('BEGIN');
    transactionOpen=true;
    // Share the exact lock key with every existing Development migration mode.
    await client.query("SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))");

    const identity=(await client.query(
      'SELECT current_database() AS database,current_user AS role')).rows[0];
    if(identity?.database!=='postgres')throw Error('DEV_TARGET_IDENTITY_MISMATCH');

    const baseline=(await client.query(`SELECT
      to_regclass('public.jobix_export_migrations') IS NOT NULL AS ledger,
      to_regclass('public.users') IS NOT NULL AS users,
      to_regclass('public.career_profiles') IS NOT NULL AS profiles,
      to_regclass('public.resume_configurations') IS NOT NULL AS configurations,
      to_regclass('public.idempotency_records') IS NOT NULL AS idempotency,
      to_regprocedure('public.read_resume_configuration(uuid)') IS NOT NULL AS read_configuration,
      to_regprocedure('public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)') IS NOT NULL AS save_layout,
      to_regrole('authenticated') IS NOT NULL AS authenticated_role,
      to_regrole('anon') IS NOT NULL AS anon_role,
      to_regrole('service_role') IS NOT NULL AS service_role`)).rows[0];
    if(!baseline||!baseline.ledger||!baseline.users||!baseline.profiles||
      !baseline.configurations||!baseline.idempotency||!baseline.read_configuration||
      !baseline.authenticated_role||!baseline.anon_role||!baseline.service_role) {
      throw Error('LAYOUT_BASELINE_SCHEMA_DRIFT');
    }
    if(baseline.save_layout)throw Error('LAYOUT_FUNCTION_ALREADY_EXISTS');

    const missingColumns=(await client.query(`SELECT expected.table_name,expected.column_name
      FROM (VALUES
       ('users','id'),('users','status'),
       ('career_profiles','id'),('career_profiles','user_id'),
       ('career_profiles','status'),('career_profiles','profile_version'),
       ('resume_configurations','profile_id'),('resume_configurations','language'),
       ('resume_configurations','template_id'),('resume_configurations','version'),
       ('resume_configurations','section_visibility'),('resume_configurations','section_order'),
       ('resume_configurations','render_config_version'),('resume_configurations','template_version'),
       ('idempotency_records','user_id'),('idempotency_records','operation_type'),
       ('idempotency_records','idempotency_key'),('idempotency_records','payload_hash'),
       ('idempotency_records','response_state')
      ) AS expected(table_name,column_name)
      WHERE NOT EXISTS (
       SELECT FROM information_schema.columns c
       WHERE c.table_schema='public' AND c.table_name=expected.table_name
        AND c.column_name=expected.column_name
      )`)).rows;
    if(missingColumns.length)throw Error('LAYOUT_BASELINE_SCHEMA_DRIFT');

    const ownerPrivileges=(await client.query(`SELECT
      current_user AS role,
      has_schema_privilege(current_user,'public','CREATE') AS schema_create,
      has_schema_privilege(current_user,'public','USAGE') AS schema_usage,
      has_table_privilege(current_user,'public.users','SELECT') AS users_select,
      has_table_privilege(current_user,'public.users','UPDATE') AS users_update,
      has_table_privilege(current_user,'public.career_profiles','SELECT') AS profiles_select,
      has_table_privilege(current_user,'public.career_profiles','UPDATE') AS profiles_update,
      has_table_privilege(current_user,'public.resume_configurations','SELECT') AS configurations_select,
      has_table_privilege(current_user,'public.resume_configurations','INSERT') AS configurations_insert,
      has_table_privilege(current_user,'public.resume_configurations','UPDATE') AS configurations_update,
      has_table_privilege(current_user,'public.idempotency_records','SELECT') AS idempotency_select,
      has_table_privilege(current_user,'public.idempotency_records','INSERT') AS idempotency_insert,
      has_function_privilege(current_user,
        'public.read_resume_configuration(uuid)','EXECUTE') AS read_rpc_execute,
      (SELECT count(*)=4 AND bool_and(
        NOT c.relrowsecurity OR r.rolsuper OR r.rolbypassrls OR
        (c.relowner=r.oid AND (NOT c.relforcerowsecurity OR r.rolsuper OR r.rolbypassrls))
      )
       FROM pg_class c CROSS JOIN pg_roles r
       WHERE r.rolname=current_user AND c.relnamespace='public'::regnamespace
        AND c.relname=ANY(ARRAY['users','career_profiles','resume_configurations','idempotency_records']))
        AS rls_owner_access`)).rows[0];
    if(!ownerPrivileges||Object.entries(ownerPrivileges)
      .some(([key,value])=>key!=='role'&&value!==true)) {
      throw Error('LAYOUT_FUNCTION_OWNER_PRIVILEGES_INSUFFICIENT');
    }

    const ledger=(await client.query(
      'SELECT version,sha256 FROM public.jobix_export_migrations ORDER BY version')).rows;
    if(ledger.length!==resumeLayoutPrerequisiteVersions.length||
      resumeLayoutPrerequisiteVersions.some((version,index)=>
        ledger[index]?.version!==version)) {
      throw Error('MIGRATION_LEDGER_STATE_CONFLICT');
    }
    for(let index=0;index<resumeLayoutPrerequisiteVersions.length;index++) {
      const version=resumeLayoutPrerequisiteVersions[index];
      const priorSource=await readFile(resolve(import.meta.dirname,
        '../supabase/migrations',version+'.sql'),'utf8');
      const expected=createHash('sha256').update(priorSource).digest('hex');
      if(ledger[index].sha256!==expected)throw Error('MIGRATION_CHECKSUM_CONFLICT');
    }

    const body=source.replace(/^BEGIN;\s*$/m,'').replace(/^COMMIT;\s*$/m,'');
    await client.query(body);
    await client.query('INSERT INTO public.jobix_export_migrations(version,sha256) VALUES($1,$2)',
      [resumeLayoutVersion,sourceHash]);

    const installed=(await client.query(`SELECT
      p.proowner=(SELECT oid FROM pg_roles WHERE rolname=current_user) AS owner_matches,
      p.prosecdef AS security_definer,
      has_function_privilege('authenticated',
        'public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)','EXECUTE') AS authenticated_execute,
      has_function_privilege('anon',
        'public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)','EXECUTE') AS anon_execute,
      has_function_privilege('service_role',
        'public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)','EXECUTE') AS service_execute
      FROM pg_proc p
      WHERE p.oid=to_regprocedure('public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)')
      AND p.prokind='f'`)).rows[0];
    const installedLedger=(await client.query(
      'SELECT sha256 FROM public.jobix_export_migrations WHERE version=$1',
      [resumeLayoutVersion])).rows[0];
    if(!installed||installed.owner_matches!==true||installed.security_definer!==true||
      installed.authenticated_execute!==true||installed.anon_execute!==false||
      installed.service_execute!==false||installedLedger?.sha256!==sourceHash) {
      throw Error('LAYOUT_POST_APPLY_ASSERTION_FAILED');
    }

    await client.query('COMMIT');
    transactionOpen=false;
    console.log('DEVELOPMENT_MIGRATION_022_APPLIED_LAYOUT_RPC_ONLY');
  } catch(error) {
    if(client&&transactionOpen)await client.query('ROLLBACK').catch(()=>{});
    throw error;
  } finally {
    client?.release();
    await pool.end();
  }
}

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
export async function migrateResumeExportCost({caFile,approved=false,outputUnitFix=false}) {
  if(!approved||!caFile)throw Error('EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED');
  const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
  if(!['postgres:','postgresql:'].includes(uri.protocol)||!uri.username.endsWith('.'+ref)||
    !uri.hostname.endsWith('.pooler.supabase.com')||uri.pathname!='/postgres'||uri.port!=='5432')throw Error('DEV_TARGET_REJECTED');
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  const pool=new Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,
    ssl:{rejectUnauthorized:true,ca:await readFile(caFile,'utf8')},statement_timeout:30000});
  const expectedVersions=outputUnitFix?[...versions,...resumeExportCostVersions]:versions;
  const migrationPlan=outputUnitFix?[resumeExportCostOutputUnitVersion]:resumeExportCostVersions;
  let client,transactionOpen=false;
  try {
    client=await pool.connect();
    await client.query('BEGIN');
    transactionOpen=true;
    // Share the lock key with the original runner so the two modes cannot race.
    await client.query("SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))");
    const baseline=(await client.query(`SELECT
      to_regclass('public.profile_volunteer_experiences') IS NOT NULL AS volunteer,
      to_regclass('public.resume_configurations') IS NOT NULL AS configurations,
      to_regclass('public.users') IS NOT NULL AS users,
      to_regclass('public.career_profiles') IS NOT NULL AS profiles,
      to_regclass('public.idempotency_records') IS NOT NULL AS idempotency,
      to_regclass('public.credit_accounts') IS NOT NULL AS accounts,
      to_regclass('public.credit_reservations') IS NOT NULL AS credit_reservations,
      to_regclass('public.credit_transactions') IS NOT NULL AS credit_transactions,
      to_regclass('public.export_settings') IS NOT NULL AS settings,
      to_regclass('public.export_snapshots') IS NOT NULL AS snapshots,
      to_regclass('public.export_jobs') IS NOT NULL AS exports,
      to_regclass('public.export_upload_flights') IS NOT NULL AS flights,
      to_regclass('public.export_cost_budget_policy') IS NOT NULL AS cost_policy,
      to_regclass('public.export_cost_reservations') IS NOT NULL AS cost_reservations,
      to_regprocedure('public.jobix_export_cost_estimate(bigint,bigint,integer)') IS NOT NULL AS cost_estimator,
      to_regclass('public.jobix_export_migrations') IS NOT NULL AS ledger`)).rows[0];
    if(!baseline.volunteer||!baseline.configurations||!baseline.users||!baseline.profiles||
      !baseline.idempotency||!baseline.accounts||!baseline.credit_reservations||
      !baseline.credit_transactions||
      !baseline.settings||!baseline.snapshots||!baseline.exports||!baseline.flights||
      !baseline.ledger||
      (outputUnitFix&&(!baseline.cost_policy||!baseline.cost_reservations||!baseline.cost_estimator))) {
      throw Error('BASELINE_SCHEMA_DRIFT');
    }

    const ledger=(await client.query(
      'SELECT version,sha256 FROM public.jobix_export_migrations ORDER BY version')).rows;
    if(ledger.length!==expectedVersions.length||
      expectedVersions.some((version,index)=>ledger[index]?.version!==version)) {
      throw Error('MIGRATION_LEDGER_STATE_CONFLICT');
    }
    for(let index=0;index<expectedVersions.length;index++) {
      const source=await readFile(resolve(import.meta.dirname,'../supabase/migrations',expectedVersions[index]+'.sql'),'utf8');
      const hash=createHash('sha256').update(source).digest('hex');
      if(ledger[index].sha256!==hash)throw Error('MIGRATION_CHECKSUM_CONFLICT');
    }

    const missingColumns=(await client.query(`SELECT expected.table_name,expected.column_name
      FROM (VALUES
       ('resume_configurations','section_visibility'),
       ('resume_configurations','section_order'),
       ('resume_configurations','render_config_version'),
       ('resume_configurations','template_version'),
       ('export_settings','singleton'),
       ('export_settings','enabled'),
       ('export_settings','deletion_policy_approved'),
       ('export_snapshots','source'),
       ('export_snapshots','source_sha256'),
       ('export_snapshots','asset_manifest'),
       ('export_snapshots','canonical_html'),
       ('export_snapshots','document_sha256'),
       ('export_snapshots','bundle'),
       ('export_jobs','id'),
       ('export_jobs','user_id'),
       ('export_jobs','profile_id'),
       ('export_jobs','snapshot_id'),
       ('export_jobs','reservation_id'),
       ('export_jobs','idempotency_key'),
       ('export_jobs','request_sha256'),
       ('export_jobs','state'),
       ('export_jobs','attempt_count'),
       ('export_jobs','object_path'),
       ('export_jobs','object_generation'),
       ('export_jobs','pdf_sha256'),
       ('export_jobs','object_size'),
       ('export_jobs','created_at'),
       ('export_jobs','updated_at'),
       ('export_jobs','completed_at'),
       ('export_jobs','expires_at'),
       ('export_jobs','lease_token'),
       ('export_jobs','lease_expires_at'),
       ('export_jobs','next_attempt_at'),
       ('export_jobs','deadline'),
       ('export_jobs','object_cleanup_verified_at'),
       ('export_upload_flights','operation'),
       ('export_upload_flights','fence'),
       ('export_upload_flights','state'),
       ('export_upload_flights','generation')
      ) AS expected(table_name,column_name)
      WHERE NOT EXISTS (
       SELECT FROM information_schema.columns c
       WHERE c.table_schema='public' AND c.table_name=expected.table_name
        AND c.column_name=expected.column_name
      )`)).rows;
    if(missingColumns.length)throw Error('BASELINE_SCHEMA_DRIFT');

    const missingFunctions=(await client.query(`SELECT expected.signature
      FROM unnest($1::text[]) AS expected(signature)
      WHERE to_regprocedure(expected.signature) IS NULL`,[[
        'public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid,jsonb)',
        'public.jobix_export_source(uuid,uuid)',
        'public.jobix_export_valid(jsonb)',
        'public.jobix_export_replay(uuid,uuid,text)',
        'public.jobix_export_fonts(text)',
        'public.jobix_export_status(uuid,uuid)',
        'public.jobix_export_history(uuid,uuid)',
        'public.reserve_resume_credits(uuid,uuid)',
        'public.finish_resume_credits(uuid,uuid,boolean)',
        'public.jobix_export_retention()',
        'public.jobix_export_claim(integer)',
        'public.jobix_export_recover()',
        'public.jobix_export_quiescent(uuid,uuid)',
        'public.jobix_export_upload_begin(uuid,uuid)',
        'public.jobix_export_upload_settle(uuid,uuid,text)',
        'public.jobix_export_freeze(uuid,uuid)',
        'public.jobix_export_cleaned(uuid,text)',
        'public.jobix_export_purge(uuid,uuid,boolean)',
        'public.jobix_export_deletions()',
      ]])).rows;
    if(missingFunctions.length)throw Error('BASELINE_SCHEMA_DRIFT');

    const roles=(await client.query(`SELECT rolname,rolcanlogin,rolsuper,rolbypassrls
      FROM pg_roles WHERE rolname=ANY($1::text[]) ORDER BY rolname`,
      [['jobix_export_gateway','jobix_export_worker']])).rows;
    if(roles.length!==2||roles.some(role=>role.rolcanlogin||role.rolsuper||role.rolbypassrls)) {
      throw Error('BASELINE_SCHEMA_DRIFT');
    }

    const gateRows=(await client.query(`SELECT enabled,deletion_policy_approved
      FROM public.export_settings WHERE singleton FOR UPDATE`)).rows;
    if(gateRows.length!==1||gateRows[0].enabled!==false||
      gateRows[0].deletion_policy_approved!==true)throw Error('EXPORT_GATES_NOT_EXPECTED');

    if(!outputUnitFix) {
      const conflictingRelations=(await client.query(`SELECT name
        FROM unnest($1::text[]) AS expected(name)
        WHERE to_regclass('public.'||expected.name) IS NOT NULL`,[[
          'export_admission_events','export_admission_events_owner_time',
          'export_cost_budget_policy','export_cost_reservations',
          'export_cost_reservations_window','export_cost_attempts',
          'export_cost_provider_observations','export_admission_legacy_holds',
          'export_cost_reservations_orphans',
        ]])).rows;
      const conflictingFunctions=(await client.query(`SELECT DISTINCT p.proname
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname=ANY($1::text[])`,[[
          'jobix_export_admission_retry_seconds','jobix_export_cost_estimate',
          'jobix_export_cost_reserve','jobix_export_cost_attempt_start',
          'jobix_export_cost_attempt_finish','jobix_export_cost_settle',
          'jobix_export_cost_resolve','jobix_export_cost_reconcile',
          'jobix_export_cost_observe',
        ]])).rows;
      if(conflictingRelations.length||conflictingFunctions.length)throw Error('MIGRATION_OBJECT_CONFLICT');
    }

    const activeJobs=(await client.query(`SELECT state,count(*) AS count
      FROM public.export_jobs
      WHERE state=ANY($1::text[])
      GROUP BY state ORDER BY state`,
      [['QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE','DELETION_PENDING']])).rows;
    const unsettledUploads=(await client.query(`SELECT count(*) AS count
      FROM public.export_upload_flights WHERE state<>'SETTLED'`)).rows[0].count;
    if(activeJobs.length||BigInt(unsettledUploads)>0n)throw Error('ACTIVE_EXPORT_JOBS_PRESENT');

    if(outputUnitFix) {
      const policy=(await client.query(`SELECT accounting_ready,
        budget_microusd=10000000 AS budget_unchanged,
        rolling_window=interval '7 days' AS window_unchanged,model_version,
        shared_cost_reserve_microusd,runtime_cost_microusd_per_second,
        output_cost_microusd_per_gib_7d,storage_operation_cost_microusd,
        per_export_overhead_microusd
        FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE`)).rows;
      const heldReservations=BigInt((await client.query(`SELECT count(*) AS count
        FROM public.export_cost_reservations WHERE state='HELD'`)).rows[0].count);
      if(policy.length!==1||policy[0].accounting_ready!==false||
        policy[0].budget_unchanged!==true||policy[0].window_unchanged!==true||
        policy[0].model_version!==1||
        policy[0].shared_cost_reserve_microusd!==null||
        policy[0].runtime_cost_microusd_per_second!==null||
        policy[0].output_cost_microusd_per_gib_7d!==null||
        policy[0].storage_operation_cost_microusd!==null||
        policy[0].per_export_overhead_microusd!==null) {
        throw Error('ACCOUNTING_CONFIGURATION_NOT_READY');
      }
      if(heldReservations>0n)throw Error('ACTIVE_EXPORT_JOBS_PRESENT');
    }

    for(const version of migrationPlan) {
      const source=await readFile(resolve(import.meta.dirname,'../supabase/migrations',version+'.sql'),'utf8');
      const hash=createHash('sha256').update(source).digest('hex');
      // Keep each migration and its ledger row inside the shared transaction.
      const body=source.replace(/^BEGIN;\s*$/m,'').replace(/^COMMIT;\s*$/m,'');
      await client.query(body);
      await client.query('INSERT INTO public.jobix_export_migrations VALUES($1,$2)',[version,hash]);
    }

    const finalGates=(await client.query(`SELECT enabled,deletion_policy_approved
      FROM public.export_settings WHERE singleton FOR UPDATE`)).rows;
    if(finalGates.length!==1||finalGates[0].enabled!==gateRows[0].enabled||
      finalGates[0].deletion_policy_approved!==gateRows[0].deletion_policy_approved) {
      throw Error('EXPORT_GATES_CHANGED');
    }
    const policy=(await client.query(`SELECT accounting_ready,
      budget_microusd=10000000 AS budget_unchanged,
      rolling_window=interval '7 days' AS window_unchanged,
      shared_cost_reserve_microusd,runtime_cost_microusd_per_second,
      output_cost_microusd_per_gib_7d,storage_operation_cost_microusd,
      per_export_overhead_microusd
      FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE`)).rows;
    if(policy.length!==1||policy[0].accounting_ready!==false||
      policy[0].budget_unchanged!==true||policy[0].window_unchanged!==true||
      policy[0].shared_cost_reserve_microusd!==null||
      policy[0].runtime_cost_microusd_per_second!==null||
      policy[0].output_cost_microusd_per_gib_7d!==null||
      policy[0].storage_operation_cost_microusd!==null||
      policy[0].per_export_overhead_microusd!==null) {
      throw Error('ACCOUNTING_CONFIGURATION_NOT_READY');
    }

    await client.query('COMMIT');
    transactionOpen=false;
    console.log(outputUnitFix
      ?'DEVELOPMENT_MIGRATION_021_APPLIED_GATES_UNCHANGED_ACCOUNTING_NOT_READY'
      :'DEVELOPMENT_MIGRATIONS_018_020_APPLIED_GATES_UNCHANGED_ACCOUNTING_NOT_READY');
  } catch(error) {
    if(client&&transactionOpen)await client.query('ROLLBACK').catch(()=>{});
    throw error;
  } finally {client?.release();await pool.end();}
}
if(process.argv[1]===import.meta.filename) {
  const ca=process.argv.indexOf('--ca-file');
  const costMode=process.argv.includes('--apply-development-resume-export-018-020');
  const costOutputUnitMode=process.argv.includes('--apply-development-resume-export-cost-output-unit-021');
  const resumeLayoutMode=process.argv.includes('--apply-development-resume-layout-022');
  const legacyMode=process.argv.includes('--apply-development');
  const safeCostFailures=new Set([
    'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED','DEV_TARGET_REJECTED',
    'BASELINE_SCHEMA_DRIFT','MIGRATION_LEDGER_STATE_CONFLICT',
    'MIGRATION_CHECKSUM_CONFLICT','EXPORT_GATES_NOT_EXPECTED',
    'MIGRATION_OBJECT_CONFLICT','ACTIVE_EXPORT_JOBS_PRESENT',
    'EXPORT_GATES_CHANGED','ACCOUNTING_CONFIGURATION_NOT_READY',
    'COST_OUTPUT_UNIT_PRECONDITION_FAILED',
  ]);
  if(resumeLayoutMode&&(costMode||costOutputUnitMode||legacyMode)) {
    console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_AMBIGUOUS_MODE');process.exitCode=1;
  } else if((costMode&&legacyMode)||(costOutputUnitMode&&(costMode||legacyMode))) {
    console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_AMBIGUOUS_MODE');process.exitCode=1;
  } else if(resumeLayoutMode) {
    migrateResumeLayout({caFile:ca>=0?process.argv[ca+1]:undefined,
      approved:true}).catch(error=>{
        const safeFailures=new Set([
          'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED','DEV_TARGET_REJECTED',
          'DEV_TARGET_IDENTITY_MISMATCH','MIGRATION_SOURCE_CHECKSUM_MISMATCH',
          'LAYOUT_BASELINE_SCHEMA_DRIFT','LAYOUT_FUNCTION_ALREADY_EXISTS',
          'LAYOUT_FUNCTION_OWNER_PRIVILEGES_INSUFFICIENT',
          'MIGRATION_LEDGER_STATE_CONFLICT','MIGRATION_CHECKSUM_CONFLICT',
          'LAYOUT_POST_APPLY_ASSERTION_FAILED',
        ]);
        const reason=safeFailures.has(error?.message)?error.message:'NO_TLS_OR_ADMIN_FALLBACK';
        console.error(`DEVELOPMENT_RESUME_LAYOUT_MIGRATION_BLOCKED_${reason}`);
        process.exitCode=1;
      });
  } else if(costMode) {
    migrateResumeExportCost({caFile:ca>=0?process.argv[ca+1]:undefined,
      approved:true}).catch(error=>{
        const reason=safeCostFailures.has(error?.message)
          ?error.message:'NO_TLS_OR_ADMIN_FALLBACK';
        console.error(`DEVELOPMENT_RESUME_EXPORT_MIGRATIONS_BLOCKED_${reason}`);process.exitCode=1;
      });
  } else if(costOutputUnitMode) {
    migrateResumeExportCost({caFile:ca>=0?process.argv[ca+1]:undefined,
      approved:true,outputUnitFix:true}).catch(error=>{
        const reason=safeCostFailures.has(error?.message)
          ?error.message:'NO_TLS_OR_ADMIN_FALLBACK';
        console.error(`DEVELOPMENT_COST_OUTPUT_UNIT_MIGRATION_BLOCKED_${reason}`);process.exitCode=1;
      });
  } else {
    migrate({caFile:ca>=0?process.argv[ca+1]:undefined,
      approved:legacyMode}).catch(()=>{
        // Never print driver errors/DSNs/user data.
        console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_NO_TLS_OR_ADMIN_FALLBACK');process.exitCode=1;
      });
  }
}
