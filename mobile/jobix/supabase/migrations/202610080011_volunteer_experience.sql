BEGIN;
-- Additive, unpaid career evidence. No scoring recompute/backfill and no AI
-- writes: even updating completeness_percent to itself would fire its latch.
CREATE TABLE public.profile_volunteer_experiences (
 id uuid PRIMARY KEY,
 profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
 organization text NOT NULL CHECK(char_length(organization) BETWEEN 1 AND 200),
 role text NOT NULL CHECK(char_length(role) BETWEEN 1 AND 200),
 location text CHECK(char_length(location)<=200),
 start_month date NOT NULL,
 end_month date,
 is_current boolean NOT NULL DEFAULT false,
 description text CHECK(char_length(description)<=1500),
 sort_order integer NOT NULL DEFAULT 0,
 version bigint NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((is_current AND end_month IS NULL) OR
       (NOT is_current AND end_month IS NOT NULL AND end_month>=start_month))
);
CREATE INDEX ix_profile_volunteer_experiences_profile
 ON public.profile_volunteer_experiences(profile_id,sort_order,created_at);
ALTER TABLE public.profile_volunteer_experiences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_volunteer_experiences FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.profile_volunteer_experiences TO authenticated;
CREATE POLICY volunteer_owner ON public.profile_volunteer_experiences
 FOR SELECT TO authenticated USING(EXISTS(
  SELECT 1 FROM public.career_profiles p JOIN public.users u ON u.id=p.user_id
  WHERE p.id=profile_id AND p.user_id=(SELECT auth.uid())
    AND p.status='ACTIVE' AND u.status='ACTIVE'
 ));

-- Keep the existing read model intact and append a distinct typed array.
ALTER FUNCTION public.jobix_profile_text_snapshot(uuid)
 RENAME TO jobix_profile_text_snapshot_pre_volunteer;
REVOKE ALL ON FUNCTION public.jobix_profile_text_snapshot_pre_volunteer(uuid)
 FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.jobix_profile_text_snapshot(profile uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.jobix_profile_text_snapshot_pre_volunteer(profile) ||
  jsonb_build_object('volunteer_experiences',(
   SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',v.id,'version',v.version,'organization',v.organization,'role',v.role,
    'location',v.location,'start_month',public.jobix_month_text(v.start_month),
    'end_month',public.jobix_month_text(v.end_month),'is_current',v.is_current,
    'description',v.description,'complete',false
   ) ORDER BY v.sort_order,v.created_at),'[]'::jsonb)
   FROM public.profile_volunteer_experiences v WHERE v.profile_id=profile
  ))
$$;
REVOKE ALL ON FUNCTION public.jobix_profile_text_snapshot(uuid)
 FROM PUBLIC,anon,authenticated;

-- Existing mutations, validation and durable acknowledgements remain owned by
-- their existing implementation. Only Volunteer takes the non-scoring branch.
ALTER FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb)
 RENAME TO jobix_profile_mutate_pre_volunteer;
REVOKE ALL ON FUNCTION public.jobix_profile_mutate_pre_volunteer(uuid,uuid,bigint,jsonb)
 FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.profile_mutate(command_key uuid, requested_profile uuid,
 expected_profile_version bigint, mutation jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); p public.career_profiles;
 previous public.idempotency_records; payload_hash text; result jsonb;
 kind text:=mutation->>'type'; item jsonb:=mutation->'value';
 item_id uuid; organization_value text; role_value text;
 location_value text; description_value text;
 start_value text; end_value text; start_d date; end_d date;
 current_flag boolean; affected integer;
BEGIN
 IF mutation->>'section' IS DISTINCT FROM 'volunteer' THEN
  RETURN public.jobix_profile_mutate_pre_volunteer(
    command_key,requested_profile,expected_profile_version,mutation);
 END IF;
 IF uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 IF command_key IS NULL OR requested_profile IS NULL OR expected_profile_version IS NULL
  OR jsonb_typeof(mutation) IS DISTINCT FROM 'object'
  OR (mutation-ARRAY['type','section','value'])<>'{}'::jsonb
  OR kind IS NULL OR kind NOT IN ('upsert_item','delete_item')
  OR jsonb_typeof(item) IS DISTINCT FROM 'object'
  THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 PERFORM 1 FROM public.users WHERE id=uid AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO p FROM public.career_profiles
  WHERE id=requested_profile AND user_id=uid AND status='ACTIVE' FOR UPDATE;
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
 IF jsonb_typeof(item->'id') IS DISTINCT FROM 'string'
  OR item->>'id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 item_id:=(item->>'id')::uuid;
 IF kind='delete_item' THEN
  IF (item-'id')<>'{}'::jsonb THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  DELETE FROM public.profile_volunteer_experiences WHERE id=item_id AND profile_id=p.id;
  GET DIAGNOSTICS affected=ROW_COUNT;
  IF affected=0 THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;
 ELSE
  IF (item-ARRAY['id','organization','role','location','start_month','end_month',
    'is_current','description'])<>'{}'::jsonb THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  organization_value:=public.jobix_text_field(item,'organization',200);
  role_value:=public.jobix_text_field(item,'role',200);
  location_value:=public.jobix_text_field(item,'location',200);
  description_value:=public.jobix_text_field(item,'description',1500);
  current_flag:=public.jobix_bool_field(item,'is_current');
  start_value:=public.jobix_text_field(item,'start_month',7);
  IF organization_value IS NULL OR role_value IS NULL OR start_value IS NULL
   OR start_value !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' OR left(start_value,4)='0000'
   THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  start_d:=public.jobix_month_field(item,'start_month');
  -- Current roles ignore/clear stale end-month values; never persist them.
  IF NOT current_flag THEN
   end_value:=public.jobix_text_field(item,'end_month',7);
   IF end_value IS NULL OR end_value !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
    OR left(end_value,4)='0000' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
   end_d:=public.jobix_month_field(item,'end_month');
   IF end_d<start_d THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  END IF;
  INSERT INTO public.profile_volunteer_experiences AS t(
   id,profile_id,organization,role,location,start_month,end_month,is_current,description,sort_order)
  VALUES(item_id,p.id,organization_value,role_value,location_value,start_d,end_d,current_flag,
   description_value,public.jobix_next_order('profile_volunteer_experiences',p.id))
  ON CONFLICT(id) DO UPDATE SET
   organization=EXCLUDED.organization,role=EXCLUDED.role,location=EXCLUDED.location,
   start_month=EXCLUDED.start_month,end_month=EXCLUDED.end_month,is_current=EXCLUDED.is_current,
   description=EXCLUDED.description,version=t.version+1,updated_at=now()
   WHERE t.profile_id=EXCLUDED.profile_id;
  GET DIAGNOSTICS affected=ROW_COUNT;
  IF affected=0 THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 END IF;
 -- Do NOT write completeness_percent, invoke its recompute helper or touch AI.
 UPDATE public.career_profiles SET profile_version=profile_version+1,updated_at=now() WHERE id=p.id;
 result:=jsonb_build_object('request_id',command_key,'operation_id',command_key,
  'state','SUCCEEDED','data',public.jobix_profile_text_snapshot(p.id),
  'authoritative_version',p.profile_version+1,'error',NULL);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
  VALUES(uid,'profile.mutate',command_key,payload_hash,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.profile_mutate(uuid,uuid,bigint,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
