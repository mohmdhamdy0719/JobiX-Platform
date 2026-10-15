// Managed Cloud Build only; source archive is explicit and contains no secrets.
import {readFile,readdir} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
import {createHash,randomUUID} from 'node:crypto';
import {google,project,region,bucket} from './phase3_google.mjs';
if(!process.argv.includes('--build-development')) {
  console.error('EXPLICIT_DEVELOPMENT_BUILD_REQUIRED');process.exit(1);
}
const root=resolve(import.meta.dirname,'..');
const gatewayOnly=process.argv.includes('--gateway-only');
const files=gatewayOnly?['.dockerignore']:['.dockerignore','backend/pdf/Dockerfile','backend/pdf/package.json','backend/pdf/pnpm-lock.yaml',
 'supabase/functions/resume-export/transport.mjs',
 'tool/prepare_resume_document.dart','lib/features/career_profile/career_profile.dart',
 'lib/features/career_profile/profile_sections.dart','lib/features/resume/resume_render.dart',
 'lib/features/resume/resume_document.dart','assets/fonts/Inter.ttf','assets/fonts/IBMPlexSansArabic-Regular.ttf',
 'assets/fonts/OFL.txt','assets/fonts/OFL-IBMPlexSansArabic.txt','assets/certs/supabase-root-2021.crt',
 ...(await readdir(resolve(root,'backend/pdf'))).filter(name=>name.endsWith('.mjs')).map(name=>'backend/pdf/'+name)];
const includeGateway=gatewayOnly||process.argv.includes('--include-development-gateway');
if(includeGateway)files.push('backend/export-gateway/Dockerfile',
 'supabase/functions/resume-export/transport.mjs',
 ...(await readdir(resolve(root,'backend/export-gateway'))).filter(name=>name.endsWith('.mjs'))
   .map(name=>'backend/export-gateway/'+name));
// Fixed file list: not git archive, not the workspace or developer config.
const archive=execFileSync('tar',['-czf','-','-C',root,...files],{maxBuffer:16000000});
const hash=createHash('sha256').update(archive).digest('hex');
const image=`${region}-docker.pkg.dev/${project}/jobix-dev/pdf-worker:source-${hash.slice(0,16)}`;
const gatewayImage=`${region}-docker.pkg.dev/${project}/jobix-dev/export-gateway:source-${hash.slice(0,16)}`;
const name=`phase3-builds/${hash}.tar.gz`;
const g=await google();
try {
  let object;
  try {object=await g.request(`https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(name)}`);}
  catch(error) {
    if(error.status!==404)throw error;
    const boundary=randomUUID();
    const body=Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Type: application/json\r\n\r\n`+
      JSON.stringify({name,contentType:'application/gzip',metadata:{purpose:'jobix-phase3-development-build',sha256:hash}})+
      `\r\n--${boundary}\r\nContent-Type: application/gzip\r\n\r\n`),archive,Buffer.from(`\r\n--${boundary}--\r\n`)]);
    object=await g.request(`https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=multipart&ifGenerationMatch=0`,
      {method:'POST',write:true,body,headers:{'content-type':`multipart/related; boundary=${boundary}`}});
  }
  console.log('DEVELOPMENT_ALLOWLISTED_SOURCE_ARCHIVE_UPLOADED');
  const build=await g.request(`https://cloudbuild.googleapis.com/v1/projects/${project}/locations/${region}/builds`,
    {method:'POST',write:true,body:{
      source:{storageSource:{bucket,object:name,generation:String(object.generation)}},
       steps:[...(gatewayOnly?[]:[{name:'gcr.io/cloud-builders/docker',args:['build','-f','backend/pdf/Dockerfile','-t',image,'.']}]),
         ...(includeGateway?[{name:'gcr.io/cloud-builders/docker',
           args:['build','-f','backend/export-gateway/Dockerfile','-t',gatewayImage,'.']}]:[])],
       images:[...(gatewayOnly?[]:[image]),...(includeGateway?[gatewayImage]:[])],timeout:'1800s',tags:['jobix','development','pdf-export'],
    }});
   console.log(JSON.stringify({operation:build.name,buildId:build.metadata?.build?.id,sourceArchiveSha256:hash,
     buildName:build.metadata?.build?.name,...(gatewayOnly?{}:{image}),...(includeGateway?{gatewayImage}:{})}));
}catch(error) {
  // Archive is retained, not deleted under a test-object cleanup authorization.
  console.error(JSON.stringify({operation:'DEVELOPMENT_BUILD_BLOCKED',status:error.status??0,
    permission:error.permission??null,reason:error.buildReason??null}));process.exitCode=1;
}
