import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {mkdtemp,readFile,rm,writeFile} from 'node:fs/promises';
import os from 'node:os';
import {join} from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';
import {
  migrate,
  migrateEducationCatalog,
  migrateProfileEntryDrafts,
  migrateResumeExportCost,
  migrateResumeLayout,
  verifyProfileEntryDraftMigrationSource,
  verifyEducationCatalogMigrationSource,
  verifyResumeLayoutMigrationSource,
} from './apply_phase3_dev.mjs';

const versions=[
  '202610080012_resume_export_foundation',
  '202610080013_resume_export_lifecycle',
  '202610080014_resume_configuration_concurrency',
  '202610080015_resume_export_local_hardening',
  '202610080016_resume_export_cleanup_hooks',
  '202610080017_resume_export_deletion',
  '202610080018_resume_export_admission',
  '202610100019_resume_export_cost_protection',
  '202610100020_resume_export_cost_purge_recovery',
  '202610100021_resume_export_cost_output_unit',
];
const migrationPath=new URL('../supabase/migrations/202610170022_resume_layout.sql',import.meta.url);
const reviewedHash='d34f6dad4d9edcd301486d9d507bed7330c0fde66cfac3630bee087fa8366473';
const profileEntryDraftVersion='202610200024_persisted_profile_entry_drafts';
const reviewedDraftHash='f246e45dce62c0d03457fe825ab2db14b687f32a92661572867e2fa1a5a48af6';

async function fixture({
  target='postgres.lmouxhbjhtqdtiqijcee@aws-0-me-central1.pooler.supabase.com',
  database='postgres',missingPrerequisite=null,existingFunction=false,
  ownerPrivilegeFailure=false,ledgerMismatch=null,failAt=null,
}={}) {
  const dir=await mkdtemp(join(os.tmpdir(),'jobix-migration-022-'));
  const caFile=join(dir,'development-ca.pem');
  await writeFile(caFile,'synthetic-test-ca');
  const originalUrl=process.env.JOBIX_DEV_DATABASE_URL;
  process.env.JOBIX_DEV_DATABASE_URL=`postgresql://${target}:5432/postgres`;
  const state={queries:[],migrationCount:0,ledgerInsertCount:0,committed:false,rolledBack:false};
  const poolFactory=options=>{
    state.poolOptions=options;
    return {
      async connect() {
        return {
          async query(sql,params) {
            state.queries.push({sql,params});
            if(sql==='BEGIN')return {rows:[]};
            if(sql.includes('pg_advisory_xact_lock'))return {rows:[]};
            if(sql.includes('current_database() AS database')) {
              return {rows:[{database,role:'postgres'}]};
            }
            if(sql.includes('p.proowner=')) {
              return {rows:[{
                owner_matches:true,security_definer:true,
                authenticated_execute:true,anon_execute:false,service_execute:false,
              }]};
            }
            if(sql.includes('to_regprocedure')&&sql.includes('save_resume_layout')) {
              return {rows:[{
                ledger:true,users:true,profiles:true,
                configurations:missingPrerequisite!=='configurations',
                idempotency:true,read_configuration:true,
                save_layout:existingFunction,
                authenticated_role:true,anon_role:true,service_role:true,
              }]};
            }
            if(sql.includes('information_schema.columns'))return {rows:[]};
            if(sql.includes('has_schema_privilege')) {
              return {rows:[{
                role:'postgres',schema_create:true,users_select:true,users_update:true,
                profiles_select:true,profiles_update:true,configurations_select:true,
                configurations_insert:true,configurations_update:true,
                idempotency_select:true,idempotency_insert:true,
                read_rpc_execute:!ownerPrivilegeFailure,
                rls_owner_access:!ownerPrivilegeFailure,
              }]};
            }
            if(sql.includes('SELECT version,sha256 FROM public.jobix_export_migrations')) {
              const rows=[];
              for(const version of versions) {
                const source=await readFile(new URL(
                  `../supabase/migrations/${version}.sql`,import.meta.url),'utf8');
                rows.push({version,sha256:createHash('sha256').update(source).digest('hex')});
              }
              if(ledgerMismatch==='checksum')rows[rows.length-1].sha256='0'.repeat(64);
              if(ledgerMismatch==='version')rows[0].version='unexpected-version';
              return {rows};
            }
            if(sql.includes('CREATE FUNCTION public.save_resume_layout')) {
              state.migrationCount++;
              if(failAt==='migration')throw Error('synthetic migration failure');
              return {rows:[]};
            }
            if(sql.startsWith('INSERT INTO public.jobix_export_migrations')) {
              state.ledgerInsertCount++;
              if(failAt==='ledger')throw Error('synthetic ledger failure');
              return {rows:[]};
            }
            if(sql.includes('SELECT sha256 FROM public.jobix_export_migrations')) {
              return {rows:[{sha256:reviewedHash}]};
            }
            if(sql==='COMMIT') {
              if(failAt==='commit')throw Error('synthetic commit failure');
              state.committed=true;
              return {rows:[]};
            }
            if(sql==='ROLLBACK') {
              state.rolledBack=true;
              return {rows:[]};
            }
            throw Error(`Unexpected mock query: ${sql.slice(0,80)}`);
          },
          release() { state.released=true; },
        };
      },
      async end() { state.ended=true; },
    };
  };
  return {
    caFile,state,poolFactory,
    restore:async()=>{
      if(originalUrl===undefined)delete process.env.JOBIX_DEV_DATABASE_URL;
      else process.env.JOBIX_DEV_DATABASE_URL=originalUrl;
      await rm(dir,{recursive:true,force:true});
    },
  };
}

async function withFixture(options,fn) {
  const f=await fixture(options);
  try { await fn(f); } finally { await f.restore(); }
}

test('Migration 022 pins the reviewed source SHA-256',async()=>{
  const source=await readFile(migrationPath,'utf8');
  assert.equal(verifyResumeLayoutMigrationSource(source),reviewedHash);
});

test('wrong target is rejected before creating a connection pool',async()=>{
  await withFixture({
    target:'postgres.otherproject@aws-0-me-central1.pooler.supabase.com',
  },async f=>{
    let poolCreated=false;
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,
        poolFactory:()=>{poolCreated=true;throw Error('must not connect');}}),
      {message:'DEV_TARGET_REJECTED'},
    );
    assert.equal(poolCreated,false);
  });
});

test('supported Development target applies and commits under verified TLS',async()=>{
  await withFixture({},async f=>{
    const source=await readFile(migrationPath,'utf8');
    assert.equal(verifyResumeLayoutMigrationSource(source),reviewedHash);
    await migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory});
    assert.equal(f.state.poolOptions.ssl.rejectUnauthorized,true);
    assert.equal(f.state.poolOptions.ssl.ca,'synthetic-test-ca');
    assert.ok(f.state.queries.some(({sql})=>sql.includes(
      "hashtext('jobix_phase3_dev_migrations')")));
    assert.equal(f.state.migrationCount,1);
    assert.equal(f.state.ledgerInsertCount,1);
    assert.equal(f.state.committed,true);
    assert.equal(f.state.rolledBack,false);
  });
});

test('source checksum mismatch fails closed',async()=>{
  const source=await readFile(migrationPath,'utf8');
  assert.throws(
    ()=>verifyResumeLayoutMigrationSource(`${source}\n-- changed`),
    {message:'MIGRATION_SOURCE_CHECKSUM_MISMATCH'},
  );
});

test('missing schema prerequisite aborts before migration SQL',async()=>{
  await withFixture({missingPrerequisite:'configurations'},async f=>{
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory}),
      {message:'LAYOUT_BASELINE_SCHEMA_DRIFT'},
    );
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('insufficient function-owner privileges abort before migration SQL',async()=>{
  await withFixture({ownerPrivilegeFailure:true},async f=>{
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory}),
      {message:'LAYOUT_FUNCTION_OWNER_PRIVILEGES_INSUFFICIENT'},
    );
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('existing exact save_resume_layout signature aborts before migration SQL',async()=>{
  await withFixture({existingFunction:true},async f=>{
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory}),
      {message:'LAYOUT_FUNCTION_ALREADY_EXISTS'},
    );
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('ledger checksum mismatch aborts before migration SQL',async()=>{
  await withFixture({ledgerMismatch:'checksum'},async f=>{
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory}),
      {message:'MIGRATION_CHECKSUM_CONFLICT'},
    );
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('ledger version mismatch aborts before migration SQL',async()=>{
  await withFixture({ledgerMismatch:'version'},async f=>{
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory}),
      {message:'MIGRATION_LEDGER_STATE_CONFLICT'},
    );
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('transaction failure rolls back migration and ledger together',async()=>{
  await withFixture({failAt:'ledger'},async f=>{
    await assert.rejects(
      migrateResumeLayout({approved:true,caFile:f.caFile,poolFactory:f.poolFactory}),
      /synthetic ledger failure/,
    );
    assert.equal(f.state.migrationCount,1);
    assert.equal(f.state.ledgerInsertCount,1);
    assert.equal(f.state.committed,false);
    assert.equal(f.state.rolledBack,true);
  });
});

const draftVersions=[
  '202610080012_resume_export_foundation',
  '202610080013_resume_export_lifecycle',
  '202610080014_resume_configuration_concurrency',
  '202610080015_resume_export_local_hardening',
  '202610080016_resume_export_cleanup_hooks',
  '202610080017_resume_export_deletion',
  '202610080018_resume_export_admission',
  '202610100019_resume_export_cost_protection',
  '202610100020_resume_export_cost_purge_recovery',
  '202610100021_resume_export_cost_output_unit',
  '202610170022_resume_layout',
  '202610190023_education_catalog',
];
const syntheticCa='-----BEGIN CERTIFICATE-----\nlocal-test-only\n-----END CERTIFICATE-----\n';

async function draftFixture({
  target=null,
  database='postgres',role='jobix_migration_owner',sessionRole=null,
  unsafeRole=false,adminMembership=false,urlQuery='',withoutPassword=false,
  missingRelation=false,missingFunction=false,missingColumn=false,
  schemaState='absent',ownerFailure=false,permissionFailure=false,
  ledgerState='prior',ledgerMismatch=null,legacyIncomplete=false,
  activeWork=false,unsettledUpload=false,heldReservation=false,
  lockBusy=false,tableLockBusy=false,failAt=null,
  postAssertionFailure=false,
}={}) {
  const dir=await mkdtemp(join(os.tmpdir(),'jobix-migration-024-'));
  const caFile=join(dir,'development-ca.pem');
  await writeFile(caFile,syntheticCa);
  const originalUrl=process.env.JOBIX_DEV_DATABASE_URL;
  const connectionTarget=target??
    `${role}.lmouxhbjhtqdtiqijcee@aws-0-me-central1.pooler.supabase.com`;
  const credentialTarget=withoutPassword?connectionTarget:
    connectionTarget.replace('@',':synthetic-password@');
  process.env.JOBIX_DEV_DATABASE_URL=
    `postgresql://${credentialTarget}:5432/postgres${urlQuery}`;
  const state={
    queries:[],migrationCount:0,ledgerInsertCount:0,committed:false,
    rolledBack:false,schema:'absent',ledger024:false,
  };
  const poolFactory=options=>{
    state.poolOptions=options;
    return {
      async connect() {
        return {
          async query(sql,params) {
            state.queries.push({sql,params});
            if(sql==='BEGIN'||sql.startsWith('SET LOCAL')||sql.startsWith('LOCK TABLE')) {
              if(sql.startsWith('LOCK TABLE')&&tableLockBusy) {
                const error=Error('synthetic lock busy');error.code='55P03';throw error;
              }
              return {rows:[]};
            }
            if(sql.includes('pg_try_advisory_xact_lock')) {
              return {rows:[{acquired:!lockBusy}]};
            }
            if(sql.includes('current_database() AS database')) {
              return {rows:[{
                database,role,session_role:sessionRole??role,rolcanlogin:true,
                rolsuper:unsafeRole,rolbypassrls:false,rolcreaterole:false,
                rolcreatedb:false,no_admin_membership:!adminMembership,
              }]};
            }
            if(sql.includes("to_regclass('public.jobix_export_migrations')")) {
              const result={};
              for(const match of sql.matchAll(/AS relation_(\d+)/g)) {
                const index=Number(match[1]);
                result[`relation_${index}`]=!(missingRelation&&index===1);
              }
              Object.assign(result,{
                authenticated_role:true,anon_role:true,service_role:true,
              });
              return {rows:[result]};
            }
            if(sql.includes('information_schema.columns')) {
              return {rows:missingColumn?[{table_name:'profile_skills',column_name:'name'}]:[]};
            }
            if(sql.includes('FROM unnest($1::text[]) AS expected(signature)')&&
              sql.includes('to_regprocedure(expected.signature)')) {
              return {rows:missingFunction?[{signature:'public.profile_mutate(uuid,uuid,bigint,jsonb)'}]:[]};
            }
            if(sql.includes('draft_columns')) {
              const complete=schemaState==='complete'||state.schema==='complete';
              const partial=schemaState==='partial';
              return {rows:[{
                draft_columns:complete?8:partial?3:0,
                safe_draft_columns:complete?8:partial?2:0,
                draft_functions:complete?3:partial?1:0,
                draft_triggers:complete?8:partial?2:0,
                correct_draft_triggers:complete?8:partial?1:0,
                archived_snapshot:complete||partial,
                pre_volunteer_snapshot:true,current_snapshot:true,
                old_volunteer_constraint:!complete,
                draft_volunteer_constraint:complete,
                draft_volunteer_constraint_validated:complete,
                draft_volunteer_constraint_definition:complete
                  ?'CHECK (is_draft OR (organization IS NOT NULL AND role IS NOT NULL '+
                    'AND start_month IS NOT NULL AND ((is_current AND end_month IS NULL) '+
                    'OR (NOT is_current AND end_month IS NOT NULL AND end_month >= start_month))))'
                  :null,
                skill_name_not_null:!complete,
                language_name_not_null:!complete,
                language_proficiency_not_null:!complete,
              }]};
            }
            if(sql.includes('SELECT version,sha256 FROM public.jobix_export_migrations ORDER BY')) {
              const rows=[];
              for(const version of draftVersions) {
                const source=await readFile(new URL(
                  `../supabase/migrations/${version}.sql`,import.meta.url),'utf8');
                rows.push({version,sha256:createHash('sha256').update(source).digest('hex')});
              }
              if(ledgerMismatch==='prior')rows[rows.length-1].sha256='0'.repeat(64);
              if(ledgerMismatch==='version')rows[0].version='unexpected-version';
              if(ledgerState==='applied')rows.push({
                version:profileEntryDraftVersion,sha256:reviewedDraftHash,
              });
              if(ledgerState==='applied-mismatch')rows.push({
                version:profileEntryDraftVersion,sha256:'0'.repeat(64),
              });
              return {rows};
            }
            if(sql.includes('schema_usage')) {
              return {rows:[{
                schema_usage:!permissionFailure,schema_create:!permissionFailure,
                ledger_permissions:!permissionFailure,users_permissions:!permissionFailure,
                profile_permissions:!permissionFailure,personal_data_select:!permissionFailure,
                summary_select:!permissionFailure,idempotency_permissions:!permissionFailure,
                export_read_permissions:!permissionFailure,definer_rls_compatible:true,
                profile_entry_permissions:!permissionFailure,
                required_function_execute:!permissionFailure,
              }]};
            }
            if(sql.includes("'table:'||c.relname")) {
              return {rows:ownerFailure?[{object_name:'table:profile_skills'}]:[]};
            }
            if(sql.includes('AS experience,')&&sql.includes('AS volunteer')) {
              return {rows:[{
                experience:legacyIncomplete?'1':'0',education:'0',certification:'0',
                achievement:'0',project:'0',skill:'0',language:'0',volunteer:'0',
              }]};
            }
            if(sql.includes('FROM public.export_jobs')) {
              return {rows:[{count:activeWork?'1':'0'}]};
            }
            if(sql.includes('FROM public.export_upload_flights')) {
              return {rows:[{count:unsettledUpload?'1':'0'}]};
            }
            if(sql.includes('FROM public.export_cost_reservations')) {
              return {rows:[{count:heldReservation?'1':'0'}]};
            }
            if(sql.includes('CREATE FUNCTION public.save_profile_entry')) {
              state.migrationCount++;
              if(failAt==='migration')throw Error('synthetic migration SQL failure');
              state.schema='complete';
              return {rows:[]};
            }
            if(sql.startsWith('INSERT INTO public.jobix_export_migrations')) {
              state.ledgerInsertCount++;
              if(failAt==='ledger')throw Error('synthetic ledger insertion failure');
              state.ledger024=true;
              return {rows:[]};
            }
            if(sql.includes('save_is_function')) {
              if(postAssertionFailure)return {rows:[{
                save_is_function:true,save_security_definer:false,
                unsafe_save_owner:false,save_authenticated:true,save_anon:false,
                save_service:false,save_public_revoked:true,visible_secdef:true,
                snapshot_secdef:true,trigger_fn_invoker:true,
                visible_public_revoked:true,visible_client_revoked:true,
                snapshot_client_revoked:true,trigger_client_revoked:true,
                ledger_matches:true,
              }]};
              return {rows:[{
                save_is_function:true,save_security_definer:true,
                unsafe_save_owner:false,save_authenticated:true,save_anon:false,
                save_service:false,save_public_revoked:true,visible_secdef:true,
                snapshot_secdef:true,trigger_fn_invoker:true,
                visible_public_revoked:true,visible_client_revoked:true,
                snapshot_client_revoked:true,trigger_client_revoked:true,
                ledger_matches:true,
              }]};
            }
            if(sql==='COMMIT') {
              if(failAt==='commit')throw Error('synthetic connection loss during COMMIT');
              state.committed=true;
              return {rows:[]};
            }
            if(sql==='ROLLBACK') {
              state.rolledBack=true;
              state.schema='absent';
              state.ledger024=false;
              return {rows:[]};
            }
            throw Error(`Unexpected mocked Migration 024 query: ${sql.slice(0,100)}`);
          },
          release() { state.released=true; },
        };
      },
      async end() { state.ended=true; },
    };
  };
  return {
    caFile,state,poolFactory,
    restore:async()=>{
      if(originalUrl===undefined)delete process.env.JOBIX_DEV_DATABASE_URL;
      else process.env.JOBIX_DEV_DATABASE_URL=originalUrl;
      await rm(dir,{recursive:true,force:true});
    },
  };
}

async function withDraftFixture(options,fn) {
  const f=await draftFixture(options);
  try { await fn(f); } finally { await f.restore(); }
}

test('Migration 024 uses the independently reviewed pinned source checksum',async()=>{
  const source=await readFile(new URL(
    '../supabase/migrations/202610200024_persisted_profile_entry_drafts.sql',import.meta.url),
  'utf8');
  assert.equal(verifyProfileEntryDraftMigrationSource(source),reviewedDraftHash);
});

test('Migration 024 hash mismatch fails before creating a connection pool',async()=>{
  await withDraftFixture({},async f=>{
    let poolCreated=false;
    const source=await readFile(new URL(
      '../supabase/migrations/202610200024_persisted_profile_entry_drafts.sql',import.meta.url),
    'utf8');
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:()=>{poolCreated=true;},
      readMigrationSource:async version=>version===profileEntryDraftVersion
        ?`${source}\n-- synthetic modified source`:
        readFile(new URL(`../supabase/migrations/${version}.sql`,import.meta.url),'utf8'),
    }),{message:'MIGRATION_SOURCE_CHECKSUM_MISMATCH'});
    assert.equal(poolCreated,false);
  });
});

test('Production and unknown database targets are rejected before pool creation',async()=>{
  for(const target of [
    'postgres.otherproject@aws-0-me-central1.pooler.supabase.com',
    'postgres.lmouxhbjhtqdtiqijcee@db.example.invalid',
  ]) await withDraftFixture({target},async f=>{
    let poolCreated=false;
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,
      poolFactory:()=>{poolCreated=true;throw Error('pool must not be created');},
    }),{message:'DEV_TARGET_REJECTED'});
    assert.equal(poolCreated,false);
  });
});

test('unsafe execution identities and privileged role memberships are rejected',async()=>{
  for(const options of [{unsafeRole:true},{adminMembership:true},
    {role:'postgres'},{role:'jobix_export_runtime'}]) {
    await withDraftFixture(options,async f=>{
      await assert.rejects(migrateProfileEntryDrafts({
        approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      }),{message:'MIGRATION_IDENTITY_UNSAFE'});
      assert.equal(f.state.migrationCount,0);
      assert.equal(f.state.ledgerInsertCount,0);
      assert.equal(f.state.rolledBack,true);
    });
  }
});

test('missing prerequisite relations, columns, or functions abort before migration',async()=>{
  for(const options of [
    {missingRelation:true},{missingColumn:true},{missingFunction:true},
  ]) await withDraftFixture(options,async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_024_PREREQUISITE_SCHEMA_MISSING'});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
  });
});

test('ledger version and checksum conflicts abort without repair',async()=>{
  for(const ledgerMismatch of ['prior','version']) {
    await withDraftFixture({ledgerMismatch},async f=>{
      await assert.rejects(migrateProfileEntryDrafts({
        approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      }),ledgerMismatch==='prior'
        ?{message:'MIGRATION_CHECKSUM_CONFLICT'}
        :{message:'MIGRATION_LEDGER_STATE_CONFLICT'});
      assert.equal(f.state.migrationCount,0);
      assert.equal(f.state.ledgerInsertCount,0);
      assert.equal(f.state.rolledBack,true);
    });
  }
});

test('matching applied Migration 024 is verification-only and mismatched hash blocks',async()=>{
  await withDraftFixture({ledgerState:'applied',schemaState:'complete'},async f=>{
    const result=await migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    });
    assert.equal(result,'already-applied');
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.committed,true);
  });
  await withDraftFixture({ledgerState:'applied-mismatch',schemaState:'complete'},async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_CHECKSUM_CONFLICT'});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('conflicting or partially applied schema aborts without repair',async()=>{
  await withDraftFixture({schemaState:'partial'},async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_024_SCHEMA_CONFLICT'});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
  });
});

test('owner, privilege, legacy-data, active-work, and lock preflights fail closed',async()=>{
  const scenarios=[
    [{ownerFailure:true},'MIGRATION_024_OWNERSHIP_MISMATCH'],
    [{permissionFailure:true},'MIGRATION_024_REQUIRED_PRIVILEGES_MISSING'],
    [{legacyIncomplete:true},'MIGRATION_024_LEGACY_INCOMPLETE_ROWS_PRESENT'],
      [{activeWork:true},'MIGRATION_024_ACTIVE_WORK_PRESENT'],
      [{unsettledUpload:true},'MIGRATION_024_ACTIVE_WORK_PRESENT'],
      [{heldReservation:true},'MIGRATION_024_ACTIVE_WORK_PRESENT'],
      [{lockBusy:true},'MIGRATION_LOCK_BUSY'],
      [{tableLockBusy:true},'MIGRATION_LOCK_CONTENTION'],
  ];
  for(const [options,error] of scenarios) await withDraftFixture(options,async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:error});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.committed,false);
  });
});

test('Migration 024 SQL and ledger failures roll back the transaction',async()=>{
  await withDraftFixture({failAt:'migration'},async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),/synthetic migration SQL failure/);
    assert.equal(f.state.migrationCount,1);
    assert.equal(f.state.ledgerInsertCount,0);
    assert.equal(f.state.schema,'absent');
    assert.equal(f.state.ledger024,false);
    assert.equal(f.state.committed,false);
    assert.equal(f.state.rolledBack,true);
  });
  await withDraftFixture({failAt:'ledger'},async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),/synthetic ledger insertion failure/);
    assert.equal(f.state.migrationCount,1);
    assert.equal(f.state.ledgerInsertCount,1);
    assert.equal(f.state.schema,'absent');
    assert.equal(f.state.ledger024,false);
    assert.equal(f.state.committed,false);
    assert.equal(f.state.rolledBack,true);
  });
});

test('Migration 024 commit connection loss is reported as uncertain',async()=>{
  await withDraftFixture({failAt:'commit'},async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_COMMIT_OUTCOME_UNKNOWN'});
    assert.equal(f.state.committed,false);
    assert.equal(f.state.rolledBack,true);
  });
});

test('existing runner entry points still reject calls without explicit approval',async()=>{
  await assert.rejects(migrate({approved:false}),{
    message:'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED',
  });
  await assert.rejects(migrateResumeExportCost({approved:false}),{
    message:'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED',
  });
  await assert.rejects(migrateResumeLayout({approved:false}),{
    message:'EXPLICIT_DEV_APPROVAL_AND_CA_REQUIRED',
  });
});

test('Migration 024 supported path applies once with TLS and atomic ledger',async()=>{
  await withDraftFixture({},async f=>{
    assert.equal(await migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),'applied');
    assert.equal(f.state.poolOptions.ssl.rejectUnauthorized,true);
    assert.equal(f.state.poolOptions.max,1);
    assert.equal(f.state.poolOptions.options,'');
    assert.equal(f.state.migrationCount,1);
    assert.equal(f.state.ledgerInsertCount,1);
    assert.equal(f.state.committed,true);
    assert.equal(f.state.rolledBack,false);
    assert.ok(f.state.queries.some(q=>q.sql==='SET LOCAL row_security=off'));
    assert.ok(f.state.queries.some(q=>
      q.sql.includes("pg_try_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))")));
  });
});

test('Migration 024 failed postcondition rolls back without claiming success',async()=>{
  await withDraftFixture({postAssertionFailure:true},async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_024_POST_ASSERTION_FAILED'});
    assert.equal(f.state.committed,false);
    assert.equal(f.state.rolledBack,true);
    assert.equal(f.state.ledger024,false);
  });
});

test('Migration 024 CLI rejects mixed or ambiguous arguments without credentials',()=>{
  for(const args of [
    ['--apply-development-profile-entry-drafts-024','--apply-development'],
    ['--apply-development-profile-entry-drafts-024','--ca-file','unused','--extra'],
    ['--apply-development-profile-entry-drafts-024','--ca-file','--apply-unknown'],
  ]) {
    const result=spawnSync(process.execPath,[
      fileURLToPath(new URL('./apply_phase3_dev.mjs',import.meta.url)),...args,
    ],{encoding:'utf8',env:{},timeout:10000});
    assert.equal(result.status,1);
    assert.match(result.stderr,/BLOCKED_AMBIGUOUS_MODE/);
    assert.equal(result.stdout,'');
  }
});

test('Migration 024 rejects credential fallbacks and URL connection overrides',async()=>{
  for(const options of [
    {withoutPassword:true},{urlQuery:'?ssl=false'},
    {urlQuery:'?ssl=no-verify'},{urlQuery:'?options=-c%20role%3Dpostgres'},
    {urlQuery:'?host=remote.example.invalid'},
  ])await withDraftFixture(options,async f=>{
    await assert.rejects(migrateProfileEntryDrafts({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'DEV_TARGET_REJECTED'});
    assert.equal(f.state.poolOptions,undefined);
  });
});

test('Migration 024 rejects session-role or database identity mismatch',async()=>{
  for(const options of [{sessionRole:'other_login'},{database:'other_database'}]) {
    await withDraftFixture(options,async f=>{
      await assert.rejects(migrateProfileEntryDrafts({
        approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      }),{message:'DEV_TARGET_IDENTITY_MISMATCH'});
      assert.equal(f.state.migrationCount,0);
      assert.equal(f.state.rolledBack,true);
    });
  }
});

const educationCatalogVersion='202610190023_education_catalog';
const educationCatalogHash='462f8ee5bd4e094539996615a8aa2b1433f257fa5cd6161eb3d811814d2d3372';
const educationCatalogPath=new URL(
  `../supabase/migrations/${educationCatalogVersion}.sql`,import.meta.url,
);
const educationPriorVersions=[...versions,'202610170022_resume_layout'];
const syntheticEducationCa=
  '-----BEGIN CERTIFICATE-----\nlocal-test-only\n-----END CERTIFICATE-----\n';

async function educationCatalogFixture({
  target=null,database='postgres',role='jobix_catalog_migrator',
  sessionRole=null,unsafeRole=false,adminMembership=false,urlQuery='',
  missingPrerequisite=false,privilegeFailure=false,ledgerState='prior',
  schemaConflict=false,lockBusy=false,tableLockBusy=false,failAt=null,
  postAssertionFailure=false,changedPrerequisite=null,
}={}) {
  const dir=await mkdtemp(join(os.tmpdir(),'jobix-migration-023-'));
  const caFile=join(dir,'development-ca.pem');
  await writeFile(caFile,syntheticEducationCa);
  const originalUrl=process.env.JOBIX_DEV_DATABASE_URL;
  const connectionTarget=target??
    `${role}.lmouxhbjhtqdtiqijcee@aws-0-me-central1.pooler.supabase.com`;
  const credentialTarget=connectionTarget.includes('@')&&
      !connectionTarget.includes(':synthetic-password@')
    ?connectionTarget.replace('@',':synthetic-password@')
    :connectionTarget;
  process.env.JOBIX_DEV_DATABASE_URL=
    `postgresql://${credentialTarget}:5432/postgres${urlQuery}`;
  const priorRows=[];
  for(const version of educationPriorVersions) {
    const text=await readFile(new URL(`../supabase/migrations/${version}.sql`,import.meta.url),'utf8');
    priorRows.push({version,sha256:createHash('sha256').update(text).digest('hex')});
  }
  const state={
    queries:[],migrationCount:0,ledgerInsertCount:0,committed:false,
    rolledBack:false,schemaApplied:ledgerState==='applied'||ledgerState==='applied-plus-024',
    ledgerRows:priorRows,poolCreated:false,
  };
  if(ledgerState==='missing-prior')state.ledgerRows.pop();
  if(ledgerState==='prior-checksum-mismatch')state.ledgerRows[0].sha256='0'.repeat(64);
  if(ledgerState==='prior-version-mismatch')state.ledgerRows[0].version='wrong-version';
  if(['applied','applied-plus-024','applied-checksum-mismatch'].includes(ledgerState)) {
    state.ledgerRows.push({version:educationCatalogVersion,sha256:
      ledgerState==='applied-checksum-mismatch'?'0'.repeat(64):educationCatalogHash});
  }
  if(ledgerState==='applied-plus-024') {
    state.ledgerRows.push({version:profileEntryDraftVersion,sha256:reviewedDraftHash});
  }
  const poolFactory=options=>{
    state.poolCreated=true;
    state.poolOptions=options;
    return {
      async connect() {
        return {
          async query(sql,params) {
            state.queries.push({sql,params});
            if(sql==='BEGIN'||sql.startsWith('SET LOCAL'))return {rows:[]};
            if(sql.startsWith('LOCK TABLE')) {
              if(tableLockBusy) {const error=Error('synthetic lock busy');error.code='55P03';throw error;}
              return {rows:[]};
            }
            if(sql.includes('pg_try_advisory_xact_lock')) {
              return {rows:[{acquired:!lockBusy}]};
            }
            if(sql.includes('current_database() AS database')) {
              return {rows:[{
                database,role,session_role:sessionRole??role,rolcanlogin:true,
                rolsuper:unsafeRole,rolbypassrls:false,rolcreaterole:false,
                rolcreatedb:false,no_admin_membership:!adminMembership,
              }]};
            }
            if(sql.includes("to_regnamespace('public')")) {
              return {rows:[{
                public_schema:true,auth_schema:true,migration_ledger:true,
                auth_uid:!missingPrerequisite,authenticated_role:true,
                anon_role:true,service_role:true,
              }]};
            }
            if(sql.includes("has_schema_privilege(current_user,'public','USAGE')")) {
              return {rows:[{
                public_usage:!privilegeFailure,public_create:!privilegeFailure,
                auth_usage:!privilegeFailure,auth_uid_execute:!privilegeFailure,
                ledger_permissions:!privilegeFailure,ledger_owner:!privilegeFailure,
                ledger_rls:true,
              }]};
            }
            if(sql==='SELECT version,sha256 FROM public.jobix_export_migrations ORDER BY version') {
              return {rows:state.ledgerRows.map(row=>({...row}))};
            }
            if(sql.includes('CREATE TABLE public.education_institution_catalog')) {
              state.migrationCount++;
              state.schemaApplied=true;
              if(failAt==='migration')throw Error('synthetic migration SQL failure');
              return {rows:[]};
            }
            if(sql.includes('AS tables_complete')) {
              const complete=state.schemaApplied&&!postAssertionFailure;
              return {rows:[{
                tables_complete:complete,columns_complete:complete,
                indexes_complete:complete,constraints_complete:complete,
                rls_complete:complete,policies_complete:complete,
                comments_complete:complete,grants_complete:complete,
                institution_count_complete:complete,institution_seed_complete:complete,
                field_seed_complete:complete,ledger_matches:complete,
              }]};
            }
            if(sql.includes('c.relname=ANY($1::text[])')) {
              return {rows:schemaConflict?[{relname:'education_institution_catalog',relkind:'r'}]:[]};
            }
            if(sql.startsWith('INSERT INTO public.jobix_export_migrations')) {
              state.ledgerInsertCount++;
              if(failAt==='ledger')throw Error('synthetic ledger insertion failure');
              state.ledgerRows.push({version:params[0],sha256:params[1]});
              return {rows:[]};
            }
            if(sql==='COMMIT') {
              if(failAt==='commit')throw Error('synthetic connection loss during COMMIT');
              state.committed=true;
              return {rows:[]};
            }
            if(sql==='ROLLBACK') {
              state.rolledBack=true;
              state.schemaApplied=false;
              state.ledgerRows=priorRows.map(row=>({...row}));
              return {rows:[]};
            }
            throw Error(`Unexpected mocked Migration 023 query: ${sql.slice(0,100)}`);
          },
          release(){state.released=true;},
        };
      },
      async end(){state.ended=true;},
    };
  };
  return {
    caFile,state,poolFactory,
    readMigrationSource:async version=>{
      const text=await readFile(new URL(`../supabase/migrations/${version}.sql`,import.meta.url),'utf8');
      return version===changedPrerequisite?`${text}\n-- test mutation`:text;
    },
    restore:async()=>{
      if(originalUrl===undefined)delete process.env.JOBIX_DEV_DATABASE_URL;
      else process.env.JOBIX_DEV_DATABASE_URL=originalUrl;
      await rm(dir,{recursive:true,force:true});
    },
  };
}

async function withEducationFixture(options,fn) {
  const fixture=await educationCatalogFixture(options);
  try {await fn(fixture);} finally {await fixture.restore();}
}

test('Migration 023 source matches the independently pinned SHA-256',async()=>{
  const source=await readFile(educationCatalogPath,'utf8');
  assert.equal(verifyEducationCatalogMigrationSource(source),educationCatalogHash);
  await assert.rejects(async()=>verifyEducationCatalogMigrationSource(`${source}\n-- changed`),{
    message:'MIGRATION_SOURCE_CHECKSUM_MISMATCH',
  });
});

test('Migration 023 rejects a changed 012–022 source before connecting',async()=>{
  await withEducationFixture({changedPrerequisite:educationPriorVersions[0]},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      readMigrationSource:f.readMigrationSource,
    }),{message:'PREREQUISITE_SOURCE_CHECKSUM_MISMATCH'});
    assert.equal(f.state.poolCreated,false);
  });
});

test('Migration 023 rejects wrong target, elevated identity, and admin membership',async()=>{
  await withEducationFixture({
    target:'postgres.otherproject@aws-0-me-central1.pooler.supabase.com',
  },async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'DEV_TARGET_REJECTED'});
    assert.equal(f.state.poolCreated,false);
  });
  for(const options of [{role:'postgres'},{unsafeRole:true},{adminMembership:true}]) {
    await withEducationFixture(options,async f=>{
      await assert.rejects(migrateEducationCatalog({
        approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      }),{message:'MIGRATION_IDENTITY_UNSAFE'});
      assert.equal(f.state.migrationCount,0);
      assert.equal(f.state.ledgerInsertCount,0);
    });
  }
});

test('Migration 023 fails closed on missing schema prerequisites or privileges',async()=>{
  for(const [options,error] of [
    [{missingPrerequisite:true},'MIGRATION_023_PREREQUISITE_SCHEMA_MISSING'],
    [{privilegeFailure:true},'MIGRATION_023_REQUIRED_PRIVILEGES_MISSING'],
  ]) await withEducationFixture(options,async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:error});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
  });
});

test('Migration 023 rejects missing, reordered, or mismatched prerequisite ledger entries',async()=>{
  for(const ledgerState of [
    'missing-prior','prior-version-mismatch','prior-checksum-mismatch',
  ]) await withEducationFixture({ledgerState},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),ledgerState==='prior-checksum-mismatch'
      ?{message:'MIGRATION_CHECKSUM_CONFLICT'}
      :{message:'MIGRATION_LEDGER_STATE_CONFLICT'});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.ledgerInsertCount,0);
  });
});

test('Migration 023 rejects partial schema and inconsistent later ledger state',async()=>{
  await withEducationFixture({schemaConflict:true},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_023_SCHEMA_CONFLICT'});
    assert.equal(f.state.migrationCount,0);
  });
  await withEducationFixture({ledgerState:'applied-checksum-mismatch'},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_CHECKSUM_CONFLICT'});
    assert.equal(f.state.migrationCount,0);
  });
});

test('Migration 023 SQL and ledger failures roll back together',async()=>{
  for(const failAt of ['migration','ledger']) await withEducationFixture({failAt},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),new RegExp(`synthetic ${failAt==='migration'?'migration SQL':'ledger insertion'} failure`));
    assert.equal(f.state.schemaApplied,false);
    assert.equal(f.state.ledgerRows.length,educationPriorVersions.length);
    assert.equal(f.state.committed,false);
    assert.equal(f.state.rolledBack,true);
  });
});

test('Migration 023 lock contention aborts before DDL',async()=>{
  for(const options of [{lockBusy:true},{tableLockBusy:true}]) {
    await withEducationFixture(options,async f=>{
      await assert.rejects(migrateEducationCatalog({
        approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      }),{message:options.lockBusy?'MIGRATION_LOCK_BUSY':'MIGRATION_LOCK_CONTENTION'});
      assert.equal(f.state.migrationCount,0);
      assert.equal(f.state.ledgerInsertCount,0);
    });
  }
});

test('Migration 023 commit uncertainty is never reported as a definite rollback',async()=>{
  await withEducationFixture({failAt:'commit'},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_COMMIT_OUTCOME_UNKNOWN'});
    assert.equal(f.state.committed,false);
  });
});

test('Migration 023 applies atomically with verified TLS and shared advisory lock',async()=>{
  await withEducationFixture({},async f=>{
    assert.equal(await migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),'applied');
    assert.equal(f.state.poolOptions.ssl.rejectUnauthorized,true);
    assert.equal(f.state.poolOptions.max,1);
    assert.equal(f.state.poolOptions.options,'');
    assert.equal(f.state.migrationCount,1);
    assert.equal(f.state.ledgerInsertCount,1);
    assert.equal(f.state.ledgerRows.at(-1).version,educationCatalogVersion);
    assert.equal(f.state.ledgerRows.at(-1).sha256,educationCatalogHash);
    assert.equal(f.state.committed,true);
    assert.equal(f.state.rolledBack,false);
    assert.ok(f.state.queries.some(query=>query.sql.includes(
      "pg_try_advisory_xact_lock(hashtext('jobix_phase3_dev_migrations'))")));
  });
});

test('Migration 023 exact ledger plus complete schema is verification-only',async()=>{
  for(const ledgerState of ['applied','applied-plus-024']) {
    await withEducationFixture({ledgerState},async f=>{
      assert.equal(await migrateEducationCatalog({
        approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
      }),'already-applied');
      assert.equal(f.state.migrationCount,0);
      assert.equal(f.state.ledgerInsertCount,0);
      assert.equal(f.state.committed,true);
    });
  }
  await withEducationFixture({ledgerState:'applied',postAssertionFailure:true},async f=>{
    await assert.rejects(migrateEducationCatalog({
      approved:true,caFile:f.caFile,poolFactory:f.poolFactory,
    }),{message:'MIGRATION_023_POST_ASSERTION_FAILED'});
    assert.equal(f.state.migrationCount,0);
    assert.equal(f.state.rolledBack,true);
  });
});

test('Migration 023 CLI rejects ambiguous flags before any connection',()=>{
  const result=spawnSync(process.execPath,[
    fileURLToPath(new URL('./apply_phase3_dev.mjs',import.meta.url)),
    '--apply-development-education-catalog-023','--apply-development',
    '--ca-file','unused',
  ],{encoding:'utf8',env:{},timeout:10000});
  assert.equal(result.status,1);
  assert.match(result.stderr,/BLOCKED_AMBIGUOUS_MODE/);
  assert.equal(result.stdout,'');
});
