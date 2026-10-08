// Managed development image verification only; no local Docker/Cloud Run start.
import {google,project,region} from './phase3_google.mjs';
if(!process.argv.includes('--verify-managed-development-image')) {
 console.error('EXPLICIT_MANAGED_IMAGE_VERIFICATION_REQUIRED');process.exit(1);
}
const image=process.argv[process.argv.indexOf('--image')+1];
if(!/^me-central1-docker\.pkg\.dev\/mhflow-jobix\/jobix-dev\/pdf-worker@sha256:[0-9a-f]{64}$/.test(image??'')) {
 console.error('APPROVED_DEVELOPMENT_IMAGE_DIGEST_REQUIRED');process.exit(1);
}
// Completely synthetic career source. No database, GCS or runtime secrets are
// used inside the image check. Never print the generated document.
const code=`
import assert from 'node:assert/strict';
import {Canonicalizer,sha256} from './document.mjs';
import {ChromiumRenderer} from './renderer.mjs';
const source={profile:{profile_id:'10000000-0000-4000-8000-000000000001',
 profile_version:1,personal:{full_name:'Fixture العربية',email:'fixture@example.invalid',
 phone:'+20 100 000 0000'},summary:'Community support دعم المجتمع',
 volunteer_experiences:[{id:'10000000-0000-4000-8000-000000000002',version:1,
 organization:'Community مجموعة',role:'Volunteer متطوع',start_month:'2025-01',
 is_current:true,description:'Organized community support and helped families.'}]},
 configuration:{version:1,language:'en',section_visibility:{}}};
const canonical=new Canonicalizer(),renderer=new ChromiumRenderer();
for(const language of ['en','ar']){
 source.configuration.language=language;
 const doc=await canonical.prepare({source,source_sha256:sha256(JSON.stringify(source))});
 assert.deepEqual(doc.issues,[]);
 assert.equal(doc.asset_manifest.font_checksums.length,2);
 const pdf=await renderer.render(doc.html,{signal:AbortSignal.timeout(30000),timeout:25000});
 const pages=await renderer.validate(pdf,doc.html,{signal:AbortSignal.timeout(30000),timeout:25000});
 assert(pages>=1&&pages<=20);
 console.log('PASS: PINNED_IMAGE_CANONICAL_CHROMIUM_FONT_TEXT_PDF_'+language.toUpperCase());
}
let invalid=false;
try{await renderer.validate(Buffer.from('not-pdf'),'<body></body>');}
catch(error){invalid=error.code==='VALIDATION_FAILED';}
assert(invalid);console.log('PASS: PINNED_IMAGE_INVALID_PDF_REJECTION');
`;
const g=await google();
try {
 const r=await g.request(`https://cloudbuild.googleapis.com/v1/projects/${project}/locations/${region}/builds`,
  {method:'POST',write:true,body:{steps:[{name:'gcr.io/cloud-builders/docker',
   args:['run','--rm','--entrypoint','node',image,'--input-type=module','-e',code]}],
   timeout:'600s',tags:['jobix','development','pdf-image-verification']}});
 console.log(JSON.stringify({operation:r.name,image}));
}catch(error){
 console.error(JSON.stringify({check:'MANAGED_IMAGE_VERIFICATION_SUBMISSION_BLOCKED',
 status:error.status,permission:error.permission,reason:error.buildReason}));process.exitCode=1;
}
