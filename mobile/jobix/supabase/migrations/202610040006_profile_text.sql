-- Approved text-editing slice. No providers, charges, rewards, exports or policy edits.
BEGIN;
CREATE COLLATION public.jobix_unicode (provider = icu, locale = 'und', deterministic = true);
ALTER TABLE public.career_profiles
  ADD COLUMN target_role text,
  ADD COLUMN completeness_percent numeric(5,2) NOT NULL DEFAULT 0 CHECK(completeness_percent BETWEEN 0 AND 100),
  ADD COLUMN completeness_algorithm_version text NOT NULL DEFAULT 'core-text-v1';
CREATE TABLE public.profile_summaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL UNIQUE REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  text text,
  version bigint NOT NULL DEFAULT 1,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(text)<=1000)
);
CREATE INDEX ix_summary_profile ON public.profile_summaries(profile_id,sort_order,updated_at);
ALTER TABLE public.profile_summaries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_summaries FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.profile_summaries TO authenticated;
CREATE POLICY summary_owner ON public.profile_summaries FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.career_profiles p JOIN public.users u ON u.id=p.user_id
 WHERE p.id=profile_id AND p.user_id=(SELECT auth.uid()) AND p.status='ACTIVE' AND u.status='ACTIVE'));

CREATE FUNCTION public.jobix_trim(value text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT regexp_replace(coalesce(value,'') COLLATE public.jobix_unicode,'^[[:space:]]+|[[:space:]]+$','','g')
$$;
CREATE FUNCTION public.jobix_meaningful(value text, minimum integer) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT char_length(public.jobix_trim(value))>=minimum
 AND public.jobix_trim(value) COLLATE public.jobix_unicode ~ '[[:alnum:]]'
 AND lower(public.jobix_trim(value) COLLATE public.jobix_unicode)
   NOT IN ('test','asdf','todo','tbd','n/a','example','placeholder','اختبار','مثال','غير متوفر')
 AND lower(public.jobix_trim(value)) NOT LIKE 'lorem ipsum%'
 AND (minimum<20 OR public.jobix_trim(value) !~ '^(.)\1+$')
$$;
CREATE FUNCTION public.jobix_recompute_text_profile(profile uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE points integer:=0; p public.profile_personal_data; s text; role text;
BEGIN
 SELECT * INTO p FROM public.profile_personal_data WHERE profile_id=profile;
 -- Independent Contact contributions, never an all-or-nothing gate.
 IF public.jobix_meaningful(p.full_name,1) AND char_length(p.full_name)<=120 THEN points:=points+5; END IF;
 IF p.email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' AND char_length(p.email)<=254 THEN points:=points+5; END IF;
 IF p.phone ~ '^\+?[0-9 ()-]+$' AND length(regexp_replace(p.phone,'[^0-9]','','g')) BETWEEN 7 AND 15
   AND char_length(p.phone)<=32 THEN points:=points+5; END IF;
 SELECT text INTO s FROM public.profile_summaries WHERE profile_id=profile;
 IF public.jobix_meaningful(s,50) THEN points:=points+10; END IF;
 SELECT target_role INTO role FROM public.career_profiles WHERE id=profile;
 IF public.jobix_meaningful(role,2) THEN points:=points+5; END IF;
 -- Other section tables are not introduced by this slice. They contain no accepted
 -- content yet; their approved weights are added when their vertical slices ship.
 UPDATE public.career_profiles SET completeness_percent=points,
   completeness_algorithm_version='core-text-v1' WHERE id=profile;
END $$;
CREATE FUNCTION public.jobix_contact_score_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN PERFORM public.jobix_recompute_text_profile(NEW.profile_id); RETURN NEW; END $$;
CREATE TRIGGER contact_completeness AFTER INSERT OR UPDATE ON public.profile_personal_data
FOR EACH ROW EXECUTE FUNCTION public.jobix_contact_score_trigger();

CREATE FUNCTION public.jobix_profile_text_snapshot(profile uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('profile_id',p.id,'profile_version',p.profile_version,
   'cv_language',p.cv_language,'personal',to_jsonb(d)-'id'-'profile_id'-'created_at'-'updated_at',
   'summary',coalesce(s.text,''),'target_role',coalesce(p.target_role,''),
   'completeness_percent',p.completeness_percent,
   'summary_state',CASE WHEN coalesce(s.text,'')='' THEN 'UNUSED'
     WHEN public.jobix_meaningful(s.text,50) THEN 'COMPLETE' ELSE 'NEEDS_ATTENTION' END,
   'target_role_state',CASE WHEN coalesce(p.target_role,'')='' THEN 'UNUSED'
     WHEN public.jobix_meaningful(p.target_role,2) THEN 'COMPLETE' ELSE 'NEEDS_ATTENTION' END)
 FROM public.career_profiles p JOIN public.profile_personal_data d ON d.profile_id=p.id
 LEFT JOIN public.profile_summaries s ON s.profile_id=p.id WHERE p.id=profile
$$;
CREATE FUNCTION public.profile_mutate(command_key uuid, requested_profile uuid,
  expected_profile_version bigint, mutation jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); p public.career_profiles; previous public.idempotency_records;
 section text; value text; result jsonb; payload_hash text;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 IF command_key IS NULL OR requested_profile IS NULL OR expected_profile_version IS NULL
   OR mutation IS NULL OR jsonb_typeof(mutation)<>'object'
   OR (mutation-ARRAY['type','section','value'])<>'{}'::jsonb
   OR mutation->>'type' IS DISTINCT FROM 'upsert_item'
   OR mutation->>'section' NOT IN ('summary','target_role')
   OR mutation->>'section' IS NULL
   OR jsonb_typeof(mutation->'value') IS DISTINCT FROM 'object'
   OR ((mutation->'value')-'text')<>'{}'::jsonb
   OR jsonb_typeof(mutation->'value'->'text') IS DISTINCT FROM 'string'
   THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 PERFORM 1 FROM public.users WHERE id=uid AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO p FROM public.career_profiles WHERE id=requested_profile AND user_id=uid AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 payload_hash:=encode(sha256(convert_to(jsonb_build_object('profile',requested_profile,
   'version',expected_profile_version,'mutation',mutation)::text,'UTF8')),'hex');
 SELECT * INTO previous FROM public.idempotency_records
   WHERE user_id=uid AND operation_type='profile.mutate' AND idempotency_key=command_key;
 IF FOUND THEN
   IF previous.payload_hash<>payload_hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
   RETURN previous.response_state;
 END IF;
 IF p.profile_version<>expected_profile_version THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
 section:=mutation->>'section'; value:=public.jobix_trim(mutation->'value'->>'text');
 IF char_length(value)>(CASE WHEN section='summary' THEN 1000 ELSE 200 END) THEN
   RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 IF section='summary' THEN
   INSERT INTO public.profile_summaries(profile_id,text) VALUES(p.id,nullif(value,''))
   ON CONFLICT(profile_id) DO UPDATE SET text=EXCLUDED.text,
     version=public.profile_summaries.version+1,updated_at=now();
 ELSE
   UPDATE public.career_profiles SET target_role=nullif(value,'') WHERE id=p.id;
 END IF;
 PERFORM public.jobix_recompute_text_profile(p.id);
 UPDATE public.career_profiles SET profile_version=profile_version+1,updated_at=now() WHERE id=p.id;
 result:=jsonb_build_object('request_id',command_key,'operation_id',command_key,
   'state','SUCCEEDED','data',public.jobix_profile_text_snapshot(p.id),
   'authoritative_version',p.profile_version+1,'error',NULL);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
   VALUES(uid,'profile.mutate',command_key,payload_hash,result);
 RETURN result;
END $$;
CREATE FUNCTION public.first_career_profile() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE profile uuid; BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE')
   THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT id INTO profile FROM public.career_profiles
   WHERE user_id=auth.uid() AND slot_number=1 AND status='ACTIVE';
 IF profile IS NULL THEN RAISE EXCEPTION 'PROFILE_NOT_PROVISIONED'; END IF;
 RETURN public.jobix_profile_text_snapshot(profile);
END $$;
REVOKE ALL ON FUNCTION public.first_career_profile() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.first_career_profile() TO authenticated;
-- Preserve existing durable Personal Information command keys and hashes.
-- Its public compatibility entry now acknowledges the complete canonical snapshot.
ALTER FUNCTION public.save_personal_information(uuid,uuid,bigint,jsonb,text)
  RENAME TO jobix_legacy_save_personal_information;
REVOKE ALL ON FUNCTION public.jobix_legacy_save_personal_information(uuid,uuid,bigint,jsonb,text)
  FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.save_personal_information(command_key uuid,requested_profile uuid,
 expected_version bigint,personal jsonb,resume_language text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; BEGIN
 result:=public.jobix_legacy_save_personal_information(command_key,requested_profile,expected_version,personal,resume_language);
 IF (SELECT profile_version FROM public.career_profiles WHERE id=requested_profile)
   =(result->>'profile_version')::bigint THEN
   result:=public.jobix_profile_text_snapshot(requested_profile);
   UPDATE public.idempotency_records SET response_state=result
     WHERE user_id=auth.uid() AND operation_type='profile.mutate' AND idempotency_key=command_key;
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.save_personal_information(uuid,uuid,bigint,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_personal_information(uuid,uuid,bigint,jsonb,text) TO authenticated;
REVOKE ALL ON FUNCTION public.jobix_trim(text),public.jobix_meaningful(text,integer),
 public.jobix_recompute_text_profile(uuid),public.jobix_contact_score_trigger(),
 public.jobix_profile_text_snapshot(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb) TO authenticated;
DO $$ DECLARE profile uuid; BEGIN
 FOR profile IN SELECT id FROM public.career_profiles LOOP
   PERFORM public.jobix_recompute_text_profile(profile);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;