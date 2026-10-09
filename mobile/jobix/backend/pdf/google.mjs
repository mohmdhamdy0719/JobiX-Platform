import {createHash,randomUUID,createPublicKey,verify} from 'node:crypto';
import {ExportError} from './document.mjs';
const backend='jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com';
const scheduler='jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com';
const bridge='jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com';
const encode=value=>encodeURIComponent(value).replace(/[!'()*]/g,c=>'%'+c.charCodeAt(0).toString(16).toUpperCase());
const digest=value=>createHash('sha256').update(value).digest('hex');
// Private evidence, minted only by this adapter for its exact physical attempt.
// Error properties/status codes alone cannot authorize flight settlement.
const noWriteEvidence=new WeakMap();
export function isDefinitiveUploadRejection(error,path,fence) {
  const evidence=noWriteEvidence.get(error);
  return !!evidence&&evidence.path===path&&evidence.fence===fence;
}
function rejectedUpload(code,path,metadata,status) {
  const error=new ExportError(code);
  if(status)error.httpStatus=status;
  if(/^[0-9a-f-]{36}$/i.test(metadata.upload_fence??'')) {
    noWriteEvidence.set(error,{path,fence:metadata.upload_fence});
  }
  return error;
}
async function checked(url,options={}) {
  const response=await fetch(url,{...options,redirect:'error',
    signal:options.signal??AbortSignal.timeout(30000)});
  if(response.status===404)return null;
  if([409,412].includes(response.status))throw new ExportError('OBJECT_EXISTS');
  if(!response.ok)throw new ExportError('SERVICE_UNAVAILABLE');
  return response;
}
export class RuntimeIdentity {
  async token() {
    if(!process.env.K_SERVICE || process.env.GCP_PROJECT_ID!=='mhflow-jobix') {
      throw new ExportError('EXPORT_NOT_READY');
    }
    const base='http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/';
    const headers={'Metadata-Flavor':'Google'};
    const account=await checked(base+'email',{headers});
    if(!account || (await account.text())!==backend)throw new ExportError('FORBIDDEN');
    const response=await checked(base+'token',{headers});
    const token=(await response.json()).access_token;
    if(!token)throw new ExportError('FORBIDDEN');
    return token;
  }
}
export class GoogleStorage {
  constructor(identity=new RuntimeIdentity()) {
    this.identity=identity;this.bucket='mhflow-jobix-dev-pdfs';
  }
  async headers() {return {Authorization:'Bearer '+await this.identity.token()};}
  url(path,generation,media=false) {
    const params=new URLSearchParams();
    if(generation)params.set('generation',String(generation));
    if(media)params.set('alt','media');
    return `https://storage.googleapis.com/storage/v1/b/${this.bucket}/o/${encode(path)}?${params}`;
  }
  async inspect(path,generation,signal) {
    const response=await checked(this.url(path,generation),{headers:await this.headers(),signal});
    return response?response.json():null;
  }
  async read(path,generation,signal) {
    const response=await checked(this.url(path,generation,true),{headers:await this.headers(),signal});
    if(!response)throw new ExportError('EXPORT_OBJECT_MISSING');
    return Buffer.from(await response.arrayBuffer());
  }
  async remove(path,generation) {
    if(!/^[1-9][0-9]*$/.test(String(generation)))throw new ExportError('VALIDATION_FAILED');
    await checked(this.url(path,generation)+'&ifGenerationMatch='+generation,
      {method:'DELETE',headers:await this.headers()});
  }
  async listPrefix(prefix) {
    if(!/^exports\/[0-9a-f-]{36}\/(?:[0-9a-f-]{36}\/)?$/.test(prefix))throw new ExportError('FORBIDDEN');
    const objects=[];let pageToken;
    do {
      const query=new URLSearchParams({prefix,maxResults:'1000'});
      if(pageToken)query.set('pageToken',pageToken);
      const response=await checked(`https://storage.googleapis.com/storage/v1/b/${this.bucket}/o?${query}`,
        {headers:await this.headers()});
      const page=await response.json();
      objects.push(...(page.items??[]));pageToken=page.nextPageToken;
    } while(pageToken);
    return objects;
  }
  async create(path,pdf,metadata,signal) {
    const attempt={upload_fence:metadata.upload_fence};
    const boundary=randomUUID();
    const body=Buffer.concat([Buffer.from(
      `--${boundary}\r\nContent-Type: application/json\r\n\r\n`+
      JSON.stringify({name:path,contentType:'application/pdf',metadata})+
      `\r\n--${boundary}\r\nContent-Type: application/pdf\r\n\r\n`),
      pdf,Buffer.from(`\r\n--${boundary}--\r\n`)]);
    let headers;
    try {headers=await this.headers();}
    catch {throw rejectedUpload('UPLOAD_NOT_SENT',path,attempt);}
    const response=await fetch(`https://storage.googleapis.com/upload/storage/v1/b/${this.bucket}/o?uploadType=multipart&ifGenerationMatch=0`,
      {method:'POST',headers:{...headers,'Content-Type':`multipart/related; boundary=${boundary}`},
        body,redirect:'error',signal:signal??AbortSignal.timeout(30000)});
    if([409,412].includes(response.status))throw new ExportError('OBJECT_EXISTS');
    if(!response.ok) {
      // Authentication/authorization denial means this exact request did not
      // create an object. Never infer that from 408/429/5xx, missing objects,
      // elapsed time, transport exceptions or a lost success body.
      if([401,403].includes(response.status)) {
        throw rejectedUpload('UPLOAD_HTTP_'+response.status,path,attempt,response.status);
      }
      const error=new ExportError('UPLOAD_HTTP_'+response.status);
      error.httpStatus=response.status;
      throw error;
    }
    return response.json();
  }
  async sign(path,generation,ttl) {
    if(!Number.isInteger(ttl)||ttl<1||ttl>600)throw new ExportError('VALIDATION_FAILED');
    const stamp=new Date().toISOString().replace(/[-:]|\.\d{3}/g,'');
    const scope=stamp.slice(0,8)+'/auto/storage/goog4_request';
    const pairs=Object.entries({
      'X-Goog-Algorithm':'GOOG4-RSA-SHA256','X-Goog-Credential':backend+'/'+scope,
      'X-Goog-Date':stamp,'X-Goog-Expires':String(ttl),'X-Goog-SignedHeaders':'host',
      generation:String(generation),
    }).map(([k,v])=>[encode(k),encode(v)]).sort(([a],[b])=>a<b?-1:a>b?1:0);
    const query=pairs.map(([k,v])=>k+'='+v).join('&');
    const uri='/'+this.bucket+'/'+path.split('/').map(encode).join('/');
    const request=`GET\n${uri}\n${query}\nhost:storage.googleapis.com\n\nhost\nUNSIGNED-PAYLOAD`;
    const signing=`GOOG4-RSA-SHA256\n${stamp}\n${scope}\n${digest(request)}`;
    const response=await checked('https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/'+backend+':signBlob',
      {method:'POST',headers:{...await this.headers(),'Content-Type':'application/json'},
        body:JSON.stringify({payload:Buffer.from(signing).toString('base64')})});
    const signature=(await response.json()).signedBlob;
    if(!signature)throw new ExportError('SERVICE_UNAVAILABLE');
    return `https://storage.googleapis.com${uri}?${query}&X-Goog-Signature=${Buffer.from(signature,'base64').toString('hex')}`;
  }
}
let keys,keysUntil=0;
export async function authenticateInternal(header,audience) {
  try {
    if(!audience || !header?.startsWith('Bearer '))throw new Error();
    const jwt=header.slice(7);const parts=jwt.split('.');
    if(parts.length!==3)throw new Error();
    const head=JSON.parse(Buffer.from(parts[0],'base64url'));
    const claims=JSON.parse(Buffer.from(parts[1],'base64url'));
    if(head.alg!=='RS256' || !['https://accounts.google.com','accounts.google.com'].includes(claims.iss) ||
      claims.aud!==audience || claims.exp<=Date.now()/1000 || claims.iat>Date.now()/1000+60 ||
      claims.email_verified!==true || ![backend,scheduler,bridge].includes(claims.email))throw new Error();
    if(Date.now()>keysUntil) {
      keys=(await (await checked('https://www.googleapis.com/oauth2/v3/certs')).json()).keys;
      keysUntil=Date.now()+300000;
    }
    const key=keys.find(k=>k.kid===head.kid);
    if(!key || !verify('RSA-SHA256',Buffer.from(parts[0]+'.'+parts[1]),
      createPublicKey({key,format:'jwk'}),Buffer.from(parts[2],'base64url')))throw new Error();
    return claims.email;
  } catch {throw new ExportError('FORBIDDEN');}
}
