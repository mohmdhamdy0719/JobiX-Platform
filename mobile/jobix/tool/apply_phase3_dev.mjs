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
const profileEntryDraftVersion='202610200024_persisted_profile_entry_drafts';
const profileEntryDraftExpectedSha256='f246e45dce62c0d03457fe825ab2db14b687f32a92661572867e2fa1a5a48af6';
const profileEntryDraftPrerequisites=[
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
  ['202610190023_education_catalog','462f8ee5bd4e094539996615a8aa2b1433f257fa5cd6161eb3d811814d2d3372'],
];
const profileEntryDraftTables=[
  'profile_experiences','profile_education','profile_certifications',
  'profile_achievements','profile_projects','profile_skills','profile_languages',
  'profile_volunteer_experiences',
];
const profileEntryDraftPrerequisiteRelations=[
  'jobix_export_migrations','users','career_profiles','profile_personal_data',
  'profile_summaries','idempotency_records','export_jobs','export_upload_flights',
  'export_cost_reservations',...profileEntryDraftTables,
];
const profileEntryDraftPrerequisiteFunctions=[
  'auth.uid()',
  'public.jobix_meaningful(text,integer)',
  'public.jobix_name_key(text)',
  'public.jobix_text_field(jsonb,text,integer)',
  'public.jobix_month_field(jsonb,text)',
  'public.jobix_bool_field(jsonb,text)',
  'public.jobix_next_order(text,uuid)',
  'public.profile_mutate(uuid,uuid,bigint,jsonb)',
  'public.jobix_profile_mutate_base(uuid,uuid,bigint,jsonb)',
  'public.jobix_experience_complete(public.profile_experiences)',
  'public.jobix_education_complete(public.profile_education)',
  'public.jobix_project_complete(public.profile_projects)',
  'public.jobix_achievement_complete(public.profile_achievements)',
  'public.jobix_recompute_text_profile(uuid)',
  'public.jobix_profile_text_snapshot(uuid)',
  'public.jobix_profile_text_snapshot_pre_volunteer(uuid)',
  'public.jobix_export_source(uuid,uuid)',
];
const profileEntryDraftOwnedFunctions=[
  'public.jobix_experience_complete(public.profile_experiences)',
  'public.jobix_education_complete(public.profile_education)',
  'public.jobix_project_complete(public.profile_projects)',
  'public.jobix_achievement_complete(public.profile_achievements)',
  'public.jobix_recompute_text_profile(uuid)',
  'public.jobix_profile_text_snapshot(uuid)',
];
const profileEntryDraftConflictingFunctions=[
  'public.jobix_profile_entry_draft_state()',
  'public.jobix_visible_profile_items(uuid,text,jsonb)',
  'public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)',
];

export function verifyResumeLayoutMigrationSource(source) {
  const actual=createHash('sha256').update(source).digest('hex');
  if(actual!==resumeLayoutExpectedSha256)throw Error('MIGRATION_SOURCE_CHECKSUM_MISMATCH');
  return actual;
}

export function verifyProfileEntryDraftMigrationSource(source) {
  const actual=createHash('sha256').update(source).digest('hex');
  if(actual!==profileEntryDraftExpectedSha256) {
    throw Error('MIGRATION_SOURCE_CHECKSUM_MISMATCH');
  }
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

async function readProfileEntryDraftSchemaState(client) {
  return (await client.query(`SELECT
    (SELECT count(*)::int FROM pg_attribute a
      JOIN pg_class c ON c.oid=a.attrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY($1::text[])
        AND a.attname='is_draft' AND a.attnum>0 AND NOT a.attisdropped) AS draft_columns,
    (SELECT count(*)::int FROM pg_attribute a
      JOIN pg_class c ON c.oid=a.attrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
      WHERE n.nspname='public' AND c.relname=ANY($1::text[])
        AND a.attname='is_draft' AND a.attnum>0 AND NOT a.attisdropped
        AND a.attnotnull AND pg_get_expr(d.adbin,d.adrelid)='false')
      AS safe_draft_columns,
    (SELECT count(*)::int FROM unnest($2::text[]) AS expected(signature)
      JOIN pg_proc p ON p.oid=to_regprocedure(expected.signature)
      WHERE p.prokind='f') AS draft_functions,
    (SELECT count(*)::int FROM pg_trigger t
      JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY($1::text[])
        AND t.tgname='jobix_entry_draft_state' AND NOT t.tgisinternal) AS draft_triggers,
    (SELECT count(*)::int FROM pg_trigger t
      JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY($1::text[])
        AND t.tgname='jobix_entry_draft_state' AND NOT t.tgisinternal
        AND t.tgtype=23
        AND t.tgfoid=to_regprocedure('public.jobix_profile_entry_draft_state()'))
      AS correct_draft_triggers,
    to_regprocedure('public.jobix_profile_text_snapshot_pre_entry_drafts(uuid)') IS NOT NULL
      AS archived_snapshot,
    to_regprocedure('public.jobix_profile_text_snapshot_pre_volunteer(uuid)') IS NOT NULL
      AS pre_volunteer_snapshot,
    to_regprocedure('public.jobix_profile_text_snapshot(uuid)') IS NOT NULL AS current_snapshot,
    EXISTS(SELECT 1 FROM pg_constraint c
      JOIN pg_class t ON t.oid=c.conrelid
      JOIN pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname='public' AND t.relname='profile_volunteer_experiences'
        AND c.conname='profile_volunteer_experiences_check') AS old_volunteer_constraint,
    EXISTS(SELECT 1 FROM pg_constraint c
      JOIN pg_class t ON t.oid=c.conrelid
      JOIN pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname='public' AND t.relname='profile_volunteer_experiences'
        AND c.conname='profile_volunteer_experiences_draft_or_valid')
      AS draft_volunteer_constraint,
    coalesce((SELECT c.convalidated FROM pg_constraint c
      JOIN pg_class t ON t.oid=c.conrelid
      JOIN pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname='public' AND t.relname='profile_volunteer_experiences'
        AND c.conname='profile_volunteer_experiences_draft_or_valid'),false)
      AS draft_volunteer_constraint_validated,
    (SELECT pg_get_constraintdef(c.oid) FROM pg_constraint c
      JOIN pg_class t ON t.oid=c.conrelid
      JOIN pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname='public' AND t.relname='profile_volunteer_experiences'
        AND c.conname='profile_volunteer_experiences_draft_or_valid')
      AS draft_volunteer_constraint_definition,
    (SELECT a.attnotnull FROM pg_attribute a
      JOIN pg_class c ON c.oid=a.attrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='profile_skills' AND a.attname='name'
        AND a.attnum>0 AND NOT a.attisdropped) AS skill_name_not_null,
    (SELECT a.attnotnull FROM pg_attribute a
      JOIN pg_class c ON c.oid=a.attrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='profile_languages' AND a.attname='name'
        AND a.attnum>0 AND NOT a.attisdropped) AS language_name_not_null,
    (SELECT a.attnotnull FROM pg_attribute a
      JOIN pg_class c ON c.oid=a.attrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='profile_languages'
        AND a.attname='proficiency' AND a.attnum>0 AND NOT a.attisdropped)
      AS language_proficiency_not_null
  `,[profileEntryDraftTables,profileEntryDraftConflictingFunctions])).rows[0];
}

function isProfileEntryDraftSchemaAbsent(state) {
  return state?.draft_columns===0&&state.draft_functions===0&&state.draft_triggers===0&&
    state.safe_draft_columns===0&&state.correct_draft_triggers===0&&
    state.archived_snapshot===false&&state.pre_volunteer_snapshot===true&&
    state.current_snapshot===true&&state.old_volunteer_constraint===true&&
    state.draft_volunteer_constraint===false&&
    state.draft_volunteer_constraint_validated===false&&
    state.skill_name_not_null===true&&
    state.language_name_not_null===true&&state.language_proficiency_not_null===true;
}

function isProfileEntryDraftSchemaComplete(state) {
  const constraintDefinition=(state?.draft_volunteer_constraint_definition??'')
    .toLowerCase().replace(/[\s()"']/g,'');
  const hasExpectedConstraintTerms=[
    'is_draft','organizationisnotnull','roleisnotnull','start_monthisnotnull',
    'is_current','end_month',
  ].every(term=>constraintDefinition.includes(term));
  return state?.draft_columns===profileEntryDraftTables.length&&
    state.safe_draft_columns===profileEntryDraftTables.length&&
    state.draft_functions===profileEntryDraftConflictingFunctions.length&&
    state.draft_triggers===profileEntryDraftTables.length&&
    state.correct_draft_triggers===profileEntryDraftTables.length&&
    state.archived_snapshot===true&&state.pre_volunteer_snapshot===true&&
    state.current_snapshot===true&&state.old_volunteer_constraint===false&&
    state.draft_volunteer_constraint===true&&
    state.draft_volunteer_constraint_validated===true&&hasExpectedConstraintTerms&&
    state.skill_name_not_null===false&&
    state.language_name_not_null===false&&state.language_proficiency_not_null===false;
}

async function readProfileEntryDraftLedger(client) {
  return (await client.query(
    'SELECT version,sha256 FROM public.jobix_export_migrations ORDER BY version',
  )).rows;
}

function verifyProfileEntryDraftLedger(rows) {
  const priorCount=profileEntryDraftPrerequisites.length;
  const has024=rows.length===priorCount+1;
  if(rows.length!==priorCount&&!has024) {
    throw Error('MIGRATION_LEDGER_STATE_CONFLICT');
  }
  for(let index=0;index<priorCount;index++) {
    const [version,sha256]=profileEntryDraftPrerequisites[index];
    if(rows[index]?.version!==version)throw Error('MIGRATION_LEDGER_STATE_CONFLICT');
    if(rows[index]?.sha256!==sha256)throw Error('MIGRATION_CHECKSUM_CONFLICT');
  }
  if(has024) {
    if(rows[priorCount]?.version!==profileEntryDraftVersion) {
      throw Error('MIGRATION_LEDGER_STATE_CONFLICT');
    }
    if(rows[priorCount]?.sha256!==profileEntryDraftExpectedSha256) {
      throw Error('MIGRATION_CHECKSUM_CONFLICT');
    }
  }
  return has024;
}

async function assertProfileEntryDraftPostState(client,sourceHash) {
  const schema=await readProfileEntryDraftSchemaState(client);
  if(!isProfileEntryDraftSchemaComplete(schema)) {
    throw Error('MIGRATION_024_SCHEMA_NOT_COMPLETE');
  }
  const installed=(await client.query(`SELECT
    save.prokind='f' AS save_is_function,
    save.prosecdef AS save_security_definer,
    owner.rolsuper OR owner.rolbypassrls OR owner.rolcreaterole OR owner.rolcreatedb
      AS unsafe_save_owner,
    has_function_privilege('authenticated',
      'public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)','EXECUTE') AS save_authenticated,
    has_function_privilege('anon',
      'public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)','EXECUTE') AS save_anon,
    has_function_privilege('service_role',
      'public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)','EXECUTE') AS save_service,
    NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(save.proacl,
      acldefault('f',save.proowner))) acl
      WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE') AS save_public_revoked,
    visible.prokind='f' AND visible.prosecdef AS visible_secdef,
    snapshot.prokind='f' AND snapshot.prosecdef AS snapshot_secdef,
    NOT trigger_fn.prosecdef AS trigger_fn_invoker,
    NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(visible.proacl,
      acldefault('f',visible.proowner))) acl
      WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE') AS visible_public_revoked,
    NOT has_function_privilege('anon',
      'public.jobix_visible_profile_items(uuid,text,jsonb)','EXECUTE')
      AND NOT has_function_privilege('authenticated',
      'public.jobix_visible_profile_items(uuid,text,jsonb)','EXECUTE') AS visible_client_revoked,
    NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(snapshot.proacl,
      acldefault('f',snapshot.proowner))) acl
      WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE')
      AND NOT has_function_privilege('anon',
      'public.jobix_profile_text_snapshot(uuid)','EXECUTE')
      AND NOT has_function_privilege('authenticated',
      'public.jobix_profile_text_snapshot(uuid)','EXECUTE') AS snapshot_client_revoked,
    NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(trigger_fn.proacl,
      acldefault('f',trigger_fn.proowner))) acl
      WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE')
      AND NOT has_function_privilege('anon',
      'public.jobix_profile_entry_draft_state()','EXECUTE')
      AND NOT has_function_privilege('authenticated',
      'public.jobix_profile_entry_draft_state()','EXECUTE') AS trigger_client_revoked,
    EXISTS(SELECT 1 FROM public.jobix_export_migrations m
      WHERE m.version=$1 AND m.sha256=$2) AS ledger_matches
    FROM pg_proc save
    JOIN pg_roles owner ON owner.oid=save.proowner
    JOIN pg_proc visible
      ON visible.oid=to_regprocedure('public.jobix_visible_profile_items(uuid,text,jsonb)')
    JOIN pg_proc snapshot
      ON snapshot.oid=to_regprocedure('public.jobix_profile_text_snapshot(uuid)')
    JOIN pg_proc trigger_fn
      ON trigger_fn.oid=to_regprocedure('public.jobix_profile_entry_draft_state()')
    WHERE save.oid=to_regprocedure(
      'public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)')`,
  [profileEntryDraftVersion,sourceHash])).rows[0];
  if(!installed||installed.save_is_function!==true||
    installed.save_security_definer!==true||installed.unsafe_save_owner!==false||
    installed.save_authenticated!==true||installed.save_anon!==false||
    installed.save_service!==false||installed.save_public_revoked!==true||
    installed.visible_secdef!==true||installed.snapshot_secdef!==true||
    installed.trigger_fn_invoker!==true||installed.visible_public_revoked!==true||
    installed.visible_client_revoked!==true||installed.snapshot_client_revoked!==true||
    installed.trigger_client_revoked!==true||installed.ledger_matches!==true) {
    throw Error('MIGRATION_024_POST_ASSERTION_FAILED');
  }
}

export async function migrateProfileEntryDrafts({
  caFile,approved=false,poolFactory=options=>new Pool(options),
  readMigrationSource=version=>readFile(resolve(import.meta.dirname,
    '../supabase/migrations',version+'.sql'),'utf8'),
}={}) {
  if(!approved||!caFile)throw Error('EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED');
  const source=await readMigrationSource(profileEntryDraftVersion);
  const sourceHash=verifyProfileEntryDraftMigrationSource(source);
  for(const [version,expectedHash] of profileEntryDraftPrerequisites) {
    const priorSource=await readMigrationSource(version);
    const actualHash=createHash('sha256').update(priorSource).digest('hex');
    if(actualHash!==expectedHash)throw Error('PREREQUISITE_SOURCE_CHECKSUM_MISMATCH');
  }

  const rawUrl=process.env.JOBIX_DEV_DATABASE_URL;
  if(!rawUrl)throw Error('DEV_TARGET_REJECTED');
  const uri=new URL(rawUrl);
  if(!['postgres:','postgresql:'].includes(uri.protocol)||
    !uri.username.endsWith('.'+ref)||
    uri.username.length<=ref.length+1||!uri.password||
    !uri.hostname.endsWith('.pooler.supabase.com')||
    uri.pathname!='/postgres'||uri.port!=='5432'||uri.hash||
    [...uri.searchParams.keys()].some(key=>
      !['sslmode','sslrootcert','sslcert','sslkey'].includes(key))) {
    throw Error('DEV_TARGET_REJECTED');
  }
  for(const key of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(key);
  const ca=await readFile(caFile,'utf8');
  if(!ca.trimStart().startsWith('-----BEGIN CERTIFICATE-----')||
    !ca.includes('-----END CERTIFICATE-----'))throw Error('DEV_CA_FILE_INVALID');

  const configuredRole=uri.username.slice(0,-ref.length-1);
  const pool=poolFactory({connectionString:uri.toString(),max:1,options:'',
    connectionTimeoutMillis:15000,
    ssl:{rejectUnauthorized:true,ca},statement_timeout:30000});
  let client,transactionOpen=false,commitStarted=false;
  try {
    client=await pool.connect();
    await client.query('BEGIN');
    transactionOpen=true;
    await client.query("SET LOCAL lock_timeout='1s'");
    await client.query('SET LOCAL statement_timeout=30000');
    // This does not bypass RLS. It makes a filtered preflight query fail
    // instead of silently reporting an incomplete aggregate.
    await client.query('SET LOCAL row_security=off');
    const advisory=(await client.query(
      "SELECT pg_try_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations')) AS acquired",
    )).rows[0];
    if(advisory?.acquired!==true)throw Error('MIGRATION_LOCK_BUSY');

    const identity=(await client.query(`SELECT current_database() AS database,
      current_user AS role,session_user AS session_role,
      r.rolcanlogin,r.rolsuper,r.rolbypassrls,
      r.rolcreaterole,r.rolcreatedb,
      NOT EXISTS(SELECT 1 FROM pg_roles elevated
        WHERE elevated.oid<>r.oid AND
          (elevated.rolsuper OR elevated.rolbypassrls OR elevated.rolcreaterole OR
           elevated.rolcreatedb OR elevated.rolname IN
            ('postgres','supabase_admin','service_role','authenticator',
             'supabase_auth_admin','supabase_storage_admin'))
          AND pg_has_role(r.oid,elevated.oid,'MEMBER')) AS no_admin_membership
      FROM pg_roles r WHERE r.rolname=current_user`)).rows[0];
    if(identity?.database!=='postgres'||identity.role!==configuredRole||
      identity.session_role!==configuredRole) {
      throw Error('DEV_TARGET_IDENTITY_MISMATCH');
    }
    if(identity.rolcanlogin!==true||identity.rolsuper!==false||
      identity.rolbypassrls!==false||identity.rolcreaterole!==false||
      identity.rolcreatedb!==false||identity.no_admin_membership!==true||
      /^(postgres|anon|authenticated|service_role|authenticator)$/.test(identity.role)||
      identity.role.startsWith('supabase_')||
      identity.role.startsWith('jobix_export_')) {
      throw Error('MIGRATION_IDENTITY_UNSAFE');
    }

    const relations=(await client.query(`SELECT
      ${profileEntryDraftPrerequisiteRelations.map((name,index)=>
        `to_regclass('public.${name}') IS NOT NULL AS relation_${index}`).join(',\n      ')},
      to_regrole('authenticated') IS NOT NULL AS authenticated_role,
      to_regrole('anon') IS NOT NULL AS anon_role,
      to_regrole('service_role') IS NOT NULL AS service_role`)).rows[0];
    if(!relations||Object.values(relations).some(value=>value!==true)) {
      throw Error('MIGRATION_024_PREREQUISITE_SCHEMA_MISSING');
    }

    const requiredColumns=[
      ['users','id'],['users','status'],
      ['career_profiles','id'],['career_profiles','user_id'],
      ['career_profiles','status'],['career_profiles','profile_version'],
      ['career_profiles','target_role'],['career_profiles','completeness_percent'],
      ['career_profiles','completeness_algorithm_version'],['career_profiles','updated_at'],
      ['profile_personal_data','profile_id'],['profile_personal_data','full_name'],
      ['profile_personal_data','email'],['profile_personal_data','phone'],
      ['profile_summaries','profile_id'],['profile_summaries','text'],
      ['idempotency_records','user_id'],['idempotency_records','operation_type'],
      ['idempotency_records','idempotency_key'],['idempotency_records','payload_hash'],
      ['idempotency_records','response_state'],
      ['profile_experiences','id'],['profile_experiences','profile_id'],
      ['profile_experiences','job_title'],['profile_experiences','company'],
      ['profile_experiences','start_month'],['profile_experiences','end_month'],
      ['profile_experiences','is_current'],['profile_experiences','description'],
      ['profile_experiences','sort_order'],['profile_experiences','version'],
      ['profile_experiences','updated_at'],
      ['profile_education','id'],['profile_education','profile_id'],
      ['profile_education','degree'],['profile_education','institution'],
      ['profile_education','field_of_study'],['profile_education','start_month'],
      ['profile_education','end_month'],['profile_education','is_current'],
      ['profile_education','description'],['profile_education','sort_order'],
      ['profile_education','version'],['profile_education','updated_at'],
      ['profile_certifications','id'],['profile_certifications','profile_id'],
      ['profile_certifications','name'],['profile_certifications','issuer'],
      ['profile_certifications','issue_month'],['profile_certifications','sort_order'],
      ['profile_certifications','version'],['profile_certifications','updated_at'],
      ['profile_achievements','id'],['profile_achievements','profile_id'],
      ['profile_achievements','title'],['profile_achievements','issuer'],
      ['profile_achievements','achieved_month'],['profile_achievements','description'],
      ['profile_achievements','sort_order'],['profile_achievements','version'],
      ['profile_achievements','updated_at'],
      ['profile_projects','id'],['profile_projects','profile_id'],
      ['profile_projects','name'],['profile_projects','role'],
      ['profile_projects','project_month'],['profile_projects','description'],
      ['profile_projects','sort_order'],['profile_projects','version'],
      ['profile_projects','updated_at'],
      ['profile_skills','id'],['profile_skills','profile_id'],
      ['profile_skills','name'],['profile_skills','sort_order'],
      ['profile_skills','version'],['profile_skills','updated_at'],
      ['profile_languages','id'],['profile_languages','profile_id'],
      ['profile_languages','name'],['profile_languages','proficiency'],
      ['profile_languages','sort_order'],['profile_languages','version'],
      ['profile_languages','updated_at'],
      ['profile_volunteer_experiences','id'],['profile_volunteer_experiences','profile_id'],
      ['profile_volunteer_experiences','organization'],['profile_volunteer_experiences','role'],
      ['profile_volunteer_experiences','location'],
      ['profile_volunteer_experiences','start_month'],['profile_volunteer_experiences','end_month'],
      ['profile_volunteer_experiences','is_current'],
      ['profile_volunteer_experiences','description'],
      ['profile_volunteer_experiences','sort_order'],
      ['profile_volunteer_experiences','version'],
      ['profile_volunteer_experiences','updated_at'],
    ];
    const missingColumns=(await client.query(`SELECT expected.table_name,expected.column_name
      FROM unnest($1::text[],$2::text[]) AS expected(table_name,column_name)
      WHERE NOT EXISTS(SELECT 1 FROM information_schema.columns c
        WHERE c.table_schema='public' AND c.table_name=expected.table_name
          AND c.column_name=expected.column_name)`,
    [requiredColumns.map(pair=>pair[0]),requiredColumns.map(pair=>pair[1])])).rows;
    if(missingColumns.length)throw Error('MIGRATION_024_PREREQUISITE_SCHEMA_MISSING');

    const missingFunctions=(await client.query(`SELECT expected.signature
      FROM unnest($1::text[]) AS expected(signature)
      WHERE to_regprocedure(expected.signature) IS NULL`,
    [profileEntryDraftPrerequisiteFunctions])).rows;
    if(missingFunctions.length)throw Error('MIGRATION_024_PREREQUISITE_SCHEMA_MISSING');

    const ledger=await readProfileEntryDraftLedger(client);
    const alreadyApplied=verifyProfileEntryDraftLedger(ledger);
    if(alreadyApplied) {
      await assertProfileEntryDraftPostState(client,sourceHash);
      commitStarted=true;
      await client.query('COMMIT');
      transactionOpen=false;
      return 'already-applied';
    }

    const initialSchema=await readProfileEntryDraftSchemaState(client);
    if(!isProfileEntryDraftSchemaAbsent(initialSchema)) {
      throw Error('MIGRATION_024_SCHEMA_CONFLICT');
    }

    const permissionState=(await client.query(`SELECT
      has_schema_privilege(current_user,'public','USAGE') AS schema_usage,
      has_schema_privilege(current_user,'public','CREATE') AS schema_create,
      has_table_privilege(current_user,'public.jobix_export_migrations','SELECT')
        AND has_table_privilege(current_user,'public.jobix_export_migrations','INSERT')
        AS ledger_permissions,
      has_table_privilege(current_user,'public.users','SELECT')
        AND has_table_privilege(current_user,'public.users','UPDATE') AS users_permissions,
      has_table_privilege(current_user,'public.career_profiles','SELECT')
        AND has_table_privilege(current_user,'public.career_profiles','UPDATE')
        AS profile_permissions,
      has_table_privilege(current_user,'public.profile_personal_data','SELECT')
        AS personal_data_select,
      has_table_privilege(current_user,'public.profile_summaries','SELECT')
        AS summary_select,
      has_table_privilege(current_user,'public.idempotency_records','SELECT')
        AND has_table_privilege(current_user,'public.idempotency_records','INSERT')
        AND has_table_privilege(current_user,'public.idempotency_records','UPDATE')
        AS idempotency_permissions,
      has_table_privilege(current_user,'public.export_jobs','SELECT')
        AND has_table_privilege(current_user,'public.export_upload_flights','SELECT')
        AND has_table_privilege(current_user,'public.export_cost_reservations','SELECT')
        AS export_read_permissions,
      has_table_privilege(current_user,'public.profile_experiences','SELECT')
        AND has_table_privilege(current_user,'public.profile_experiences','UPDATE')
        AND has_table_privilege(current_user,'public.profile_education','SELECT')
        AND has_table_privilege(current_user,'public.profile_education','UPDATE')
        AND has_table_privilege(current_user,'public.profile_certifications','SELECT')
        AND has_table_privilege(current_user,'public.profile_certifications','UPDATE')
        AND has_table_privilege(current_user,'public.profile_achievements','SELECT')
        AND has_table_privilege(current_user,'public.profile_achievements','UPDATE')
        AND has_table_privilege(current_user,'public.profile_projects','SELECT')
        AND has_table_privilege(current_user,'public.profile_projects','UPDATE')
        AND has_table_privilege(current_user,'public.profile_skills','SELECT')
        AND has_table_privilege(current_user,'public.profile_skills','INSERT')
        AND has_table_privilege(current_user,'public.profile_skills','UPDATE')
        AND has_table_privilege(current_user,'public.profile_languages','SELECT')
        AND has_table_privilege(current_user,'public.profile_languages','INSERT')
        AND has_table_privilege(current_user,'public.profile_languages','UPDATE')
        AND has_table_privilege(current_user,'public.profile_volunteer_experiences','SELECT')
        AND has_table_privilege(current_user,'public.profile_volunteer_experiences','INSERT')
        AND has_table_privilege(current_user,'public.profile_volunteer_experiences','UPDATE')
        AS profile_entry_permissions,
      has_function_privilege(current_user,'auth.uid()','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_meaningful(text,integer)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_text_field(jsonb,text,integer)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_month_field(jsonb,text)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_bool_field(jsonb,text)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_next_order(text,uuid)','EXECUTE')
        AND has_function_privilege(current_user,'public.profile_mutate(uuid,uuid,bigint,jsonb)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_profile_mutate_base(uuid,uuid,bigint,jsonb)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_recompute_text_profile(uuid)','EXECUTE')
        AND has_function_privilege(current_user,'public.jobix_profile_text_snapshot(uuid)','EXECUTE')
        AS required_function_execute,
      (SELECT count(*)::int FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname=ANY($1::text[])
          AND c.relkind IN ('r','p') AND c.relforcerowsecurity)=0
        AS definer_rls_compatible`,
    [['users','career_profiles','profile_personal_data','profile_summaries',
      'idempotency_records',...profileEntryDraftTables]])).rows[0];
    if(!permissionState||Object.values(permissionState).some(value=>value!==true)) {
      throw Error('MIGRATION_024_REQUIRED_PRIVILEGES_MISSING');
    }

    const ownershipFailures=(await client.query(`SELECT 'table:'||c.relname AS object_name
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY($1::text[])
        AND c.relowner<>(SELECT oid FROM pg_roles WHERE rolname=current_user)
      UNION ALL
      SELECT 'function:'||expected.signature
      FROM unnest($2::text[]) AS expected(signature)
      JOIN pg_proc p ON p.oid=to_regprocedure(expected.signature)
      WHERE p.proowner<>(SELECT oid FROM pg_roles WHERE rolname=current_user)`,
    [profileEntryDraftTables,profileEntryDraftOwnedFunctions])).rows;
    if(ownershipFailures.length)throw Error('MIGRATION_024_OWNERSHIP_MISMATCH');

    await client.query(`LOCK TABLE ${profileEntryDraftTables.map(name=>
      `public.${name}`).join(', ')} IN ACCESS EXCLUSIVE MODE NOWAIT`);
    await client.query(`LOCK TABLE public.export_jobs,public.export_upload_flights,
      public.export_cost_reservations IN SHARE ROW EXCLUSIVE MODE NOWAIT`);
    await client.query(
      'LOCK TABLE public.jobix_export_migrations IN SHARE ROW EXCLUSIVE MODE NOWAIT',
    );

    const lockedSchema=await readProfileEntryDraftSchemaState(client);
    if(!isProfileEntryDraftSchemaAbsent(lockedSchema)) {
      throw Error('MIGRATION_024_SCHEMA_CONFLICT');
    }
    if(verifyProfileEntryDraftLedger(await readProfileEntryDraftLedger(client))) {
      throw Error('MIGRATION_024_LEDGER_CHANGED');
    }

    // Match 024's Complete-save structural requirements, not the separate
    // completeness/scoring thresholds (which also consider description length).
    const incompleteRows=(await client.query(`SELECT
      (SELECT count(*)::bigint FROM public.profile_experiences e
        WHERE nullif(btrim(e.job_title),'') IS NULL
          OR nullif(btrim(e.company),'') IS NULL OR e.start_month IS NULL
          OR (NOT e.is_current AND e.end_month IS NULL)) AS experience,
      (SELECT count(*)::bigint FROM public.profile_education e
        WHERE nullif(btrim(e.degree),'') IS NULL
          OR nullif(btrim(e.institution),'') IS NULL
          OR nullif(btrim(e.field_of_study),'') IS NULL OR e.start_month IS NULL
          OR (NOT e.is_current AND e.end_month IS NULL)) AS education,
      (SELECT count(*)::bigint FROM public.profile_certifications e
        WHERE nullif(btrim(e.name),'') IS NULL
          OR nullif(btrim(e.issuer),'') IS NULL
          OR e.issue_month IS NULL)
        AS certification,
      (SELECT count(*)::bigint FROM public.profile_achievements e
        WHERE nullif(btrim(e.title),'') IS NULL
          OR nullif(btrim(e.issuer),'') IS NULL OR e.achieved_month IS NULL)
        AS achievement,
      (SELECT count(*)::bigint FROM public.profile_projects e
        WHERE nullif(btrim(e.name),'') IS NULL
          OR nullif(btrim(e.role),'') IS NULL OR e.project_month IS NULL) AS project,
      (SELECT count(*)::bigint FROM public.profile_skills e
        WHERE nullif(btrim(e.name),'') IS NULL) AS skill,
      (SELECT count(*)::bigint FROM public.profile_languages e
        WHERE nullif(btrim(e.name),'') IS NULL
          OR e.proficiency IS NULL) AS language,
      (SELECT count(*)::bigint FROM public.profile_volunteer_experiences e
        WHERE nullif(btrim(e.organization),'') IS NULL
          OR nullif(btrim(e.role),'') IS NULL
          OR e.start_month IS NULL
          OR (e.is_current AND e.end_month IS NOT NULL)
          OR (NOT e.is_current AND
            (e.end_month IS NULL OR e.end_month<e.start_month))) AS volunteer
    `)).rows[0];
    if(!incompleteRows||Object.values(incompleteRows).some(value=>BigInt(value)>0n)) {
      throw Error('MIGRATION_024_LEGACY_INCOMPLETE_ROWS_PRESENT');
    }

    const activeJobs=(await client.query(`SELECT count(*)::bigint AS count
      FROM public.export_jobs
      WHERE state=ANY($1::text[])`,
    [['QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE',
      'DELETION_PENDING']])).rows[0]?.count;
    const unsettledUploads=(await client.query(`SELECT count(*)::bigint AS count
      FROM public.export_upload_flights WHERE state<>'SETTLED'`)).rows[0]?.count;
    const heldReservations=(await client.query(`SELECT count(*)::bigint AS count
      FROM public.export_cost_reservations WHERE state='HELD'`)).rows[0]?.count;
    if(activeJobs==null||unsettledUploads==null||heldReservations==null||
      BigInt(activeJobs)>0n||BigInt(unsettledUploads)>0n||BigInt(heldReservations)>0n) {
      throw Error('MIGRATION_024_ACTIVE_WORK_PRESENT');
    }

    const body=source.replace(/^BEGIN;\s*$/m,'').replace(/^COMMIT;\s*$/m,'');
    await client.query(body);
    await client.query(
      'INSERT INTO public.jobix_export_migrations(version,sha256) VALUES($1,$2)',
      [profileEntryDraftVersion,sourceHash],
    );
    await assertProfileEntryDraftPostState(client,sourceHash);
    commitStarted=true;
    await client.query('COMMIT');
    transactionOpen=false;
    return 'applied';
  } catch(error) {
    if(client&&transactionOpen)await client.query('ROLLBACK').catch(()=>{});
    if(commitStarted)throw Error('MIGRATION_COMMIT_OUTCOME_UNKNOWN');
    if(error?.code==='55P03'||error?.code==='40P01') {
      throw Error('MIGRATION_LOCK_CONTENTION');
    }
    throw error;
  } finally {
    // Cleanup must not replace a failure (especially an unknown COMMIT outcome).
    try { client?.release(); } catch {}
    try { await pool.end(); } catch {}
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
  const profileEntryDraftMode=process.argv.includes('--apply-development-profile-entry-drafts-024');
  const legacyMode=process.argv.includes('--apply-development');
  const profileDraftArgs=process.argv.slice(2);
  const safeCostFailures=new Set([
    'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED','DEV_TARGET_REJECTED',
    'BASELINE_SCHEMA_DRIFT','MIGRATION_LEDGER_STATE_CONFLICT',
    'MIGRATION_CHECKSUM_CONFLICT','EXPORT_GATES_NOT_EXPECTED',
    'MIGRATION_OBJECT_CONFLICT','ACTIVE_EXPORT_JOBS_PRESENT',
    'EXPORT_GATES_CHANGED','ACCOUNTING_CONFIGURATION_NOT_READY',
    'COST_OUTPUT_UNIT_PRECONDITION_FAILED',
  ]);
  if(profileEntryDraftMode&&
    (resumeLayoutMode||costMode||costOutputUnitMode||legacyMode)) {
    console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_AMBIGUOUS_MODE');process.exitCode=1;
  } else if(resumeLayoutMode&&(costMode||costOutputUnitMode||legacyMode)) {
    console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_AMBIGUOUS_MODE');process.exitCode=1;
  } else if((costMode&&legacyMode)||(costOutputUnitMode&&(costMode||legacyMode))) {
    console.error('DEVELOPMENT_MIGRATIONS_BLOCKED_AMBIGUOUS_MODE');process.exitCode=1;
  } else if(profileEntryDraftMode) {
    const modeFlags=profileDraftArgs.filter(argument=>argument.startsWith('--apply-'));
    const caFlags=profileDraftArgs.filter(argument=>argument==='--ca-file');
    const caIndex=profileDraftArgs.indexOf('--ca-file');
    if(profileDraftArgs.length!==3||modeFlags.length!==1||
      modeFlags[0]!=='--apply-development-profile-entry-drafts-024'||
      caFlags.length!==1||caIndex<0||!profileDraftArgs[caIndex+1]||
      profileDraftArgs[caIndex+1].startsWith('--')) {
      console.error('DEVELOPMENT_PROFILE_ENTRY_DRAFTS_024_BLOCKED_AMBIGUOUS_MODE');
      process.exitCode=1;
    } else {
      migrateProfileEntryDrafts({caFile:profileDraftArgs[caIndex+1],approved:true})
        .then(result=>console.log(result==='applied'
          ?'DEVELOPMENT_MIGRATION_024_APPLIED_PROFILE_ENTRY_DRAFTS'
          :'DEVELOPMENT_MIGRATION_024_ALREADY_APPLIED_VERIFIED'))
        .catch(error=>{
          const safeFailures=new Set([
            'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED','DEV_TARGET_REJECTED',
            'DEV_TARGET_IDENTITY_MISMATCH','DEV_CA_FILE_INVALID',
            'MIGRATION_SOURCE_CHECKSUM_MISMATCH',
            'PREREQUISITE_SOURCE_CHECKSUM_MISMATCH',
            'MIGRATION_IDENTITY_UNSAFE','MIGRATION_LOCK_BUSY',
            'MIGRATION_LOCK_CONTENTION','MIGRATION_024_PREREQUISITE_SCHEMA_MISSING',
            'MIGRATION_LEDGER_STATE_CONFLICT','MIGRATION_CHECKSUM_CONFLICT',
            'MIGRATION_024_SCHEMA_CONFLICT','MIGRATION_024_OWNERSHIP_MISMATCH',
            'MIGRATION_024_REQUIRED_PRIVILEGES_MISSING',
            'MIGRATION_024_LEGACY_INCOMPLETE_ROWS_PRESENT',
            'MIGRATION_024_ACTIVE_WORK_PRESENT','MIGRATION_024_LEDGER_CHANGED',
            'MIGRATION_024_SCHEMA_NOT_COMPLETE',
            'MIGRATION_024_POST_ASSERTION_FAILED',
            'MIGRATION_COMMIT_OUTCOME_UNKNOWN',
          ]);
          const reason=safeFailures.has(error?.message)
            ?error.message:'NO_TLS_OR_ADMIN_FALLBACK';
          console.error(`DEVELOPMENT_PROFILE_ENTRY_DRAFTS_024_BLOCKED_${reason}`);
          process.exitCode=1;
        });
    }
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
