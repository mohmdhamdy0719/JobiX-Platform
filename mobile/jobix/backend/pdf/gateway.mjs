import {randomUUID} from 'node:crypto';
import {bundle, ExportError, requireUuid, logicalHash} from './document.mjs';

export class Gateway {
  constructor({db,canonicalizer,storage,enabled=false}) {
    Object.assign(this,{db,canonicalizer,storage,enabled});
  }
  async handle(actor,action,command={}) {
    requireUuid(actor);
    if (!this.enabled) throw new ExportError('EXPORT_NOT_READY');
    if (action==='history') {
      const before = command.cursor == null ? null : requireUuid(command.cursor);
      const jobs = await this.db.call('history',{actor,before_id:before});
      return {jobs:jobs.map(publicJob),next_cursor:jobs.length===25?jobs.at(-1).id:null};
    }
    if (['status','download'].includes(action)) {
      const operation = requireUuid(command.export_id);
      const job = await this.db.call('status',{actor,operation});
      if (action==='status') return publicJob(job);
      if (job.state==='EXPIRED' || (job.expires_at && Date.parse(job.expires_at)<=Date.now())) {
        throw new ExportError('EXPORT_EXPIRED');
      }
      if (job.state==='MISSING_OBJECT') throw new ExportError('EXPORT_OBJECT_MISSING');
      if (job.state!=='COMPLETED') throw new ExportError('EXPORT_NOT_READY');
      const metadata = await this.storage.inspect(job.object_path,job.object_generation);
      if (!metadata) {
        await this.db.call('missing',{actor,operation,generation:job.object_generation});
        throw new ExportError('EXPORT_OBJECT_MISSING');
      }
      if (String(metadata.generation)!==job.object_generation) throw new ExportError('EXPORT_OBJECT_MISSING');
      // Recheck account state after IO; URLs themselves remain short-lived bearer capabilities.
      const current=await this.db.call('status',{actor,operation});
      if(current.state!=='COMPLETED' || current.object_generation!==job.object_generation) {
        throw new ExportError('EXPORT_NOT_READY');
      }
      const ttl = Math.min(600,Math.floor((Date.parse(job.expires_at)-Date.now())/1000));
      if (ttl<1) throw new ExportError('EXPORT_EXPIRED');
      return {url:await this.storage.sign(job.object_path,job.object_generation,ttl),expires_in:ttl};
    }
    if (action==='document') return this.canonicalizer.prepare(
      await this.db.call('source',{actor,profile:requireUuid(command.profile_id)}));
    if (!['create','again'].includes(action)) throw new ExportError('VALIDATION_FAILED');
    const {payload} = command;
    requireUuid(command.request_id);requireUuid(command.idempotency_key);
    if (!payload || !Number.isSafeInteger(command.expected_profile_version) ||
        !Number.isSafeInteger(payload.expected_configuration_version) ||
        payload.renderer_bundle_version!==bundle ||
        !/^[0-9a-f]{64}$/.test(payload.expected_document_sha256 ?? '') ||
        Object.keys(payload).some(k=>!['profile_id','expected_configuration_version',
          'expected_document_sha256','renderer_bundle_version','historical_export_id'].includes(k))) {
      throw new ExportError('VALIDATION_FAILED');
    }
    const profile = requireUuid(payload.profile_id);
    if (action==='again') requireUuid(payload.historical_export_id);
    else if (payload.historical_export_id) throw new ExportError('VALIDATION_FAILED');
    const hash = logicalHash(command);
    const replay = await this.db.call('replay',{actor,command:command.idempotency_key,request_hash:hash});
    if (replay) return replay;
    const document = await this.handle(actor,'document',{profile_id:profile});
    if (document.document_sha256!==payload.expected_document_sha256 ||
        document.profile_version!==command.expected_profile_version ||
        document.configuration_version!==payload.expected_configuration_version) {
      throw new ExportError('VERSION_CONFLICT');
    }
    if (document.issues.length) throw new ExportError('VALIDATION_FAILED');
    return this.db.call('create',{
      actor,command:command.idempotency_key,request_id:command.request_id ?? randomUUID(),
      profile,profile_version:document.profile_version,config_version:document.configuration_version,
      source_hash:document.source_sha256,document_hash:document.document_sha256,
      request_hash:hash,html:document.html,bundle,again:payload.historical_export_id ?? null,
    });
  }
}
function publicJob(job) {
  const {object_path,object_generation,pdf_sha256,lease_expires_at,user_id,...safe} = job;
  return safe;
}
