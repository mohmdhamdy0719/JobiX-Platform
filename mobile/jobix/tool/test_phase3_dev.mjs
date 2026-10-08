// Opt-in DEVELOPMENT checks. DB fixtures ALWAYS roll back; GCS fixture is
// freshly created here and deleted only by its exact generation.
import {readFile} from 'node:fs/promises';
import {randomUUID,createHash} from 'node:crypto';
import {Pool} from '../backend/pdf/node_modules/pg/esm/index.mjs';
import {Canonicalizer} from '../backend/pdf/document.mjs';
import {google,bucket} from './phase3_google.mjs';
if(!process.argv.includes('--allow-phase3-isolated-fixtures')) {
  console.error('EXPLICIT_ISOLATED_DEVELOPMENT_FIXTURE_APPROVAL_REQUIRED');process.exit(1);
}
const actor=randomUUID(),other=randomUUID(),operation=randomUUID(),key=randomUUID();
const uri=new URL(process.env.JOBIX_DEV_DATABASE_URL);
if(!uri.username.endsWith('.lmouxhbjhtqdtiqijcee')||!uri.hostname.endsWith('.pooler.supabase.com')||
 uri.port!=='5432'||uri.pathname!='/postgres')throw Error('DEV_TARGET_REJECTED');
for(const field of ['sslmode','sslrootcert','sslcert','sslkey'])uri.searchParams.delete(field);
const pool=new Pool({connectionString:uri.toString(),max:1,connectionTimeoutMillis:15000,statement_timeout:15000,
 ssl:{rejectUnauthorized:true,ca:await readFile(new URL('../assets/certs/supabase-root-2021.crt',import.meta.url),'utf8')}});
const assert=(condition)=>{if(!condition)throw Error('FIXTURE_ASSERTION_FAILED');};
let client,stage='connect';
try {
 client=await pool.connect();await client.query('BEGIN');
 stage='create-confirmed-isolated-auth-fixture';
 await client.query('INSERT INTO auth.users(id,email,email_confirmed_at) VALUES($1,$2,now()),($3,$4,now())',
  [actor,`phase3-fixture-${actor}@example.invalid`,other,`phase3-fixture-${other}@example.invalid`]);
 const profile=(await client.query('SELECT id FROM public.career_profiles WHERE user_id=$1',[actor])).rows[0]?.id;
 assert(!!profile);
 stage='seed-isolated-profile';
 await client.query(`UPDATE public.profile_personal_data SET full_name='Phase Three Fixture',
 email='fixture@example.invalid',phone='+20 100 000 0000' WHERE profile_id=$1`,[profile]);
 await client.query(`INSERT INTO public.profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current)
 VALUES($1,$2,'Community','Helper','2025-01-01',true)`,[randomUUID(),profile]);
 await client.query('UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true');
 stage='canonical-preparation';
 const source=(await client.query('SELECT public.jobix_export_source($1,$2) AS value',[actor,profile])).rows[0].value;
 const doc=await new Canonicalizer().prepare(source);assert(doc.issues.length===0);
 const args=[actor,key,randomUUID(),profile,doc.profile_version,doc.configuration_version,doc.source_sha256,
 doc.document_sha256,createHash('sha256').update(key).digest('hex'),doc.html,doc.bundle,null,JSON.stringify(doc.asset_manifest)];
 const create=`SELECT public.jobix_export_create(${args.map((_,index)=>'$'+(index+1)).join(',')}) AS value`;
 stage='atomic-create-replay';
 const first=(await client.query(create,args)).rows[0].value;
 args[2]=randomUUID();
 const replay=(await client.query(create,args)).rows[0].value;
 assert(JSON.stringify(first)===JSON.stringify(replay));
 stage='reservation-balance';
 const before=(await client.query('SELECT finalized_balance,reserved_balance FROM public.credit_accounts WHERE user_id=$1',[actor])).rows[0];
 assert(Number(before.finalized_balance)===5&&Number(before.reserved_balance)===2);
 stage='cross-actor-rls';
 await client.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[other]);
 await client.query('SET LOCAL ROLE authenticated');
 await client.query('SAVEPOINT client_table_check');
 let denied=false;
 try {await client.query('SELECT id FROM public.export_jobs WHERE user_id=$1',[actor]);}
 catch(error){denied=error.code==='42501';}
 await client.query('ROLLBACK TO SAVEPOINT client_table_check');
 assert(denied); // Private table access denied outright: do not grant SELECT for the test.
 await client.query('RESET ROLE');
 await client.query('SAVEPOINT cross_actor_status');
 let isolated=false;
 try {await client.query('SELECT public.jobix_export_status($1,$2)',[other,first.operation_id]);}
 catch(error){isolated=['NOT_FOUND','FORBIDDEN'].includes(error.message);}
 await client.query('ROLLBACK TO SAVEPOINT cross_actor_status');assert(isolated);
 stage='freeze';
 await client.query("UPDATE public.career_profiles SET status='DELETING' WHERE id=$1",[profile]);
 assert(Number((await client.query('SELECT reserved_balance FROM public.credit_accounts WHERE user_id=$1',[actor])).rows[0].reserved_balance)===0);
 const scope=await client.query('SELECT public.jobix_export_freeze($1,$2) AS value',[actor,profile]);
 assert(scope.rows[0].value.length===1);
 const g=await google();
 stage='owned-object-absence';
 const objects=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/o?prefix=${encodeURIComponent('exports/'+actor+'/')}`);
 assert((objects.items??[]).length===0);
 stage='private-export-purge';
 const purged=(await client.query('SELECT public.jobix_export_purge($1,$2,true) AS value',[actor,profile])).rows[0].value;
 assert(purged.state==='EXPORT_DATA_REMOVED'&&purged.snapshots_verified===true);
 assert((await client.query('SELECT count(*)::int AS n FROM public.export_snapshots WHERE user_id=$1',[actor])).rows[0].n===0);
 console.log('PASS: LIVE_DEV_DB_CANONICAL_CREATE_REPLAY_RESERVATION_RLS_FREEZE_EXPORT_PURGE');
}catch(error){
 const code=/^[0-9A-Z]{5}$/.test(error.code??'')?error.code:
  ['FIXTURE_ASSERTION_FAILED','VALIDATION_FAILED','SERVICE_UNAVAILABLE','EXPORT_NOT_READY',
   'AUTH_REQUIRED','NOT_FOUND','FORBIDDEN'].includes(error.code??error.message)?error.code??error.message:'SUPPRESSED';
 console.error(JSON.stringify({check:'LIVE_DEV_DB_FIXTURE_FAILED',stage,code}));process.exitCode=1;
}finally{
 if(client){await client.query('ROLLBACK').catch(()=>{process.exitCode=1;});client.release();}
 await pool.end();
}
if(process.exitCode)process.exit();
console.log('PASS: ALL_LIVE_DB_FIXTURE_ROWS_AND_CREDIT_OPERATIONS_ROLLED_BACK');
const g=await google(),path=`exports/${actor}/${operation}/${createHash('sha256').update(key).digest('hex')}.pdf`;
let generation;
try {
 const boundary=randomUUID(),bytes=Buffer.from('%PDF-synthetic-storage-protocol-fixture');
 const body=Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Type: application/json\r\n\r\n`+
 JSON.stringify({name:path,contentType:'application/pdf',metadata:{purpose:'phase3-isolated-storage-test'}})+
 `\r\n--${boundary}\r\nContent-Type: application/pdf\r\n\r\n`),bytes,Buffer.from(`\r\n--${boundary}--\r\n`)]);
 const url=`https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=multipart&ifGenerationMatch=0`;
 const options={method:'POST',write:true,body,headers:{'content-type':`multipart/related; boundary=${boundary}`}};
 const object=await g.request(url,options);generation=String(object.generation);
 let conflict=false;try{await g.request(url,options);}catch(error){conflict=error.status===412;}
 assert(conflict);
 const publicRead=await fetch(`https://storage.googleapis.com/${bucket}/${path}?generation=${generation}`,{signal:AbortSignal.timeout(15000)});
 assert([401,403].includes(publicRead.status));
 console.log('PASS: LIVE_PRIVATE_GCS_CONDITIONAL_CREATE_CONFLICT_ANONYMOUS_DENIAL_USING_DEPLOYER_FIXTURE');
}catch{
 console.error('FAIL: LIVE_GCS_FIXTURE_DETAILS_SUPPRESSED');process.exitCode=1;
}finally{
 if(generation) {
  try{
   await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(path)}?generation=${generation}&ifGenerationMatch=${generation}`,
    {method:'DELETE',write:true});
   let missing=false;
   try{await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(path)}`);}
   catch(error){missing=error.status===404;}
   assert(missing);console.log('PASS: NEW_TEST_OBJECT_EXACT_GENERATION_DELETED_ABSENCE_VERIFIED');
  }catch{console.error('FAIL: ISOLATED_TEST_OBJECT_CLEANUP_UNVERIFIED');process.exitCode=1;}
 }
}
