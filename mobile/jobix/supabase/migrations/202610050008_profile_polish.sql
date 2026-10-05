BEGIN;
-- Keep old command acknowledgements replayable, but require structural fields
-- for new repeatable-entity saves. Short optional prose affects completeness,
-- not whether an otherwise valid entity can be saved.
ALTER FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb)
  RENAME TO jobix_profile_mutate_base;
REVOKE ALL ON FUNCTION public.jobix_profile_mutate_base(uuid,uuid,bigint,jsonb)
  FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.profile_mutate(command_key uuid, requested_profile uuid,
  expected_profile_version bigint, mutation jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE section text:=mutation->>'section'; item jsonb:=mutation->'value'; field text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.idempotency_records r
   WHERE r.user_id=auth.uid() AND r.operation_type='profile.mutate'
   AND r.idempotency_key=command_key) AND mutation->>'type'='upsert_item' THEN
   FOREACH field IN ARRAY CASE section
     WHEN 'experience' THEN ARRAY['job_title','company','start_month']
     WHEN 'education' THEN ARRAY['degree','institution','field_of_study','start_month']
     WHEN 'certification' THEN ARRAY['name','issuer','issue_month']
     WHEN 'achievement' THEN ARRAY['title','issuer','achieved_month']
     WHEN 'project' THEN ARRAY['name','role','project_month']
     WHEN 'skill' THEN ARRAY['name']
     WHEN 'language' THEN ARRAY['name','proficiency']
     ELSE ARRAY[]::text[] END LOOP
     IF nullif(public.jobix_trim(item->>field),'') IS NULL THEN
       RAISE EXCEPTION 'VALIDATION_FAILED' USING DETAIL='Required structural field missing';
     END IF;
   END LOOP;
   IF section IN ('experience','education') AND
      coalesce(item->>'is_current','false') <> 'true' AND
      nullif(item->>'end_month','') IS NULL THEN
     RAISE EXCEPTION 'VALIDATION_FAILED';
   END IF;
 END IF;
 RETURN public.jobix_profile_mutate_base(command_key,requested_profile,
   expected_profile_version,mutation);
END $$;
REVOKE ALL ON FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb) TO authenticated;

-- Private, bounded profile attachments. Never a public URL/bucket. Photos are
-- kept out of list/bootstrap responses and returned only by this owner-scoped RPC.
CREATE TABLE public.profile_extras (
 profile_id uuid PRIMARY KEY REFERENCES public.career_profiles(id) ON DELETE CASCADE,
 links jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(links)='array'),
 photo_base64 text,
 photo_mime text CHECK(photo_mime IN ('image/jpeg','image/png')),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK ((photo_base64 IS NULL)=(photo_mime IS NULL)),
 CHECK (octet_length(photo_base64)<=1400000)
);
ALTER TABLE public.profile_extras ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_extras FROM PUBLIC,anon,authenticated;
CREATE POLICY extras_owner ON public.profile_extras FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.career_profiles p JOIN public.users u ON u.id=p.user_id
 WHERE p.id=profile_id AND p.user_id=auth.uid() AND p.status='ACTIVE' AND u.status='ACTIVE'));

CREATE FUNCTION public.read_profile_extras(requested_profile uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.career_profiles p JOIN public.users u ON u.id=p.user_id
 WHERE p.id=requested_profile AND p.user_id=auth.uid() AND p.status='ACTIVE' AND u.status='ACTIVE')
 THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 SELECT jsonb_build_object('links',links,'photo_base64',photo_base64,'photo_mime',photo_mime)
 INTO result FROM public.profile_extras WHERE profile_id=requested_profile;
 RETURN coalesce(result,jsonb_build_object('links','[]'::jsonb,
   'photo_base64',NULL,'photo_mime',NULL));
END $$;

CREATE FUNCTION public.save_profile_extras(command_key uuid,requested_profile uuid,
 expected_profile_version bigint,extras jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.career_profiles; old public.idempotency_records; hash text;
 link jsonb; normalized jsonb:='[]'; seen uuid[]:='{}'; link_id uuid; photo bytea;
 mime text; encoded text; result jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO p FROM public.career_profiles WHERE id=requested_profile
 AND user_id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 IF command_key IS NULL OR extras IS NULL OR jsonb_typeof(extras)<>'object'
 OR (extras-ARRAY['links','photo_base64','photo_mime'])<>'{}'::jsonb
 OR jsonb_typeof(extras->'links') IS DISTINCT FROM 'array'
 OR pg_column_size(extras)>1500000 THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 hash:=encode(sha256(convert_to(jsonb_build_object('profile',p.id,
   'version',expected_profile_version,'extras',extras)::text,'UTF8')),'hex');
 SELECT * INTO old FROM public.idempotency_records WHERE user_id=auth.uid()
 AND operation_type='profile.extras' AND idempotency_key=command_key;
 IF FOUND THEN
   IF old.payload_hash<>hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
   RETURN old.response_state;
 END IF;
 IF p.profile_version IS DISTINCT FROM expected_profile_version THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
 FOR link IN SELECT value FROM jsonb_array_elements(extras->'links') LOOP
   IF jsonb_typeof(link)<>'object' OR (link-ARRAY['id','label','url'])<>'{}'::jsonb
   OR nullif(public.jobix_text_field(link,'label',200),'') IS NULL
   OR public.jobix_url_field(link,'url') IS NULL THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
   BEGIN link_id:=(link->>'id')::uuid;
   EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END;
   IF link_id IS NULL OR link_id=ANY(seen) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
   seen:=array_append(seen,link_id);
   normalized:=normalized||jsonb_build_array(jsonb_build_object('id',link_id,
     'label',public.jobix_text_field(link,'label',200),'url',public.jobix_url_field(link,'url')));
 END LOOP;
 mime:=extras->>'photo_mime'; encoded:=extras->>'photo_base64';
 IF (mime IS NULL)<>(encoded IS NULL) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 IF encoded IS NOT NULL THEN
   IF length(encoded)>1400000 THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
   BEGIN photo:=decode(encoded,'base64');
   EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END;
   IF octet_length(photo)>1048576 OR octet_length(photo)<8 OR NOT (
     (mime='image/jpeg' AND substring(photo FROM 1 FOR 3)=decode('ffd8ff','hex')) OR
     (mime='image/png' AND substring(photo FROM 1 FOR 8)=decode('89504e470d0a1a0a','hex')))
   THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 END IF;
 INSERT INTO public.profile_extras(profile_id,links,photo_base64,photo_mime)
 VALUES(p.id,normalized,encoded,mime) ON CONFLICT(profile_id) DO UPDATE
 SET links=EXCLUDED.links,photo_base64=EXCLUDED.photo_base64,
 photo_mime=EXCLUDED.photo_mime,updated_at=now();
 UPDATE public.career_profiles SET profile_version=profile_version+1,updated_at=now() WHERE id=p.id;
 result:=jsonb_build_object('state','SUCCEEDED','data',public.jobix_profile_text_snapshot(p.id));
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
 VALUES(auth.uid(),'profile.extras',command_key,hash,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.read_profile_extras(uuid),
 public.save_profile_extras(uuid,uuid,bigint,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.read_profile_extras(uuid),
 public.save_profile_extras(uuid,uuid,bigint,jsonb) TO authenticated;
COMMIT;
