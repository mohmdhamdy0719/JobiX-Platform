-- Synthetic disposable PostgreSQL only; never run on Supabase.
DO $test$
DECLARE actor uuid:=gen_random_uuid(); other_actor uuid:=gen_random_uuid(); profile uuid;
 input jsonb; html text:='<html><body>synthetic document</body></html>';
 doc_hash text; request_hash text:=repeat('a',64); command uuid:=gen_random_uuid();
 ack jsonb; again jsonb; job uuid; claimed jsonb; fence uuid; v bigint; before_score jsonb;
 proof jsonb; historical_key uuid:=gen_random_uuid(); config_response jsonb; config_before bigint;
BEGIN
 ASSERT NOT (SELECT enabled FROM public.export_settings);
 INSERT INTO auth.users(id,email) VALUES(actor,'export-'||actor||'@example.invalid'),(other_actor,'other-'||other_actor||'@example.invalid');
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 SELECT id,profile_version INTO profile,v FROM public.career_profiles WHERE user_id=actor;
 UPDATE public.profile_personal_data SET full_name='Synthetic',email='fixture@example.invalid',phone='+20 100 000 0000' WHERE profile_id=profile;
 INSERT INTO public.profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current)
 VALUES(gen_random_uuid(),profile,'Community','Helper','2025-01-01',true);
 input:=public.jobix_export_source(actor,profile);
 ASSERT public.jobix_export_valid(input->'source');
 SELECT jsonb_build_object('score',completeness_percent,'algorithm',completeness_algorithm_version) INTO before_score FROM public.career_profiles WHERE id=profile;
 doc_hash:=encode(sha256(convert_to(html,'UTF8')),'hex');
 BEGIN
  PERFORM public.jobix_export_create(actor,command,gen_random_uuid(),profile,v,0,
   input->>'source_sha256',doc_hash,request_hash,html,'jobix-resume-export-1');
  RAISE EXCEPTION 'disabled gate bypass';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='EXPORT_NOT_READY'; END;
 -- TEST-ONLY gate override, in this disposable transaction.
 UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true;
 ack:=public.jobix_export_create(actor,command,gen_random_uuid(),profile,v,0,
 input->>'source_sha256',doc_hash,request_hash,html,'jobix-resume-export-1');
 job:=(ack->>'operation_id')::uuid;
 ASSERT (public.credit_balance()->>'available')::integer=3;
 ASSERT (SELECT count(*) FROM public.export_jobs WHERE user_id=actor)=1;
 UPDATE public.career_profiles SET profile_version=profile_version+1 WHERE id=profile;
 ASSERT public.jobix_export_create(actor,command,gen_random_uuid(),profile,v,0,
 input->>'source_sha256',doc_hash,request_hash,html,'jobix-resume-export-1')=ack;
 DELETE FROM public.idempotency_records WHERE user_id=actor AND operation_type='export.create';
 ASSERT public.jobix_export_replay(actor,command,request_hash)=ack;
 BEGIN
  PERFORM public.jobix_export_replay(actor,command,repeat('b',64));
  RAISE EXCEPTION 'key misuse accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='IDEMPOTENCY_KEY_REUSE'; END;
 BEGIN
  PERFORM public.jobix_export_status(other_actor,job);
  RAISE EXCEPTION 'other actor accessed';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='NOT_FOUND'; END;
 BEGIN
  PERFORM public.jobix_export_create(actor,gen_random_uuid(),gen_random_uuid(),profile,v,0,
  input->>'source_sha256',doc_hash,request_hash,html,'jobix-resume-export-1');
  RAISE EXCEPTION 'stale version accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='VERSION_CONFLICT'; END;
 ASSERT (SELECT count(*) FROM public.credit_reservations WHERE user_id=actor)=1;
 claimed:=public.jobix_export_claim(2);
 ASSERT jsonb_array_length(claimed)=1;
 fence:=(claimed#>>'{0,lease_token}')::uuid;
 BEGIN
  PERFORM public.jobix_export_heartbeat(job,gen_random_uuid());
  RAISE EXCEPTION 'stale heartbeat accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='STALE_LEASE'; END;
 PERFORM public.jobix_export_stage(job,fence,'GENERATING');
 PERFORM public.jobix_export_stage(job,fence,'UPLOADING');
 proof:=jsonb_build_object('path','exports/'||actor||'/'||job||'/'||(input->>'source_sha256')||'.pdf',
 'generation','1','pdf_sha256',repeat('c',64),'document_sha256',doc_hash,
 'pages',1,'size',100,'content_type','application/pdf','created_at',now());
 BEGIN
  PERFORM public.jobix_export_finish(job,fence,proof||'{"pages":21}',false);
  RAISE EXCEPTION 'oversize completed';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='VALIDATION_FAILED'; END;
 ASSERT (public.credit_balance()->>'finalized')::integer=5 OR
 (SELECT finalized_balance FROM public.credit_accounts WHERE user_id=actor)=5;
 ASSERT public.jobix_export_finish(job,fence,proof,false)='COMPLETED';
 ASSERT public.jobix_export_finish(job,fence,proof,false)='COMPLETED';
 ASSERT (SELECT count(*) FROM public.credit_transactions WHERE user_id=actor AND delta=-2)=1;
 ASSERT (public.credit_balance()->>'available')::integer=3;
 PERFORM public.jobix_export_status(actor,job);
 ASSERT (public.credit_balance()->>'available')::integer=3;
 ASSERT (SELECT source#>>'{profile,profile_version}' FROM public.export_snapshots WHERE id=(ack#>>'{data,snapshot_id}')::uuid)=v::text;
 BEGIN
  UPDATE public.export_snapshots SET canonical_html='changed' WHERE id=(ack#>>'{data,snapshot_id}')::uuid;
  RAISE EXCEPTION 'mutable snapshot';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='INVALID_STATE'; END;
 PERFORM public.jobix_export_missing(actor,job,'1');
 ASSERT public.jobix_export_status(actor,job)->>'state'='MISSING_OBJECT';
 ASSERT (public.credit_balance()->>'available')::integer=3;
 -- The lifecycle fixture tests a second independent export; move its synthetic
 -- accepted event outside every rolling window rather than bypassing admission.
 UPDATE public.export_admission_events SET accepted_at=now()-interval '8 days'
 WHERE user_id=actor;
 input:=public.jobix_export_source(actor,profile);
 v:=(input#>>'{source,profile,profile_version}')::bigint;
 again:=public.jobix_export_create(actor,gen_random_uuid(),gen_random_uuid(),profile,v,0,
 input->>'source_sha256',doc_hash,repeat('d',64),html,'jobix-resume-export-1',job);
 job:=(again->>'operation_id')::uuid;
 ASSERT (public.credit_balance()->>'available')::integer=1;
 UPDATE public.export_jobs SET deadline=now()-interval '1 second' WHERE id=job;
 PERFORM public.jobix_export_recover();
 PERFORM public.jobix_export_recover();
 ASSERT public.jobix_export_status(actor,job)->>'state'='FAILED';
 ASSERT (public.credit_balance()->>'available')::integer=3;
 ASSERT (SELECT count(*) FROM public.credit_transactions WHERE user_id=actor AND delta=-2)=1;
 ASSERT NOT has_function_privilege('authenticated','public.jobix_export_source(uuid,uuid)','EXECUTE');
 ASSERT NOT has_function_privilege('service_role','public.jobix_export_finish(uuid,uuid,jsonb,boolean)','EXECUTE');
 ASSERT NOT has_table_privilege('jobix_export_worker','public.credit_transactions','UPDATE');
 ASSERT NOT has_table_privilege('authenticated','public.export_jobs','INSERT');
 config_response:=public.save_resume_configuration(historical_key,profile,0,'ar','resume_ats_ar_v1');
 ASSERT (SELECT profile_version FROM public.career_profiles WHERE id=profile)=v+1;
 ASSERT public.save_resume_configuration(historical_key,profile,0,'ar','resume_ats_ar_v1')=config_response;
 ASSERT (SELECT profile_version FROM public.career_profiles WHERE id=profile)=v+1;
 config_response:=public.save_resume_presentation(gen_random_uuid(),profile,v+1,1,'ar','["volunteer"]');
 ASSERT config_response#>>'{section_visibility,volunteer}'='false';
 ASSERT NOT public.jobix_export_valid(public.jobix_export_source(actor,profile)->'source');
 ASSERT (SELECT jsonb_build_object('score',completeness_percent,'algorithm',completeness_algorithm_version) FROM public.career_profiles WHERE id=profile)=before_score;
 ASSERT NOT EXISTS(SELECT FROM public.ai_allowance_accounts WHERE user_id=actor);
 UPDATE public.export_settings SET enabled=false,deletion_policy_approved=false;
END $test$;
