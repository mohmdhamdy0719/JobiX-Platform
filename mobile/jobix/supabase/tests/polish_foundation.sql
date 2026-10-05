DO $test$
DECLARE uid uuid:=gen_random_uuid(); profile uuid; v bigint; response jsonb;
 command uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid(); reservation jsonb; balance jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(uid,'polish-'||uid||'@example.invalid');
 PERFORM set_config('request.jwt.claim.sub',uid::text,true);
 SELECT id,profile_version INTO profile,v FROM public.career_profiles WHERE user_id=uid;
 ASSERT profile IS NOT NULL;
 ASSERT (public.credit_balance()->>'available')::integer=5;
 BEGIN
  PERFORM public.profile_mutate(gen_random_uuid(),profile,v,
    jsonb_build_object('type','upsert_item','section','experience','value',jsonb_build_object('id',gen_random_uuid(),'job_title','Role')));
  RAISE EXCEPTION 'assertion: required field accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF;
 END;
 response:=public.save_profile_extras(command,profile,v,jsonb_build_object(
 'links',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'label','Website','url','example.com')),
 'photo_base64',NULL,'photo_mime',NULL));
 ASSERT response->>'state'='SUCCEEDED';
 ASSERT public.read_profile_extras(profile)#>>'{links,0,url}'='https://example.com';
 ASSERT (response#>>'{data,profile_version}')::bigint=v+1;
 BEGIN
  PERFORM public.save_profile_extras(gen_random_uuid(),profile,v,
    jsonb_build_object('links','[]'::jsonb,'photo_base64',NULL,'photo_mime',NULL));
  RAISE EXCEPTION 'assertion: stale extras accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'VERSION_CONFLICT' THEN RAISE; END IF;
 END;
 response:=public.save_resume_configuration(gen_random_uuid(),profile,0,'ar','resume_ats_ar_v1');
 ASSERT response->>'language'='ar';
 ASSERT (SELECT count(*) FROM public.career_profiles WHERE user_id=uid)=1;
 ASSERT public.ai_allowance()->>'limit'='6';
 ASSERT public.ai_allowance()->>'used'='0';
 ASSERT public.ai_allowance()->>'generation_enabled'='false';
 reservation:=public.reserve_resume_credits(uid,operation);
 ASSERT (public.credit_balance()->>'available')::integer=3;
 ASSERT public.reserve_resume_credits(uid,operation)->>'id'=reservation->>'id';
 ASSERT public.finish_resume_credits(operation,(reservation->>'fencing_token')::uuid,false)='RELEASED';
 ASSERT public.finish_resume_credits(operation,(reservation->>'fencing_token')::uuid,false)='RELEASED';
 ASSERT (public.credit_balance()->>'available')::integer=5;
 operation:=gen_random_uuid();
 reservation:=public.reserve_resume_credits(uid,operation);
 ASSERT public.finish_resume_credits(operation,(reservation->>'fencing_token')::uuid,true)='CONSUMED';
 ASSERT public.finish_resume_credits(operation,(reservation->>'fencing_token')::uuid,true)='CONSUMED';
 ASSERT (public.credit_balance()->>'available')::integer=3;
 ASSERT (SELECT count(*) FROM public.credit_transactions WHERE user_id=uid AND delta=-2)=1;
 ASSERT NOT has_function_privilege('authenticated','public.reserve_resume_credits(uuid,uuid)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.finish_resume_credits(uuid,uuid,boolean)','EXECUTE');
 ASSERT NOT has_table_privilege('anon','public.profile_extras','SELECT');
 ASSERT NOT has_table_privilege('authenticated','public.profile_extras','UPDATE');
 PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 BEGIN
  PERFORM public.read_profile_extras(profile);
  RAISE EXCEPTION 'assertion: foreign extras read';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'FORBIDDEN' THEN RAISE; END IF;
 END;
END $test$;
