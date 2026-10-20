// Used only by test_rls.sh --education-catalog-runner-only.
// The runner's injected Pool always connects to this disposable Unix socket.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile,stat,writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {migrateEducationCatalog} from './apply_phase3_dev.mjs';

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
const owner='jobix_catalog_migrator';
const version='202610190023_education_catalog';
const expectedHash='462f8ee5bd4e094539996615a8aa2b1433f257fa5cd6161eb3d811814d2d3372';
const priorMigrations=[
  ['202610080012_resume_export_foundation','000e679329170539502fa5f8e672cb93c42652eda2451d3ae3075efdaf624db0'],
  ['202610080013_resume_export_lifecycle','df807dbecf098306bae74f8afe7a01a9d28a09c91477203179278a00a4a928b9'],
  ['202610080014_resume_configuration_concurrency','e8eaa30acea373460cd2e43c2a525bf083f30b92d4b2a125de2d9dd4cbf53284'],
  ['202610080015_resume_export_local_hardening','3cd8af5855fe2976216111ebb4cfee490556881441fb28f46afaccd0290858db'],
  ['202610080016_resume_export_cleanup_hooks','018becbe1a190797e1dbef907159d579de87a4c25eba24dbb7fa72e97697256c'],
  ['202610080017_resume_export_deletion','70a04b0ad7e397bbef9ee0cd5a1ce34d60ffc109ea6bb4eab811e2851986fc12'],
  ['202610080018_resume_export_admission','9b64fa82315dd4469c0842c28568f393eeedbc5a25f1b186af4718cc8c86b76a'],
  ['202610100019_resume_export_cost_protection','a2801821b915cbabdfbd6bd35aa4e55a61e9da06463a4f7a4a74f79506d301cd'],
  ['202610100020_resume_export_cost_purge_recovery','cb63d7f31b772b61d4ba719172cac40837d7b0978123795213ae385bd5307cba'],
  ['202610100021_resume_export_cost_output_unit','147a14c1acb399237a831a994163ebf4006f82d718363e1c370ba937a838fae6'],
  ['202610170022_resume_layout','d34f6dad4d9edcd301486d9d507bed7330c0fde66cfac3630bee087fa8366473'],
];
const caFile=join(dirname(socket),'synthetic-education-ca.pem');
const oldDatabaseUrl=process.env.JOBIX_DEV_DATABASE_URL;
let stage='verify disposable PostgreSQL isolation';

try {
  const identity=(await admin.query(`SELECT current_database() AS database,
    current_user AS role,inet_server_addr() IS NULL AS socket_only,
    current_setting('listen_addresses') AS listen,
    current_setting('data_directory') AS data,
    current_setting('unix_socket_directories') AS socket,
    current_setting('port') AS port`)).rows[0];
  assert.deepEqual(identity,{database:'postgres',role:'runner',socket_only:true,
    listen:'',data,socket,port:'55439'});
  console.log('PASS: isolated disposable PostgreSQL verified (Unix socket; TCP disabled)');

  stage='record unchanged local Development-like gates';
  const before=(await admin.query(`SELECT
    (SELECT enabled FROM public.export_settings WHERE singleton) AS export_enabled,
    (SELECT accounting_ready FROM public.export_cost_budget_policy WHERE singleton)
      AS accounting_ready,
    (SELECT deletion_policy_approved FROM public.export_settings WHERE singleton)
      AS deletion_approved`)).rows[0];
  assert.ok(before);

  stage='create disposable least-privilege migration fixture';
  await admin.query(`CREATE ROLE ${owner} LOGIN NOSUPERUSER NOCREATEDB
    NOCREATEROLE NOINHERIT NOBYPASSRLS;
    GRANT USAGE,CREATE ON SCHEMA public TO ${owner};
    GRANT USAGE ON SCHEMA auth TO ${owner};
    GRANT EXECUTE ON FUNCTION auth.uid() TO ${owner};
    CREATE TABLE public.jobix_export_migrations(
      version text PRIMARY KEY,sha256 text NOT NULL);
    ALTER TABLE public.jobix_export_migrations OWNER TO ${owner};
    ALTER TABLE public.jobix_export_migrations ENABLE ROW LEVEL SECURITY;
    REVOKE ALL ON public.jobix_export_migrations
      FROM PUBLIC,anon,authenticated,service_role`);

  const ledgerRows=[];
  for(const [priorVersion,expectedPriorHash] of priorMigrations) {
    const source=await readFile(new URL(
      `../supabase/migrations/${priorVersion}.sql`,import.meta.url),'utf8');
    const sha256=createHash('sha256').update(source).digest('hex');
    assert.equal(sha256,expectedPriorHash,`local source checksum mismatch: ${priorVersion}`);
    ledgerRows.push({version:priorVersion,sha256:expectedPriorHash});
    await admin.query(
      'INSERT INTO public.jobix_export_migrations(version,sha256) VALUES($1,$2)',
      [priorVersion,expectedPriorHash],
    );
  }
  const migrationSource=await readFile(new URL(
    `../supabase/migrations/${version}.sql`,import.meta.url),'utf8');
  assert.equal(createHash('sha256').update(migrationSource).digest('hex'),expectedHash);
  await writeFile(caFile,
    '-----BEGIN CERTIFICATE-----\ndisposable-only\n-----END CERTIFICATE-----\n');
  // This synthetic target is never used for networking; fixturePool below
  // discards it and opens only the verified local Unix socket.
  process.env.JOBIX_DEV_DATABASE_URL=
    `postgresql://${owner}.lmouxhbjhtqdtiqijcee:disposable-only@aws-0-me-central1.pooler.supabase.com:5432/postgres`;

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
              const isMigration=sql.includes('CREATE TABLE public.education_institution_catalog');
              const isLedger=sql.startsWith('INSERT INTO public.jobix_export_migrations');
              if(isMigration)counters.migration++;
              if(isLedger)counters.ledger++;
              const result=await client.query(sql,params);
              if((isMigration&&fault==='migration')||(isLedger&&fault==='ledger')) {
                await client.query('SELECT 1/0');
              }
              if(sql.includes('AS tables_complete')&&fault==='postcondition') {
                return {rows:[{...result.rows[0],field_seed_complete:false}]};
              }
              if(sql==='COMMIT'&&fault==='commit-after-commit') {
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
  const run=(fault=null,counters)=>migrateEducationCatalog({
    approved:true,caFile,poolFactory:fixturePool(fault,counters),
  });
  async function assertUnapplied() {
    const result=(await admin.query(`SELECT
      to_regclass('public.education_institution_catalog') IS NULL AS institution_absent,
      to_regclass('public.study_field_catalog') IS NULL AS field_absent,
      NOT EXISTS(SELECT 1 FROM public.jobix_export_migrations WHERE version=$1)
        AS ledger_absent`,[version])).rows[0];
    assert.deepEqual(result,{institution_absent:true,field_absent:true,ledger_absent:true});
  }

  stage='previous ledger mismatch checks';
  const last=ledgerRows.at(-1);
  await admin.query('DELETE FROM public.jobix_export_migrations WHERE version=$1',[last.version]);
  await assert.rejects(run(),{message:'MIGRATION_LEDGER_STATE_CONFLICT'});
  await admin.query(
    'INSERT INTO public.jobix_export_migrations(version,sha256) VALUES($1,$2)',
    [last.version,last.sha256],
  );
  await admin.query('UPDATE public.jobix_export_migrations SET sha256=$1 WHERE version=$2',
    ['0'.repeat(64),last.version]);
  await assert.rejects(run(),{message:'MIGRATION_CHECKSUM_CONFLICT'});
  await admin.query('UPDATE public.jobix_export_migrations SET sha256=$1 WHERE version=$2',
    [last.sha256,last.version]);
  await assertUnapplied();
  console.log('PASS: missing/mismatched 012–022 ledger rows abort without repair');

  stage='schema conflict detection';
  await admin.query('CREATE VIEW public.education_institution_catalog AS SELECT 1 AS conflict');
  await assert.rejects(run(),{message:'MIGRATION_023_SCHEMA_CONFLICT'});
  await admin.query('DROP VIEW public.education_institution_catalog');
  await assertUnapplied();
  console.log('PASS: pre-existing relation conflict aborts without repair');

  stage='migration advisory lock contention';
  const blocker=await admin.connect();
  try {
    await blocker.query('BEGIN');
    await blocker.query(
      "SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))",
    );
    await assert.rejects(run(),{message:'MIGRATION_LOCK_BUSY'});
    await blocker.query('ROLLBACK');
  } finally {
    await blocker.query('ROLLBACK').catch(()=>{});
    blocker.release();
  }
  await assertUnapplied();
  console.log('PASS: shared advisory lock prevents concurrent migration');

  stage='migration, ledger, and postcondition transaction rollback';
  for(const fault of ['migration','ledger','postcondition']) {
    await assert.rejects(run(fault),fault==='postcondition'
      ?{message:'MIGRATION_023_POST_ASSERTION_FAILED'}
      :/division by zero/);
    await assertUnapplied();
  }
  console.log('PASS: DDL, ledger, and failed postconditions roll back atomically');

  stage='unknown commit response and safe reconciliation';
  await assert.rejects(run('commit-after-commit'),{
    message:'MIGRATION_COMMIT_OUTCOME_UNKNOWN',
  });
  const committed=(await admin.query(`SELECT
    to_regclass('public.education_institution_catalog') IS NOT NULL AS table_present,
    EXISTS(SELECT 1 FROM public.jobix_export_migrations
      WHERE version=$1 AND sha256=$2) AS ledger_present`,
  [version,expectedHash])).rows[0];
  assert.deepEqual(committed,{table_present:true,ledger_present:true});
  const counters={migration:0,ledger:0};
  assert.equal(await run(null,counters),'already-applied');
  assert.deepEqual(counters,{migration:0,ledger:0});
  console.log('PASS: uncertain commit is surfaced, then reconciled without replay');

  stage='catalog post-application invariants';
  const catalog=(await admin.query(`SELECT
    (SELECT count(*)=139 FROM public.education_institution_catalog)
      AS institution_count,
    (SELECT count(DISTINCT institution_type)=7
      FROM public.education_institution_catalog) AS institution_types,
    (SELECT count(*)=62 FROM public.study_field_catalog) AS field_count,
    (SELECT count(*)=21 FROM information_schema.columns
      WHERE table_schema='public'
        AND table_name=ANY(ARRAY['education_institution_catalog','study_field_catalog']))
      AS columns,
    (SELECT count(*)=7 AND bool_and(i.indisvalid AND i.indisready)
      FROM pg_class idx JOIN pg_namespace n ON n.oid=idx.relnamespace
      JOIN pg_index i ON i.indexrelid=idx.oid
      WHERE n.nspname='public' AND idx.relname=ANY(ARRAY[
        'education_institution_catalog_pkey',
        'education_institution_catalog_name_en_uq',
        'education_institution_catalog_name_ar_uq',
        'education_institution_catalog_type_idx',
        'study_field_catalog_pkey',
        'study_field_catalog_name_en_idx',
        'study_field_catalog_name_ar_idx']))
      AS indexes,
    (SELECT count(*)=10 AND bool_and(con.convalidated)
      FROM pg_constraint con JOIN pg_class tbl ON tbl.oid=con.conrelid
      JOIN pg_namespace n ON n.oid=tbl.relnamespace
      WHERE n.nspname='public'
        AND tbl.relname=ANY(ARRAY['education_institution_catalog','study_field_catalog'])
        AND con.contype IN ('p','c')) AS constraints,
    (SELECT count(*)=2 AND bool_and(relrowsecurity AND NOT relforcerowsecurity)
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public'
        AND c.relname=ANY(ARRAY['education_institution_catalog','study_field_catalog']))
      AS rls,
    (SELECT count(*)=2 AND bool_and(cmd='SELECT'
       AND roles=ARRAY['authenticated']::name[]
       AND lower(coalesce(qual,'')) LIKE '%auth.uid%')
      FROM pg_policies WHERE schemaname='public'
        AND tablename=ANY(ARRAY['education_institution_catalog','study_field_catalog']))
      AS policies,
    has_table_privilege('authenticated','public.education_institution_catalog','SELECT')
      AND has_table_privilege('authenticated','public.study_field_catalog','SELECT')
      AND NOT has_table_privilege('anon','public.education_institution_catalog','SELECT')
      AND NOT has_table_privilege('anon','public.study_field_catalog','SELECT')
      AND NOT has_table_privilege('service_role','public.education_institution_catalog','SELECT')
      AND NOT has_table_privilege('service_role','public.study_field_catalog','SELECT')
      AS grants,
    EXISTS(SELECT 1 FROM public.jobix_export_migrations
      WHERE version=$1 AND sha256=$2) AS ledger` ,
  [version,expectedHash])).rows[0];
  assert.deepEqual(catalog,{
    institution_count:true,institution_types:true,field_count:true,columns:true,
    indexes:true,constraints:true,rls:true,policies:true,grants:true,ledger:true,
  });
  const after=(await admin.query(`SELECT
    (SELECT enabled FROM public.export_settings WHERE singleton) AS export_enabled,
    (SELECT accounting_ready FROM public.export_cost_budget_policy WHERE singleton)
      AS accounting_ready,
    (SELECT deletion_policy_approved FROM public.export_settings WHERE singleton)
      AS deletion_approved`)).rows[0];
  assert.deepEqual(after,before);
  console.log('PASS: schema, RLS, grants, 139/7/62 seed totals, ledger, and gates verified');
  console.log('PASS: Development-like disposable gates/configuration unchanged');
} catch(error) {
  console.error(`FAIL: disposable Migration 023 integration stage: ${stage}`);
  throw error;
} finally {
  if(oldDatabaseUrl===undefined)delete process.env.JOBIX_DEV_DATABASE_URL;
  else process.env.JOBIX_DEV_DATABASE_URL=oldDatabaseUrl;
  await admin.end();
}
