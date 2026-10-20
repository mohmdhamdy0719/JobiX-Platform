// Invoked only by test_rls.sh --profile-entry-drafts-runner-only.
// No TCP connection, configured database URL, or runtime credential is used.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile,stat,writeFile,unlink} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {migrateProfileEntryDrafts} from './apply_phase3_dev.mjs';

const socket=process.env.JOBIX_DISPOSABLE_PG_SOCKET;
const data=process.env.JOBIX_DISPOSABLE_PG_DATA;
if(!/^\/tmp\/jobix-rls\.[^/]+\/socket$/.test(socket??'')||
  data!==join(dirname(socket??''),'data')||
  !(await stat(join(socket,'.s.PGSQL.55439'))).isSocket()) {
  throw Error('DISPOSABLE_LOCAL_SOCKET_REQUIRED');
}
const local={host:socket,port:55439,database:'postgres',user:'runner',
  password:'',ssl:false,max:1,connectionTimeoutMillis:5000,statement_timeout:30000};
const admin=new Pool(local);
const owner='jobix_disposable_migrator';
const caFile=join(dirname(socket),'synthetic-ca.pem');
const version024='202610200024_persisted_profile_entry_drafts';
const hash024='f246e45dce62c0d03457fe825ab2db14b687f32a92661572867e2fa1a5a48af6';
const priorVersions=[
  '202610080012_resume_export_foundation','202610080013_resume_export_lifecycle',
  '202610080014_resume_configuration_concurrency','202610080015_resume_export_local_hardening',
  '202610080016_resume_export_cleanup_hooks','202610080017_resume_export_deletion',
  '202610080018_resume_export_admission','202610100019_resume_export_cost_protection',
  '202610100020_resume_export_cost_purge_recovery','202610100021_resume_export_cost_output_unit',
  '202610170022_resume_layout','202610190023_education_catalog',
];
let stage='verify local isolation';
try {
  const identity=(await admin.query(`SELECT current_database() AS database,
    current_user AS role,inet_server_addr() IS NULL AS socket_only,
    current_setting('listen_addresses') AS listen,
    current_setting('data_directory') AS data,
    current_setting('unix_socket_directories') AS socket,
    current_setting('port') AS port`)).rows[0];
  assert.deepEqual(identity,{database:'postgres',role:'runner',socket_only:true,
    listen:'',data,socket,port:'55439'});
  console.log('PASS: runner integration verified disposable Unix socket and TCP disabled');

  stage='create disposable owner and migration ledger fixtures';
  await admin.query(`CREATE ROLE ${owner} LOGIN NOSUPERUSER NOCREATEDB
    NOCREATEROLE NOINHERIT NOBYPASSRLS;
    GRANT USAGE,CREATE ON SCHEMA public TO ${owner};
    GRANT USAGE ON SCHEMA auth TO ${owner};
    GRANT EXECUTE ON FUNCTION auth.uid() TO ${owner};
    CREATE TABLE public.jobix_export_migrations(version text PRIMARY KEY,sha256 text NOT NULL);
    ALTER TABLE public.jobix_export_migrations ENABLE ROW LEVEL SECURITY;
    REVOKE ALL ON public.jobix_export_migrations FROM PUBLIC,anon,authenticated,service_role`);
  const entries=[];
  for(const version of priorVersions) {
    const source=await readFile(new URL(
      `../supabase/migrations/${version}.sql`,import.meta.url),'utf8');
    const sha256=createHash('sha256').update(source).digest('hex');
    entries.push({version,sha256});
    await admin.query('INSERT INTO public.jobix_export_migrations VALUES($1,$2)',
      [version,sha256]);
  }
  // Fixture ownership only: no ownership/privilege operation exists in the
  // runner. Give this synthetic non-admin owner the existing application
  // objects so the actual DDL and SECURITY DEFINER checks can be exercised.
  await admin.query(`DO $fixture$
    DECLARE object record;
    BEGIN
      FOR object IN SELECT c.relname FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relkind='r'
      LOOP
        EXECUTE format('ALTER TABLE public.%I OWNER TO ${owner}',object.relname);
      END LOOP;
      FOR object IN SELECT p.oid,p.proname,pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.prokind='f'
          AND NOT EXISTS(SELECT 1 FROM pg_depend d
            WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e')
      LOOP
        EXECUTE format('ALTER FUNCTION public.%I(%s) OWNER TO ${owner}',
          object.proname,object.args);
      END LOOP;
    END $fixture$`);
  await writeFile(caFile,
    '-----BEGIN CERTIFICATE-----\nsynthetic-local-only\n-----END CERTIFICATE-----\n');
  // Overwrite the child process's configuration with a synthetic, pinned URL.
  // The injected factory below ignores it and connects exclusively by socket.
  process.env.JOBIX_DEV_DATABASE_URL=
    `${'postgresql:'}//${owner}.lmouxhbjhtqdtiqijcee:synthetic-password@aws-0-me-central1.pooler.supabase.com:5432/postgres`;

  function fixturePool(fault=null,counters={migration:0,ledger:0}) {
    return options=>{
      assert.equal(options.ssl.rejectUnauthorized,true);
      assert.equal(options.max,1);
      assert.equal(options.options,'');
      const pool=new Pool({...local,user:owner});
      return {
        async connect() {
          const client=await pool.connect();
          return {
            async query(sql,params) {
              const migration=sql.includes('CREATE FUNCTION public.save_profile_entry');
              const ledger=sql.startsWith('INSERT INTO public.jobix_export_migrations');
              if(migration)counters.migration++;
              if(ledger)counters.ledger++;
              const result=await client.query(sql,params);
              if((migration&&fault==='migration')||(ledger&&fault==='ledger')) {
                await client.query('SELECT 1/0');
              }
              if(sql==='COMMIT'&&fault==='commit') {
                throw Error('SYNTHETIC_COMMIT_RESPONSE_LOST');
              }
              return result;
            },
            release:()=>client.release(),
          };
        },
        end:()=>pool.end(),
      };
    };
  }
  const run=(fault=null,counters)=>migrateProfileEntryDrafts({
    approved:true,caFile,poolFactory:fixturePool(fault,counters),
  });
  async function assertUnapplied() {
    const result=(await admin.query(`SELECT
      NOT EXISTS(SELECT 1 FROM public.jobix_export_migrations WHERE version=$1) AS ledger_absent,
      NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='profile_experiences' AND column_name='is_draft') AS column_absent,
      to_regprocedure('public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)')
        IS NULL AS rpc_absent`,[version024])).rows[0];
    assert.deepEqual(result,{ledger_absent:true,column_absent:true,rpc_absent:true});
  }
  async function settings() {
    return (await admin.query(`SELECT
      (SELECT to_jsonb(s) FROM public.export_settings s WHERE singleton) AS gates,
      (SELECT to_jsonb(p) FROM public.export_cost_budget_policy p WHERE singleton) AS policy,
      (SELECT count(*)::int FROM public.resume_configurations) AS layout_rows`)).rows[0];
  }
  const before=await settings();

  stage='prior ledger mismatch and missing entry';
  const last=entries.at(-1);
  await admin.query('DELETE FROM public.jobix_export_migrations WHERE version=$1',[last.version]);
  await assert.rejects(run(),{message:'MIGRATION_LEDGER_STATE_CONFLICT'});
  await admin.query('INSERT INTO public.jobix_export_migrations VALUES($1,$2)',
    [last.version,last.sha256]);
  await admin.query('UPDATE public.jobix_export_migrations SET sha256=$1 WHERE version=$2',
    ['0'.repeat(64),last.version]);
  await assert.rejects(run(),{message:'MIGRATION_CHECKSUM_CONFLICT'});
  await admin.query('UPDATE public.jobix_export_migrations SET sha256=$1 WHERE version=$2',
    [last.sha256,last.version]);
  console.log('PASS: real missing/mismatched prior ledger aborts without repair');

  stage='partial schema detection';
  await admin.query('ALTER TABLE public.profile_skills ADD COLUMN is_draft boolean');
  await assert.rejects(run(),{message:'MIGRATION_024_SCHEMA_CONFLICT'});
  await admin.query('ALTER TABLE public.profile_skills DROP COLUMN is_draft');
  console.log('PASS: real partial schema aborts without automatic repair');

  stage='advisory and table contention';
  const blocker=await admin.connect();
  try {
    await blocker.query('BEGIN');
    await blocker.query(
      "SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))");
    await assert.rejects(run(),{message:'MIGRATION_LOCK_BUSY'});
    await blocker.query('ROLLBACK');
    await blocker.query('BEGIN');
    await blocker.query('LOCK TABLE public.profile_experiences IN ACCESS SHARE MODE');
    await assert.rejects(run(),{message:'MIGRATION_LOCK_CONTENTION'});
    await blocker.query('ROLLBACK');
  } finally {
    await blocker.query('ROLLBACK').catch(()=>{});
    blocker.release();
  }
  console.log('PASS: real advisory/table lock contention aborts without waiting');

  stage='DDL and ledger transaction rollback';
  for(const fault of ['migration','ledger']) {
    await assert.rejects(run(fault),{code:'22012'});
    await assertUnapplied();
  }
  console.log('PASS: real DDL and ledger-insert failures roll back schema and ledger');

  stage='commit response loss and read-only reconciliation';
  await assert.rejects(run('commit'),{message:'MIGRATION_COMMIT_OUTCOME_UNKNOWN'});
  const verifier=await admin.connect();
  try {
    await verifier.query('BEGIN READ ONLY');
    const rows=(await verifier.query(
      'SELECT sha256 FROM public.jobix_export_migrations WHERE version=$1',[version024])).rows;
    assert.deepEqual(rows,[{sha256:hash024}]);
    const schema=(await verifier.query(`SELECT
      to_regprocedure('public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)')
        IS NOT NULL AS rpc_exists,
      (SELECT count(*)::int FROM information_schema.columns
        WHERE table_schema='public' AND column_name='is_draft') AS draft_columns`)).rows[0];
    assert.deepEqual(schema,{rpc_exists:true,draft_columns:8});
    await verifier.query('ROLLBACK');
  } finally {
    await verifier.query('ROLLBACK').catch(()=>{});
    verifier.release();
  }
  console.log('PASS: lost COMMIT response stays unknown until read-only ledger/schema evidence');

  stage='already applied verification-only';
  const counters={migration:0,ledger:0};
  assert.equal(await run(null,counters),'already-applied');
  assert.deepEqual(counters,{migration:0,ledger:0});
  assert.deepEqual(await settings(),before);
  console.log('PASS: matching 024 verifies without reapplication; gates, accounting and layouts unchanged');
} catch(error) {
  const code=/^[A-Z0-9_]+$/.test(error?.message??'')
    ?error.message:/^[A-Z0-9_]+$/.test(error?.code??'')?error.code:error?.name??'SUPPRESSED';
  console.error(`FAIL: disposable Migration 024 runner; stage=${stage}; code=${code}`);
  process.exitCode=1;
} finally {
  await admin.end();
  await unlink(caFile).catch(()=>{});
}
