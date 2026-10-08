// Development credential provisioning only. Never writes secrets to files/logs.
// Existing LOGINs/secret versions are not rotated or overwritten by this tool.
import {readFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {google,projectNumber,bucket} from './phase3_google.mjs';
if(!process.argv.includes('--provision-restricted-development-login')) {
 console.error('EXPLICIT_DEVELOPMENT_PROVISIONING_REQUIRED');process.exit(1);
}
const role='jobix_export_runtime';
const secret=`https://secretmanager.googleapis.com/v1/projects/${projectNumber}/secrets/jobix-dev-export-database`;
const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
if(!['postgres:','postgresql:'].includes(uri.protocol)||!uri.username.endsWith('.lmouxhbjhtqdtiqijcee')||
 !uri.hostname.endsWith('.pooler.supabase.com')||uri.port!=='5432'||uri.pathname!=='/postgres')throw Error('DEV_TARGET_REJECTED');
for(const field of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(field);
const ca=await readFile(new URL('../assets/certs/supabase-root-2021.crt',import.meta.url),'utf8');
const g=await google(),b=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}`);
if(String(b.projectNumber)!==projectNumber)throw Error('DEV_PROJECT_REJECTED');
const token=await g.impersonate();
let empty=false;
try{await g.request(secret+'/versions/latest:access',{token});}
catch(error){if(error.status===404)empty=true;else throw error;}
if(!empty){console.error('EXISTING_RUNTIME_SECRET_REQUIRES_RECONCILIATION_NO_ROTATION');process.exit(1);}
const pool=new Pool({connectionString:uri.toString(),max:1,ssl:{rejectUnauthorized:true,ca},
 connectionTimeoutMillis:15000,statement_timeout:15000});
let client,stored=false,committed=false;
try {
 client=await pool.connect();await client.query('BEGIN');
 await client.query("SELECT pg_advisory_xact_lock(hashtext('jobix_phase3_dev_runtime_login'))");
 if((await client.query('SELECT 1 FROM pg_roles WHERE rolname=$1',[role])).rowCount)
  throw Error('EXISTING_LOGIN_REQUIRES_RECONCILIATION');
 const password=randomBytes(32).toString('base64url');
 // Base64url has no quote/metacharacters. Never emit the generated statement.
 await client.query(`CREATE ROLE ${role} LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '${password}'`);
 await client.query(`GRANT jobix_export_gateway,jobix_export_worker TO ${role}`);
 const runtime=new URL(uri);runtime.username=role+'.lmouxhbjhtqdtiqijcee';runtime.password=password;
 const result=await g.request(secret+':addVersion',{method:'POST',write:true,
  body:{payload:{data:Buffer.from(runtime.toString()).toString('base64')}}});
 if(!result.name)throw Error('SECRET_VERSION_UNVERIFIED');
 stored=true;await client.query('COMMIT');committed=true;
 console.log('DEVELOPMENT_RESTRICTED_LOGIN_AND_ENCRYPTED_RUNTIME_SECRET_PROVISIONED');
 const check=new Pool({connectionString:runtime.toString(),max:1,ssl:{rejectUnauthorized:true,ca},
  connectionTimeoutMillis:15000,statement_timeout:15000});
 try {
  const flags=(await check.query(`SELECT rolcanlogin,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls
   FROM pg_roles WHERE rolname=current_user`)).rows[0];
  if(!flags.rolcanlogin||Object.entries(flags).some(([key,value])=>key!=='rolcanlogin'&&value))throw Error('LOGIN_FLAGS_UNSAFE');
  const parents=(await check.query(`SELECT r.rolname FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.roleid
   WHERE m.member=(SELECT oid FROM pg_roles WHERE rolname=current_user) ORDER BY r.rolname`)).rows.map(r=>r.rolname);
  if(JSON.stringify(parents)!==JSON.stringify(['jobix_export_gateway','jobix_export_worker']))throw Error('LOGIN_MEMBERSHIP_UNSAFE');
  if((await check.query("SELECT has_table_privilege(current_user,'public.export_jobs','INSERT') AS allowed")).rows[0].allowed)
   throw Error('DIRECT_TABLE_PRIVILEGE_UNSAFE');
  console.log('PASS: RESTRICTED_LOGIN_VERIFIED_TLS_EXACT_MEMBERSHIP_NO_BYPASS_NO_DIRECT_INSERT');
 }finally{await check.end();}
}catch{
 if(client&&!committed)await client.query('ROLLBACK').catch(()=>{});
 console.error(stored&&!committed?'BLOCKED_SECRET_STORED_DB_COMMIT_UNVERIFIED_NO_WORKER_STARTED':
  committed?'BLOCKED_RESTRICTED_LOGIN_POST_PROVISION_VERIFICATION':'BLOCKED_RUNTIME_PROVISIONING_ROLLED_BACK');
 process.exitCode=1;
}finally{if(client)client.release();await pool.end();}
