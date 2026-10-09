import {sha256,bundle,fontChecksums,ExportError} from './document.mjs';
import {isDefinitiveUploadRejection} from './google.mjs';

export const systemClock={now:()=>Date.now(),setTimeout,clearTimeout,setInterval,clearInterval};
export class Worker {
  constructor({db,renderer,storage,enabled=false,heartbeatMs=60000,clock=systemClock}) {
    Object.assign(this,{db,renderer,storage,enabled,heartbeatMs,clock});this.active=0;
  }
  async recover() {
    await this.db.call('recover');
    // Recovery only reconciles durable reservations and expired jobs. Dispatch
    // remains controlled by the export gate and cannot run while it is closed.
    if (this.enabled) return this.dispatch();
  }
  async dispatch() {
    if (!this.enabled) throw new ExportError('EXPORT_NOT_READY');
    const slots=2-this.active;
    if (slots<=0) return;
    this.active+=slots;
    try {
      const jobs=await this.db.call('claim',{capacity:slots});
      await Promise.all(jobs.map(job=>this.run(job)));
    } finally {this.active-=slots;}
  }
  async run(job) {
    const controller=new AbortController(),{signal}=controller;
    let heartbeatInFlight=false;
    const operation=job.id,fence=job.lease_token;
    const remaining=()=>Date.parse(job.deadline)-this.clock.now();
    // Race even adapters that fail to honor cancellation; no late result can finalize.
    const step=async(callback)=>{
      if(signal.aborted || remaining()<=0)throw new ExportError('STALE_LEASE');
      let listener;
      try {
        return await Promise.race([Promise.resolve().then(callback),
          new Promise((_,reject)=>{
            listener=()=>reject(new ExportError('STALE_LEASE'));
            signal.addEventListener('abort',listener,{once:true});
          })]);
      } finally {if(listener)signal.removeEventListener('abort',listener);}
    };
    const timer=this.clock.setInterval(async()=>{
      if(heartbeatInFlight || signal.aborted)return;
      heartbeatInFlight=true;
      try {await step(()=>this.db.call('heartbeat',{operation,fence}));}
      catch {controller.abort();}
      finally {heartbeatInFlight=false;}
    },this.heartbeatMs);
    const deadline=this.clock.setTimeout(()=>controller.abort(),Math.max(1,remaining()));
    const validate=async(bytes,html)=>{
      const pages=await step(()=>this.renderer.validate(bytes,html,
        {signal,timeout:Math.min(20000,remaining())}));
      if(!Number.isInteger(pages)||pages<1||pages>20)throw new ExportError('VALIDATION_FAILED');
      return pages;
    };
    try {
      const snapshot=job.snapshot;
      if(snapshot.bundle!==bundle || sha256(snapshot.canonical_html)!==snapshot.document_sha256 ||
        (Array.isArray(snapshot.asset_manifest?.font_checksums) && JSON.stringify(snapshot.asset_manifest.font_checksums)!==
          JSON.stringify(fontChecksums(snapshot.canonical_html))))throw new ExportError('VALIDATION_FAILED');
      if(snapshot.asset_manifest?.licenses?.some(license=>
        typeof license.text!=='string' || sha256(license.text)!==license.sha256)) {
        throw new ExportError('VALIDATION_FAILED');
      }
      const path=`exports/${job.user_id}/${operation}/${snapshot.source_sha256}.pdf`;
      await step(()=>this.db.call('stage',{operation,fence,stage:'GENERATING'}));
      let metadata=await step(()=>this.storage.inspect(path,null,signal)),pdf;
      if(metadata) {
        if(metadata.metadata?.document_sha256!==snapshot.document_sha256 ||
          metadata.metadata?.source_sha256!==snapshot.source_sha256)throw new ExportError('VALIDATION_FAILED');
        pdf=await step(()=>this.storage.read(path,metadata.generation,signal));
        if(metadata.metadata.upload_fence) {
          await step(()=>this.db.call('upload_settle',{operation,
            fence:metadata.metadata.upload_fence,generation:String(metadata.generation)}));
        }
      } else {
        pdf=await step(()=>this.renderer.render(snapshot.canonical_html,
          {signal,timeout:Math.min(600000,remaining())}));
      }
      await validate(pdf,snapshot.canonical_html);
      await step(()=>this.db.call('heartbeat',{operation,fence}));
      await step(()=>this.db.call('stage',{operation,fence,stage:'UPLOADING'}));
      if(!metadata) {
        await step(()=>this.db.call('upload_begin',{operation,fence}));
        try {
          metadata=await step(()=>this.storage.create(path,pdf,{
            document_sha256:snapshot.document_sha256,source_sha256:snapshot.source_sha256,
            pdf_sha256:sha256(pdf),upload_fence:fence},signal).then(async object=>{
              await this.db.call('upload_settle',{operation,fence,generation:String(object.generation)});
              return object;
            }).catch(async error=>{
              if(error.code==='OBJECT_EXISTS'||isDefinitiveUploadRejection(error,path,fence)) {
                await this.db.call('upload_settle',{operation,fence,generation:null});
              }
              // Network/timeout ambiguity stays SENT: never assume quiescence.
              throw error;
            }));
        } catch(error) {
          if(error.code!=='OBJECT_EXISTS')throw error;
          metadata=await step(()=>this.storage.inspect(path,null,signal));
        }
      }
      if(!metadata || metadata.contentType!=='application/pdf' ||
        metadata.metadata?.document_sha256!==snapshot.document_sha256 ||
        metadata.metadata?.source_sha256!==snapshot.source_sha256)throw new ExportError('VALIDATION_FAILED');
      const stored=await step(()=>this.storage.read(path,metadata.generation,signal));
      const pages=await validate(stored,snapshot.canonical_html);
      if(!stored.length || metadata.metadata?.pdf_sha256!==sha256(stored))throw new ExportError('VALIDATION_FAILED');
      await step(()=>this.db.call('finish',{operation,fence,proof:{
        path,generation:String(metadata.generation),pdf_sha256:sha256(stored),
        document_sha256:snapshot.document_sha256,pages,size:stored.length,
        content_type:'application/pdf',created_at:metadata.timeCreated,
      },terminal:false}));
    } catch(error) {
      if(!signal.aborted && error.code!=='STALE_LEASE') {
        try {await step(()=>this.db.call('finish',{operation,fence,proof:null,
          terminal:error.code==='VALIDATION_FAILED'}));} catch { /* Durable recovery owns ambiguity. */ }
      }
    } finally {
      this.clock.clearInterval(timer);this.clock.clearTimeout(deadline);controller.abort();
    }
  }
}
