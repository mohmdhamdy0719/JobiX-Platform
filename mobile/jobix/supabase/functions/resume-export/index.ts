// Not deployed. Public gateway verifies Supabase identity; no service-role key.
const project = 'lmouxhbjhtqdtiqijcee';
const account = 'jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com';
const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');

async function identityToken(audience: string): Promise<string> {
  // Optional credential-backed transport, NOT enabled/provisioned by this source.
  // Keyless provider can replace this function after actual owner-approved setup.
  const raw = Deno.env.get('JOBIX_EXPORT_GATEWAY_IDENTITY_JSON');
  if (!raw) throw new Error('EXPORT_NOT_READY');
  const key = JSON.parse(raw);
  if (key.project_id !== 'mhflow-jobix' || key.client_email !== account) throw new Error('FORBIDDEN');
  const pem = key.private_key.replace(/-----[^-]+-----|\s/g,'');
  const signingKey = await crypto.subtle.importKey('pkcs8',
    Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),
    {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const now = Math.floor(Date.now()/1000);
  const encoder = new TextEncoder();
  const unsigned = [
    {alg:'RS256',typ:'JWT'},
    {iss:account,aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+600,target_audience:audience},
  ].map(v=>base64url(encoder.encode(JSON.stringify(v)))).join('.');
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',
    signingKey,encoder.encode(unsigned)));
  const response = await fetch('https://oauth2.googleapis.com/token',{
    method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion:unsigned+'.'+base64url(signature)}),
  });
  if (!response.ok) throw new Error('SERVICE_UNAVAILABLE');
  const token = (await response.json()).id_token;
  if (!token) throw new Error('SERVICE_UNAVAILABLE');
  return token;
}

Deno.serve(async request => {
  const headers = {'Content-Type':'application/json','Cache-Control':'no-store'};
  try {
    if (Deno.env.get('JOBIX_EXPORT_ENABLED') !== 'true' ||
        Deno.env.get('JOBIX_EXPORT_DELETION_POLICY_APPROVED') !== 'true') {
      throw new Error('EXPORT_NOT_READY');
    }
    if (request.method !== 'POST') throw new Error('FORBIDDEN');
    const token = request.headers.get('Authorization');
    if (!token?.startsWith('Bearer ')) throw new Error('AUTH_REQUIRED');
    const origin = Deno.env.get('SUPABASE_URL');
    if (origin !== `https://${project}.supabase.co`) throw new Error('FORBIDDEN');
    const userResponse = await fetch(origin+'/auth/v1/user',{
      headers:{Authorization:token,apikey:Deno.env.get('SUPABASE_ANON_KEY')??''},
      redirect:'error',signal:AbortSignal.timeout(15000),
    });
    if (!userResponse.ok) throw new Error('AUTH_REQUIRED');
    const user = await userResponse.json();
    const bodyText = await request.text();
    if (new TextEncoder().encode(bodyText).length>32000) throw new Error('VALIDATION_FAILED');
    const body = JSON.parse(bodyText);
    const target = Deno.env.get('JOBIX_DEV_EXPORT_WORKER_URL')??'';
    const url = new URL(target);
    if (url.protocol!=='https:' || !url.hostname.endsWith('.run.app') || url.search ||
        url.username || url.password) throw new Error('EXPORT_NOT_READY');
    const response = await fetch(target.replace(/\/$/,'')+'/command',{
      method:'POST',redirect:'error',signal:AbortSignal.timeout(45000),
      headers:{Authorization:'Bearer '+await identityToken(target),'Content-Type':'application/json'},
      // Caller-supplied actor/user_id cannot override verified Supabase identity.
      body:JSON.stringify({actor:user.id,action:body.action,command:body.command}),
    });
    return new Response(await response.text(),{status:response.status,headers});
  } catch(error) {
    const allowed = ['EXPORT_NOT_READY','FORBIDDEN','AUTH_REQUIRED','VALIDATION_FAILED'];
    const code = error instanceof Error && allowed.includes(error.message)
      ? error.message : 'SERVICE_UNAVAILABLE';
    return new Response(JSON.stringify({data:null,error:{code}}),
      {status:code==='AUTH_REQUIRED'?401:503,headers});
  }
});
