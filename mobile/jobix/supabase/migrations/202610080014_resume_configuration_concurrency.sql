BEGIN;
-- Historical acknowledgement is retained verbatim. No scoring/latch writes.
ALTER FUNCTION public.save_resume_configuration(uuid,uuid,bigint,text,text)
 RENAME TO save_resume_configuration_pre_export;
REVOKE ALL ON FUNCTION public.save_resume_configuration_pre_export(uuid,uuid,bigint,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.save_resume_configuration(command_key uuid,requested_profile uuid,
 expected_version bigint,language text,template_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE replay boolean; result jsonb;
BEGIN
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 PERFORM 1 FROM public.career_profiles WHERE id=requested_profile AND user_id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 SELECT EXISTS(SELECT FROM public.idempotency_records WHERE user_id=auth.uid()
 AND operation_type='resume.configure' AND idempotency_key=command_key) INTO replay;
 result:=public.save_resume_configuration_pre_export(command_key,requested_profile,expected_version,language,template_id);
 IF NOT replay THEN UPDATE public.career_profiles SET profile_version=profile_version+1,updated_at=now() WHERE id=requested_profile; END IF;
 RETURN result;
END $$;
CREATE FUNCTION public.save_resume_presentation(command_key uuid,requested_profile uuid,
 expected_profile_version bigint,expected_configuration_version bigint,language text,hidden_sections jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.career_profiles; current_version bigint; hash text; old public.idempotency_records; result jsonb; visibility jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO p FROM public.career_profiles WHERE id=requested_profile AND user_id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 IF command_key IS NULL OR language NOT IN ('en','ar') OR language IS NULL
 OR jsonb_typeof(hidden_sections) IS DISTINCT FROM 'array' OR
 EXISTS(SELECT FROM jsonb_array_elements(hidden_sections) x WHERE jsonb_typeof(x)<>'string' OR
 x#>>'{}' NOT IN ('summary','target_role','experience','volunteer','education','certification','achievement','project','skill','language'))
 THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 hash:=encode(sha256(convert_to(jsonb_build_array(requested_profile,expected_profile_version,
 expected_configuration_version,language,hidden_sections)::text,'UTF8')),'hex');
 SELECT * INTO old FROM public.idempotency_records WHERE user_id=auth.uid()
 AND operation_type='resume.presentation' AND idempotency_key=command_key;
 IF FOUND THEN
  IF hash<>old.payload_hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
  RETURN old.response_state;
 END IF;
 SELECT version INTO current_version FROM public.resume_configurations WHERE profile_id=requested_profile;
 IF p.profile_version IS DISTINCT FROM expected_profile_version OR coalesce(current_version,0) IS DISTINCT FROM expected_configuration_version THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
 SELECT coalesce(jsonb_object_agg(x#>>'{}',false),'{}') INTO visibility FROM jsonb_array_elements(hidden_sections) x;
 INSERT INTO public.resume_configurations(profile_id,language,template_id,section_visibility)
 VALUES(requested_profile,language,'resume_ats_'||language||'_v1',visibility)
 ON CONFLICT(profile_id) DO UPDATE SET language=EXCLUDED.language,template_id=EXCLUDED.template_id,
 section_visibility=EXCLUDED.section_visibility,version=public.resume_configurations.version+1,updated_at=now();
 UPDATE public.career_profiles SET profile_version=profile_version+1,updated_at=now() WHERE id=requested_profile;
 result:=public.read_resume_configuration(requested_profile);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
 VALUES(auth.uid(),'resume.presentation',command_key,hash,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.save_resume_configuration(uuid,uuid,bigint,text,text),
 public.save_resume_presentation(uuid,uuid,bigint,bigint,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_resume_configuration(uuid,uuid,bigint,text,text),
 public.save_resume_presentation(uuid,uuid,bigint,bigint,text,jsonb) TO authenticated;
COMMIT;
