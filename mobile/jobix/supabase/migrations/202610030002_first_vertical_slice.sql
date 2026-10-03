-- First slice only. Deferred V2 dependencies are documented in SLICE.md.
-- No Credits, Resume configuration, completeness engine or sync/outbox.
BEGIN;

CREATE TABLE public.onboarding_context (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  career_stage text,
  career_goal text,
  desired_work_location text,
  help_areas jsonb NOT NULL DEFAULT '[]',
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(help_areas) = 'array' AND jsonb_array_length(help_areas) <= 3)
);
CREATE TABLE public.profile_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  slot_number smallint NOT NULL CHECK (slot_number BETWEEN 1 AND 3),
  unlocked boolean NOT NULL DEFAULT false,
  unlocked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, slot_number)
);
CREATE TABLE public.career_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  slot_number smallint NOT NULL DEFAULT 1 CHECK (slot_number BETWEEN 1 AND 3),
  -- No invented default Profile name or Resume language.
  name text,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DELETING','DELETED')),
  profile_version bigint NOT NULL DEFAULT 1,
  cv_language text CHECK (cv_language IN ('en','ar')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  FOREIGN KEY (user_id, slot_number) REFERENCES public.profile_slots(user_id, slot_number)
);
CREATE UNIQUE INDEX uq_active_profile_slot ON public.career_profiles(user_id, slot_number)
  WHERE status <> 'DELETED';
CREATE TABLE public.profile_personal_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL UNIQUE REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  full_name text,
  email text,
  phone text,
  country text,
  city text,
  linkedin_url text,
  github_url text,
  portfolio_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.idempotency_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  operation_type text NOT NULL,
  idempotency_key uuid NOT NULL,
  payload_hash text NOT NULL,
  operation_id uuid,
  response_state jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '30 days',
  UNIQUE (user_id, operation_type, idempotency_key)
);
CREATE INDEX idempotency_expiry ON public.idempotency_records(expires_at);

ALTER TABLE public.onboarding_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_personal_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.idempotency_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_context, public.profile_slots, public.career_profiles,
  public.profile_personal_data, public.idempotency_records FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.onboarding_context, public.profile_slots, public.career_profiles,
  public.profile_personal_data TO authenticated;
CREATE POLICY onboarding_owner ON public.onboarding_context FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND EXISTS
    (SELECT 1 FROM public.users u WHERE u.id = user_id AND u.status = 'ACTIVE'));
CREATE POLICY slots_owner ON public.profile_slots FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND EXISTS
    (SELECT 1 FROM public.users u WHERE u.id = user_id AND u.status = 'ACTIVE'));
CREATE POLICY profiles_owner ON public.career_profiles FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND status = 'ACTIVE' AND EXISTS
    (SELECT 1 FROM public.users u WHERE u.id = user_id AND u.status = 'ACTIVE'));
CREATE POLICY personal_owner ON public.profile_personal_data FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.career_profiles p WHERE p.id = profile_id
    AND p.user_id = (SELECT auth.uid()) AND p.status = 'ACTIVE'));

CREATE FUNCTION public.jobix_new_account() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE profile uuid;
BEGIN
  INSERT INTO public.users(id) VALUES (NEW.id);
  INSERT INTO public.profile_slots(user_id,slot_number,unlocked,unlocked_at)
    VALUES (NEW.id,1,true,now());
  INSERT INTO public.career_profiles(user_id,slot_number)
    VALUES (NEW.id,1) RETURNING id INTO profile;
  INSERT INTO public.profile_personal_data(profile_id) VALUES (profile);
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.jobix_new_account() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER jobix_account_after_registration AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.jobix_new_account();
-- Existing Auth accounts are deliberately not backfilled.

CREATE FUNCTION public.save_onboarding(
  command_key uuid, expected_version bigint, answers jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  previous public.idempotency_records;
  current_version bigint;
  answer_hash text := encode(sha256(convert_to(
    jsonb_build_object('version',expected_version,'answers',answers)::text,'UTF8')),'hex');
  result jsonb;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF command_key IS NULL OR expected_version IS NULL OR answers IS NULL
    OR jsonb_typeof(answers) <> 'object' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  PERFORM 1 FROM public.users WHERE id = uid AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
  SELECT * INTO previous FROM public.idempotency_records
    WHERE user_id = uid AND operation_type = 'onboarding.save' AND idempotency_key = command_key;
  IF FOUND THEN
    IF previous.payload_hash <> answer_hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
    RETURN previous.response_state;
  END IF;
  IF (answers - ARRAY['career_stage','career_goal','desired_work_location','help_areas']) <> '{}'::jsonb
    OR (answers->>'career_stage') IS NULL OR (answers->>'career_goal') IS NULL
    OR (answers->>'desired_work_location') IS NULL
    OR answers->>'career_stage' NOT IN ('student','graduate','early','mid','experienced','returning','changer')
    OR answers->>'career_goal' NOT IN ('first_job','better_job','change','advance','prepare','unsure')
    OR answers->>'desired_work_location' NOT IN ('city','country','remote','abroad','multiple','unsure')
    OR jsonb_typeof(answers->'help_areas') IS DISTINCT FROM 'array'
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  IF jsonb_array_length(answers->'help_areas') NOT BETWEEN 1 AND 3
    OR EXISTS (SELECT 1 FROM jsonb_array_elements_text(answers->'help_areas') h(value)
      WHERE value NOT IN ('cv','opportunities','paths','online','skills','interviews'))
    OR (SELECT count(DISTINCT value) FROM jsonb_array_elements_text(answers->'help_areas'))
      <> jsonb_array_length(answers->'help_areas')
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  SELECT version INTO current_version FROM public.onboarding_context WHERE user_id = uid;
  IF coalesce(current_version,0) <> expected_version THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
  INSERT INTO public.onboarding_context(user_id,career_stage,career_goal,desired_work_location,help_areas)
    VALUES (uid,answers->>'career_stage',answers->>'career_goal',
      answers->>'desired_work_location',answers->'help_areas')
    ON CONFLICT(user_id) DO UPDATE SET
      career_stage=EXCLUDED.career_stage,career_goal=EXCLUDED.career_goal,
      desired_work_location=EXCLUDED.desired_work_location,help_areas=EXCLUDED.help_areas,
      version=public.onboarding_context.version+1,updated_at=now();
  SELECT jsonb_build_object('version',version) INTO result
    FROM public.onboarding_context WHERE user_id = uid;
  INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
    VALUES (uid,'onboarding.save',command_key,answer_hash,result);
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.save_onboarding(uuid,bigint,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_onboarding(uuid,bigint,jsonb) TO authenticated;

CREATE FUNCTION public.save_personal_information(
  command_key uuid, requested_profile uuid, expected_version bigint, personal jsonb,
  resume_language text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  previous public.idempotency_records;
  profile public.career_profiles;
  result jsonb;
  value text;
  answer_hash text := encode(sha256(convert_to(jsonb_build_object(
    'profile',requested_profile,'version',expected_version,
    'personal',personal,'language',resume_language)::text,'UTF8')),'hex');
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF command_key IS NULL OR requested_profile IS NULL OR expected_version IS NULL
    OR personal IS NULL OR jsonb_typeof(personal) <> 'object'
    OR (personal - ARRAY['full_name','email','phone','country','city','linkedin_url','github_url','portfolio_url'])
      <> '{}'::jsonb
    OR (resume_language IS NOT NULL AND resume_language NOT IN ('en','ar'))
    OR EXISTS (SELECT 1 FROM jsonb_each(personal) v WHERE jsonb_typeof(v.value) NOT IN ('string','null'))
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  PERFORM 1 FROM public.users WHERE id = uid AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
  SELECT * INTO profile FROM public.career_profiles
    WHERE id = requested_profile AND user_id = uid AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT * INTO previous FROM public.idempotency_records
    WHERE user_id = uid AND operation_type = 'profile.mutate' AND idempotency_key = command_key;
  IF FOUND THEN
    IF previous.payload_hash <> answer_hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
    RETURN previous.response_state;
  END IF;
  IF profile.profile_version <> expected_version THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
  value := nullif(btrim(personal->>'email'),'');
  IF value IS NOT NULL AND value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  value := nullif(btrim(personal->>'phone'),'');
  IF value IS NOT NULL AND (value !~ '^\+?[0-9 ()-]+$'
    OR length(regexp_replace(value,'[^0-9]','','g')) NOT BETWEEN 7 AND 15)
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  FOREACH value IN ARRAY ARRAY[personal->>'linkedin_url',personal->>'github_url',personal->>'portfolio_url'] LOOP
    IF nullif(btrim(value),'') IS NOT NULL AND value !~ '^https://[^[:space:]/?#@]+([/?#][^[:space:]]*)?$'
      THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  END LOOP;
  UPDATE public.profile_personal_data SET
    full_name=nullif(btrim(personal->>'full_name'),''),
    email=nullif(btrim(personal->>'email'),''),
    phone=nullif(btrim(personal->>'phone'),''),
    country=nullif(btrim(personal->>'country'),''),
    city=nullif(btrim(personal->>'city'),''),
    linkedin_url=nullif(btrim(personal->>'linkedin_url'),''),
    github_url=nullif(btrim(personal->>'github_url'),''),
    portfolio_url=nullif(btrim(personal->>'portfolio_url'),''),
    updated_at=now() WHERE profile_id = requested_profile;
  UPDATE public.career_profiles SET cv_language=resume_language,
    profile_version=profile_version+1,updated_at=now() WHERE id = requested_profile;
  SELECT jsonb_build_object('profile_id',p.id,'profile_version',p.profile_version,
    'cv_language',p.cv_language,'personal',jsonb_build_object(
      'full_name',d.full_name,'email',d.email,'phone',d.phone,'country',d.country,'city',d.city,
      'linkedin_url',d.linkedin_url,'github_url',d.github_url,'portfolio_url',d.portfolio_url))
    INTO result FROM public.career_profiles p JOIN public.profile_personal_data d ON d.profile_id=p.id
    WHERE p.id=requested_profile;
  INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,response_state)
    VALUES (uid,'profile.mutate',command_key,answer_hash,result);
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.save_personal_information(uuid,uuid,bigint,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_personal_information(uuid,uuid,bigint,jsonb,text) TO authenticated;
COMMIT;