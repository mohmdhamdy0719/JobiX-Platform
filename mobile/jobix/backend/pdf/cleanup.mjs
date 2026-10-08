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
    if(!this.barrier || !(await this.barrier.quiescent(jobs))) {
      return {state:'DELETION_PENDING',objects_verified:false,
        snapshot_policy:'APPROVAL_REQUIRED'};
    }
    for(const job of jobs)await this.removeGeneration(job);
    // Verify again after the barrier/cleanup, including an upload racing removal.
    if(!(await this.barrier.quiescent(jobs)))throw new ExportError('CLEANUP_UNVERIFIED');
    for(const job of jobs)if(await this.storage.inspect(job.path)) {
      throw new ExportError('CLEANUP_UNVERIFIED');
    }
    // Intentionally no snapshot purge or "account deletion complete" claim.
    return {state:'DELETION_PENDING',objects_verified:true,
      snapshot_policy:'APPROVAL_REQUIRED'};
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
