import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtemp,readFile,rm,writeFile} from 'node:fs/promises';
import os from 'node:os';
import {join} from 'node:path';
import test from 'node:test';
import {
  migrateResumeLayout,
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
