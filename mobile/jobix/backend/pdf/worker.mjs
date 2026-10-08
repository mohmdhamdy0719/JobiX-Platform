import {sha256,bundle,ExportError} from './document.mjs';

export class Worker {
  constructor({db,renderer,storage,enabled=false,heartbeatMs=60000}) {
    Object.assign(this,{db,renderer,storage,enabled,heartbeatMs});this.active=0;
  }
  async recover() {
    if (!this.enabled) throw new ExportError('EXPORT_NOT_READY');
    await this.db.call('recover');
    return this.dispatch();
  }
  async dispatch() {
    if (!this.enabled) throw new ExportError('EXPORT_NOT_READY');
    // Reserve capacity before asynchronous claiming, including concurrent dispatch.
    const slots=2-this.active;
    if (slots<=0) return;
    this.active+=slots;
    let jobs=[];
    try {
      jobs=await this.db.call('claim',{capacity:slots});
      await Promise.all(jobs.map(job=>this.run(job)));
    } finally {this.active-=slots;}
  }
  async run(job) {
    const controller=new AbortController(); let heartbeatInFlight=false;
    const operation=job.id,fence=job.lease_token;
    const timer=setInterval(async()=>{
      if (heartbeatInFlight || controller.signal.aborted) return;
      heartbeatInFlight=true;
      try {await this.db.call('heartbeat',{operation,fence});}
      catch {controller.abort();}
      finally {heartbeatInFlight=false;}
    },this.heartbeatMs);
    const remaining=Date.parse(job.deadline)-Date.now();
    const deadline=setTimeout(()=>controller.abort(),Math.max(1,remaining));
    try {
      const snapshot=job.snapshot;
      if (snapshot.bundle!==bundle ||
          sha256(snapshot.canonical_html)!==snapshot.document_sha256) {
        throw new ExportError('VALIDATION_FAILED');
      }
      const path=`exports/${job.user_id}/${job.id}/${snapshot.source_sha256}.pdf`;
      await this.db.call('stage',{operation,fence,stage:'GENERATING'});
      let metadata=await this.storage.inspect(path);
      let pdf;
      if (metadata) {
        // Adopt only the same snapshot/document, not an arbitrary pre-existing object.
        if (metadata.metadata?.document_sha256!==snapshot.document_sha256 ||
            metadata.metadata?.source_sha256!==snapshot.source_sha256) {
          throw new ExportError('VALIDATION_FAILED');
        }
        pdf=await this.storage.read(path,metadata.generation);
      } else {
        pdf=await this.renderer.render(snapshot.canonical_html,{
          signal:controller.signal,timeout:Math.min(600000,remaining)});
      }
      const pages=await this.renderer.validate(pdf,snapshot.canonical_html);
      if (!Number.isInteger(pages) || pages<1 || pages>20) throw new ExportError('VALIDATION_FAILED');
      if (controller.signal.aborted) throw new ExportError('STALE_LEASE');
      await this.db.call('heartbeat',{operation,fence});
      await this.db.call('stage',{operation,fence,stage:'UPLOADING'});
      if (!metadata) {
        try {metadata=await this.storage.create(path,pdf,{
          document_sha256:snapshot.document_sha256,source_sha256:snapshot.source_sha256,
          pdf_sha256:sha256(pdf)},controller.signal);}
        catch(error) {
          // A conditional-create conflict can be an earlier worker's valid upload.
          if (error.code!=='OBJECT_EXISTS') throw error;
          metadata=await this.storage.inspect(path);
        }
      }
      if (!metadata || metadata.contentType!=='application/pdf' ||
          metadata.metadata?.document_sha256!==snapshot.document_sha256 ||
          metadata.metadata?.source_sha256!==snapshot.source_sha256) {
        throw new ExportError('VALIDATION_FAILED');
      }
      const stored=await this.storage.read(path,metadata.generation);
      const storedPages=await this.renderer.validate(stored,snapshot.canonical_html);
      if (storedPages>20 || storedPages<1 || metadata.metadata?.pdf_sha256!==sha256(stored)) {
        throw new ExportError('VALIDATION_FAILED');
      }
      if (controller.signal.aborted) throw new ExportError('STALE_LEASE');
      await this.db.call('finish',{operation,fence,proof:{
        path,generation:String(metadata.generation),pdf_sha256:sha256(stored),
        document_sha256:snapshot.document_sha256,pages:storedPages,size:stored.length,
        content_type:'application/pdf',created_at:metadata.timeCreated,
      },terminal:false});
    } catch(error) {
      // Never release a lost/expired lease or an ambiguous committed completion.
      if (!controller.signal.aborted && error.code!=='STALE_LEASE') {
        try {await this.db.call('finish',{operation,fence,proof:null,
          terminal:error.code==='VALIDATION_FAILED'});} catch {}
      }
    } finally {clearInterval(timer);clearTimeout(deadline);controller.abort();}
  }
}
