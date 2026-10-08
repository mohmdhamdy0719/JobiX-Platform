// Operational development tooling only. Never logs credentials or provider bodies.
import {createSign} from 'node:crypto';
export const project='mhflow-jobix',region='me-central1',bucket='mhflow-jobix-dev-pdfs';
// Public project number, verified against the approved bucket's projectNumber.
// Managed Google responses may use this canonical numeric form.
export const projectNumber='850519041397';
export const backend=`jobix-backend-dev@${project}.iam.gserviceaccount.com`;
export const scheduler=`jobix-scheduler-dev@${project}.iam.gserviceaccount.com`;
export class CloudFailure extends Error {
  constructor(status,permission) {super('DEVELOPMENT_CLOUD_OPERATION_REJECTED');this.status=status;this.permission=permission;}
}
export async function google() {
  const key=JSON.parse(process.env.JOBIX_DEV_GCP_DEPLOYER_JSON??'null');
  if(key?.project_id!==project||key.type!=='service_account')throw new CloudFailure(0,'DEV_CREDENTIAL_GUARD');
  const b64=value=>Buffer.from(JSON.stringify(value)).toString('base64url'),now=Math.floor(Date.now()/1000);
  const message=b64({alg:'RS256',typ:'JWT'})+'.'+b64({iss:key.client_email,
    scope:'https://www.googleapis.com/auth/cloud-platform',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+1800});
  const assertion=message+'.'+createSign('RSA-SHA256').update(message).sign(key.private_key,'base64url');
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),signal:AbortSignal.timeout(20000)});
  const auth=await response.json();
  if(!response.ok||!auth.access_token)throw new CloudFailure(response.status,'CREDENTIAL_UNAVAILABLE');
  const hosts=new Set(['storage.googleapis.com','iam.googleapis.com','iamcredentials.googleapis.com',
    'run.googleapis.com','cloudbuild.googleapis.com','artifactregistry.googleapis.com',
    'cloudscheduler.googleapis.com','secretmanager.googleapis.com','serviceusage.googleapis.com']);
  const request=async(url,{method='GET',body,token=auth.access_token,write=false,headers={}}={})=>{
    const target=new URL(url);
    if(target.protocol!=='https:'||!hosts.has(target.hostname)||
      !(target.pathname.includes(project)||target.pathname.includes(bucket)||
        target.pathname.includes(`/projects/${projectNumber}/`)))throw new CloudFailure(0,'DEV_RESOURCE_GUARD');
    const readOnlyPost=/:(testIamPermissions|getIamPolicy|generateAccessToken|generateIdToken|signBlob)$/.test(target.pathname);
    if(method!=='GET'&&!readOnlyPost&&!write)throw new CloudFailure(0,'EXPLICIT_WRITE_REQUIRED');
    const r=await fetch(url,{method,headers:{authorization:'Bearer '+token,
      'content-type':'application/json',...headers},body:body===undefined?undefined:
      body instanceof Uint8Array?body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
    const data=await r.json().catch(()=>({}));
    if(!r.ok) {
      const message=data.error?.message??data.message??(typeof data.error==='string'?data.error:'');
      const permission=message.match(/\b(?:iam|secretmanager|cloudbuild|storage|run|serviceusage)\.[a-zA-Z.]+\b/)?.[0];
      const error=new CloudFailure(r.status,permission);
      // Build requests contain only allowlisted source references/public image
      // names, never environment values, credentials or customer documents.
      if(target.hostname==='cloudbuild.googleapis.com')error.buildReason=message.slice(0,300);
      throw error;
    }
    return data;
  };
  const impersonate=async()=> {
    const data=await request(`https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${backend}:generateAccessToken`,
      {method:'POST',body:{scope:['https://www.googleapis.com/auth/cloud-platform'],lifetime:'900s'}});
    if(!data.accessToken)throw new CloudFailure(0,'IMPERSONATION_UNAVAILABLE');
    return data.accessToken;
  };
  return {request,impersonate,principal:key.client_email};
}
