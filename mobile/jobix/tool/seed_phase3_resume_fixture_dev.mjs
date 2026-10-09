// Explicitly approved fictional data, account A only, normal authenticated saves.
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
const cfg=JSON.parse(await readFile('mobile/jobix/config/dev.local.json','utf8'));
if(!process.argv.includes('--approved-fictional-profile-a')||
  cfg.APP_ENV!=='dev'||cfg.SUPABASE_URL!=='https://lmouxhbjhtqdtiqijcee.supabase.co') {
  throw Error('EXPLICIT_DEVELOPMENT_PROFILE_APPROVAL_REQUIRED');
}
let token,stage='login';
async function rpc(name,body={}) {
  const r=await fetch(cfg.SUPABASE_URL+'/rest/v1/rpc/'+name,{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},
    body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
  const data=await r.json();
  if(!r.ok){const e=Error('PROFILE_SAVE_REJECTED');e.status=r.status;
    e.code=/^[A-Z_]{3,70}$/.test(data?.message??'')?data.message:'SUPPRESSED';throw e;}
  return data;
}
try {
  const login=await fetch(cfg.SUPABASE_URL+'/auth/v1/token?grant_type=password',{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,'Content-Type':'application/json'},
    body:JSON.stringify({email:process.env.JOBIX_DEV_TEST_EMAIL_A,password:process.env.JOBIX_DEV_TEST_PASSWORD_A})});
  const session=await login.json();if(!login.ok||!session.access_token)throw Error('AUTH_FAILED');
  token=session.access_token;
  let p=await rpc('first_career_profile');
  p.id=p.profile_id??p.id;
  if(!p?.id||!Number.isSafeInteger(p.profile_version))throw Error('PROFILE_SHAPE_INVALID');
  const saves=[
    ['personal',{personal:{full_name:'Omar Nabil (Fictional Test)',email:'omar.nabil.test@example.invalid',
      phone:'+1 202 555 0147',country:'United States',city:'Washington, DC',
      linkedin_url:'',github_url:'',portfolio_url:''},resume_language:'en'}],
    ['target_role',{text:'Community Operations Coordinator'}],
    ['summary',{text:'Organized community operations coordinator with experience supporting volunteer programs, maintaining clear schedules and preparing practical reporting tools. Skilled in team coordination, spreadsheet analysis and participant communication. This fictional profile is used only to verify the JobiX development resume export.'}],
    ['volunteer',{id:randomUUID(),organization:'Example Community Hub (Fictional)',
      role:'Volunteer Program Coordinator',location:'Washington, DC',start_month:'2025-01',
      end_month:'',is_current:true,description:'Coordinated weekly activities for a fictional community program.\nMaintained volunteer schedules and prepared clear participation reports.\nSupported event logistics and communicated updates to the team.'}],
    ['education',{id:randomUUID(),degree:'Bachelor of Business Administration',
      institution:'Example State University (Fictional)',field_of_study:'Operations Management',
      start_month:'2017-09',end_month:'2021-06',is_current:false,
      description:'Completed a fictional program covering operations planning, business communication and practical data analysis.'}],
    ...['Program Coordination','Spreadsheet Analysis','Event Planning','Team Communication']
      .map(name=>['skill',{id:randomUUID(),name}]),
    ['language',{id:randomUUID(),name:'English',proficiency:'FLUENT'}],
  ];
  for(const [section,value]of saves) {
    stage='save_'+section;
    const ack=await rpc('profile_mutate',{command_key:randomUUID(),requested_profile:p.id,
      expected_profile_version:p.profile_version,mutation:{type:'upsert_item',section,value}});
    if(ack.state!=='SUCCEEDED'||!ack.data)throw Error('SAVE_NOT_ACKNOWLEDGED');
    p=ack.data;
    p.id=p.profile_id??p.id;
    console.log(JSON.stringify({section,saved:true,profileVersion:p.profile_version}));
  }
  stage='structural_export_check';
  const r=await fetch(cfg.SUPABASE_URL+'/functions/v1/resume-export',{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},
    body:JSON.stringify({action:'document',command:{profile_id:p.id}}),signal:AbortSignal.timeout(65000)});
  const body=await r.json();
  const issues=body.data?.issues;
  console.log(JSON.stringify({status:r.status,structuralIssues:issues,creditsChanged:false,
    normalProfileScoring:true,fictionalDataRetained:true}));
  if(r.status!==200||!Array.isArray(issues)||issues.length)throw Error('STRUCTURAL_EXPORT_NOT_READY');
}catch(e){console.error(JSON.stringify({stage,code:e.code??e.message,status:e.status??null}));process.exitCode=1;}
finally {
  if(token)await fetch(cfg.SUPABASE_URL+'/auth/v1/logout?scope=local',{method:'POST',
    headers:{apikey:cfg.SUPABASE_CLIENT_KEY,Authorization:'Bearer '+token}}).catch(()=>{process.exitCode=1;});
}
