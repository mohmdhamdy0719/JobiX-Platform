import {gatewayIdentity,workerTarget} from './core.mjs';
import {TransportError} from '../../supabase/functions/resume-export/transport.mjs';
export class GatewayIdentity {
  constructor(target,{fetchImpl=fetch}={}){this.target=workerTarget(target);this.fetchImpl=fetchImpl;}
  async token() {
    if(process.env.GCP_PROJECT_ID!=='mhflow-jobix'||!process.env.K_SERVICE) {
      throw new TransportError('EXPORT_NOT_READY');
    }
    const base='http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/';
    const options={headers:{'Metadata-Flavor':'Google'},redirect:'error',signal:AbortSignal.timeout(5000)};
    const account=await this.fetchImpl(base+'email',options);
    if(!account.ok||(await account.text())!==gatewayIdentity)throw new TransportError('FORBIDDEN');
    const token=await this.fetchImpl(base+'identity?'+new URLSearchParams({
      audience:this.target,format:'full',
    }),{...options,signal:AbortSignal.timeout(5000)});
    if(!token.ok)throw new TransportError('SERVICE_UNAVAILABLE');
    const value=await token.text();
    if(!/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value)) {
      throw new TransportError('SERVICE_UNAVAILABLE');
    }
    return value;
  }
}
