import {ExportError} from './document.mjs';

/**
 * Private integration hook, not a new account-deletion endpoint/policy.
 * Auth/profile freeze must already have been authorized and applied by its owner.
 * A barrier adapter must prove writer quiescence; elapsed time is NOT that proof.
 */
export class ExportCleanup {
  constructor({db,storage,barrier,enabled=false}) {
    Object.assign(this,{db,storage,barrier,enabled});
  }
  async removeGeneration(job) {
    const object=await this.storage.inspect(job.path);
    if(!object)return;
    if(job.generation && object.generation!==job.generation)throw new ExportError('CLEANUP_UNVERIFIED');
    await this.storage.remove(job.path,object.generation);
    if(await this.storage.inspect(job.path))throw new ExportError('CLEANUP_UNVERIFIED');
  }
  async freeze(actor,profile=null) {
    if(!this.enabled)throw new ExportError('EXPORT_NOT_READY');
    // SQL only accepts an already DELETING account/profile; never changes Auth.
    const jobs=await this.db.call('freeze',{actor,profile});
    for(const job of jobs) {
      const object=await this.storage.inspect(job.path);
      if(object?.metadata?.upload_fence &&
        object.metadata.document_sha256===job.document_sha256 &&
        object.metadata.source_sha256===job.source_sha256) {
        // One registered physical create per fence, no overlapping unresolved
        // creates: this exact stored marker proves that request completed.
        await this.db.call('upload_settle',{operation:job.id,
          fence:object.metadata.upload_fence,generation:String(object.generation)});
      }
    }
    const quiescent=()=>this.barrier?this.barrier.quiescent(jobs):
      this.db.call('quiescent',{actor,profile});
    if((await quiescent())!==true) {
      return {state:'DELETION_PENDING',objects_verified:false,
        reason:'UPLOAD_QUIESCENCE_UNVERIFIED'};
    }
    for(const job of jobs)await this.removeGeneration(job);
    const prefixes=profile?jobs.map(job=>job.path.slice(0,job.path.lastIndexOf('/')+1)):
      [`exports/${actor}/`];
    for(const prefix of prefixes) {
      for(const object of await this.storage.listPrefix(prefix)) {
        await this.storage.remove(object.name,object.generation);
      }
    }
    // Verify again after the barrier/cleanup, including an upload racing removal.
    if((await quiescent())!==true)throw new ExportError('CLEANUP_UNVERIFIED');
    for(const job of jobs)if(await this.storage.inspect(job.path)) {
      throw new ExportError('CLEANUP_UNVERIFIED');
    }
    for(const prefix of prefixes)if((await this.storage.listPrefix(prefix)).length) {
      throw new ExportError('CLEANUP_UNVERIFIED');
    }
    return this.db.call('purge',{actor,profile,objects_verified:true});
  }
  async deletions() {
    if(!this.enabled)throw new ExportError('EXPORT_NOT_READY');
    const scopes=await this.db.call('deletions');
    for(const scope of scopes)await this.freeze(scope.actor,scope.profile);
    return {processed:scopes.length};
  }
  async retention() {
    if(!this.enabled)throw new ExportError('EXPORT_NOT_READY');
    const jobs=await this.db.call('retention'); // Only seven-day expired PDFs.
    for(const job of jobs) {
      await this.removeGeneration(job);
      await this.db.call('cleaned',{operation:job.id,generation:job.generation});
    }
    return {verified:jobs.length}; // History/dedupe/snapshots are preserved.
  }
}
