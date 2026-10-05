BEGIN;
CREATE TABLE public.resume_configurations (
 profile_id uuid PRIMARY KEY REFERENCES public.career_profiles(id) ON DELETE CASCADE,
 language text NOT NULL CHECK(language IN ('en','ar')),
 template_id text NOT NULL CHECK(template_id IN ('resume_ats_en_v1','resume_ats_ar_v1')),
 version bigint NOT NULL DEFAULT 1,
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(template_id='resume_ats_'||language||'_v1')
);
ALTER TABLE public.resume_configurations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.resume_configurations FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.read_resume_configuration(requested_profile uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.read_profile_extras(requested_profile);
 RETURN (SELECT to_jsonb(c)-'updated_at' FROM public.resume_configurations c WHERE profile_id=requested_profile);
END $$;
CREATE FUNCTION public.save_resume_configuration(command_key uuid,requested_profile uuid,
 expected_version bigint,language text,template_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE current_version bigint; hash text; old public.idempotency_records; result jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 PERFORM 1 FROM public.career_profiles WHERE id=requested_profile
 AND user_id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 IF command_key IS NULL OR language IS NULL OR language NOT IN ('en','ar')
 OR template_id IS DISTINCT FROM 'resume_ats_'||language||'_v1'
 OR expected_version IS NULL THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 hash:=encode(sha256(convert_to(jsonb_build_array(requested_profile,expected_version,
 language,template_id)::text,'UTF8')),'hex');
 SELECT * INTO old FROM public.idempotency_records WHERE user_id=auth.uid()
 AND operation_type='resume.configure' AND idempotency_key=command_key;
 IF FOUND THEN
  IF old.payload_hash<>hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
  RETURN old.response_state;
 END IF;
 SELECT c.version INTO current_version FROM public.resume_configurations c WHERE c.profile_id=requested_profile;
 IF coalesce(current_version,0)<>expected_version THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
 INSERT INTO public.resume_configurations(profile_id,language,template_id)
 VALUES(requested_profile,language,template_id) ON CONFLICT(profile_id) DO UPDATE
 SET language=EXCLUDED.language,template_id=EXCLUDED.template_id,
 version=public.resume_configurations.version+1,updated_at=now();
 result:=public.read_resume_configuration(requested_profile);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
 VALUES(auth.uid(),'resume.configure',command_key,hash,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.read_resume_configuration(uuid),
 public.save_resume_configuration(uuid,uuid,bigint,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.read_resume_configuration(uuid),
 public.save_resume_configuration(uuid,uuid,bigint,text,text) TO authenticated;
COMMIT;
