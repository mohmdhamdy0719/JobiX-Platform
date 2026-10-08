import {ExportError} from './document.mjs';
import {readFile} from 'node:fs/promises';
const contracts = {
  source:['actor','profile'], replay:['actor','command','request_hash'],
  create:['actor','command','request_id','profile','profile_version','config_version',
    'source_hash','document_hash','request_hash','html','bundle','again','asset_manifest'],
  status:['actor','operation'], history:['actor','before_id'], missing:['actor','operation','generation'],
  claim:['capacity'], heartbeat:['operation','fence'], stage:['operation','fence','stage'],
  finish:['operation','fence','proof','terminal'], recover:[],
  freeze:['actor','profile'], retention:[],cleaned:['operation','generation'],
  upload_begin:['operation','fence'],upload_settle:['operation','fence','generation'],
  quiescent:['actor','profile'],purge:['actor','profile','objects_verified'],deletions:[],
};
const jsonArgs = new Set(['proof','asset_manifest']);
export class Database {
  constructor(pool) { this.pool = pool; }
  async call(method,args={}) {
    const names = contracts[method];
    if (!names) throw new ExportError('FORBIDDEN');
    const values = names.map(key => jsonArgs.has(key) && args[key] != null
      ? JSON.stringify(args[key]) : args[key] ?? null);
    try {
      const result = await this.pool.query(
        `select public.jobix_export_${method}(${values.map((_,i)=>'$'+(i+1)).join(',')}) as result`,values);
      return result.rows[0].result;
    } catch (error) {
      const known = new Set(['AUTH_REQUIRED','ACCOUNT_DELETING','FORBIDDEN','NOT_FOUND',
        'EXPORT_NOT_READY','VALIDATION_FAILED','VERSION_CONFLICT','IDEMPOTENCY_KEY_REUSE',
        'CREDIT_INSUFFICIENT','RATE_LIMITED','STALE_LEASE','INVALID_STATE','CLEANUP_UNVERIFIED']);
      throw new ExportError(known.has(error.message) ? error.message : 'SERVICE_UNAVAILABLE');
    }
  }
}
export async function database(connectionString) {
  if (!connectionString) throw new ExportError('EXPORT_NOT_READY');
  const target=new URL(connectionString);
  const user=decodeURIComponent(target.username);
  const pooler=target.hostname.endsWith('.pooler.supabase.com') &&
    user.endsWith('.lmouxhbjhtqdtiqijcee');
  if (!['postgres:','postgresql:'].includes(target.protocol) ||
      !(pooler || target.hostname==='db.lmouxhbjhtqdtiqijcee.supabase.co') ||
      !user.startsWith('jobix_export_') || target.pathname!=='/postgres') {
    throw new ExportError('FORBIDDEN');
  }
  for(const key of ['sslmode','sslcert','sslkey','sslrootcert']) target.searchParams.delete(key);
  if(!process.env.JOBIX_DEV_DATABASE_CA_FILE)throw new ExportError('EXPORT_NOT_READY');
  const ca=await readFile(process.env.JOBIX_DEV_DATABASE_CA_FILE,'utf8');
  const {Pool} = await import('pg');
  return new Database(new Pool({connectionString:target.toString(),max:5,
    ssl:{rejectUnauthorized:true,ca},connectionTimeoutMillis:10000,
    statement_timeout:15000, application_name:'jobix-private-export'}));
}
