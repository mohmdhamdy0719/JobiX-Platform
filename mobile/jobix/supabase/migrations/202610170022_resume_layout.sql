-- Local implementation only. Separate approval required before live application.
-- Reuse existing profile-scoped columns; preserve historical RPCs and ACKs.
BEGIN;
CREATE FUNCTION public.save_resume_layout(
 command_key uuid, requested_profile uuid, expected_profile_version bigint,
 expected_configuration_version bigint, language text, hidden_sections jsonb,
 section_order jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 p public.career_profiles; current_version bigint; hash text;
 old public.idempotency_records; result jsonb; visibility jsonb;
 allowed constant jsonb := '["summary","target_role","experience","volunteer","education","certification","achievement","project","skill","language"]';
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO p FROM public.career_profiles
 WHERE id=requested_profile AND user_id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 IF command_key IS NULL OR language IS NULL OR language NOT IN ('en','ar')
 OR jsonb_typeof(hidden_sections) IS DISTINCT FROM 'array'
 OR jsonb_typeof(section_order) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 IF jsonb_array_length(section_order) <> 10 OR
 (SELECT count(DISTINCT value) FROM jsonb_array_elements(section_order)) <> 10 OR
 EXISTS(SELECT FROM jsonb_array_elements(section_order) x(value)
   WHERE jsonb_typeof(value) <> 'string' OR NOT allowed @> jsonb_build_array(value)) OR
 EXISTS(SELECT FROM jsonb_array_elements(hidden_sections) x(value)
   WHERE jsonb_typeof(value) <> 'string' OR NOT allowed @> jsonb_build_array(value)) THEN
  RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 hash:=encode(sha256(convert_to(jsonb_build_array(requested_profile,
   expected_profile_version,expected_configuration_version,language,
   hidden_sections,section_order)::text,'UTF8')),'hex');
 SELECT * INTO old FROM public.idempotency_records WHERE user_id=auth.uid()
 AND operation_type='resume.layout' AND idempotency_key=command_key;
 IF FOUND THEN
  IF hash <> old.payload_hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
  RETURN old.response_state;
 END IF;
 SELECT version INTO current_version FROM public.resume_configurations
 WHERE profile_id=requested_profile;
 IF p.profile_version IS DISTINCT FROM expected_profile_version OR
 coalesce(current_version,0) IS DISTINCT FROM expected_configuration_version THEN
  RAISE EXCEPTION 'VERSION_CONFLICT';
 END IF;
 SELECT coalesce(jsonb_object_agg(x#>>'{}',false),'{}') INTO visibility
 FROM jsonb_array_elements(hidden_sections) x;
 INSERT INTO public.resume_configurations AS cfg
 (profile_id,language,template_id,section_visibility,section_order,
  render_config_version,template_version)
 VALUES(requested_profile,language,'resume_ats_'||language||'_v1',visibility,
  section_order,'export-layout-v1',3)
 ON CONFLICT(profile_id) DO UPDATE SET language=EXCLUDED.language,
 template_id=EXCLUDED.template_id,section_visibility=EXCLUDED.section_visibility,
 section_order=EXCLUDED.section_order,render_config_version=EXCLUDED.render_config_version,
 template_version=EXCLUDED.template_version,version=cfg.version+1,updated_at=now();
 UPDATE public.career_profiles SET profile_version=profile_version+1,updated_at=now()
 WHERE id=requested_profile;
 result:=public.read_resume_configuration(requested_profile);
 INSERT INTO public.idempotency_records
 (user_id,operation_type,idempotency_key,payload_hash,response_state)
 VALUES(auth.uid(),'resume.layout',command_key,hash,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)
 FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)
 TO authenticated;
COMMENT ON FUNCTION public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)
 IS 'Owner-scoped versioned layout; no profile content, Credit, export or policy mutation.';
COMMIT;
