-- Approved core Career Profile sections. Typed, owner-scoped, read-only to clients;
-- every write goes through the versioned, idempotent profile_mutate command.
-- No providers, charges, rewards, exports, AI output or policy edits.
BEGIN;

CREATE TABLE public.profile_experiences (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  job_title text, company text, location text,
  start_month date, end_month date, is_current boolean NOT NULL DEFAULT false,
  -- Original user-authored text. Future AI proposals are stored separately.
  description text,
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(job_title)<=200 AND char_length(company)<=200 AND char_length(location)<=200),
  CHECK(char_length(description)<=1500),
  CHECK(NOT is_current OR end_month IS NULL),
  CHECK(end_month IS NULL OR start_month IS NULL OR end_month>=start_month)
);
CREATE TABLE public.profile_education (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  degree text, institution text, field_of_study text,
  start_month date, end_month date, is_current boolean NOT NULL DEFAULT false,
  description text,
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(degree)<=200 AND char_length(institution)<=200 AND char_length(field_of_study)<=200),
  CHECK(char_length(description)<=1500),
  CHECK(NOT is_current OR end_month IS NULL),
  CHECK(end_month IS NULL OR start_month IS NULL OR end_month>=start_month)
);
CREATE TABLE public.profile_certifications (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  name text, issuer text, issue_month date, expiry_month date, credential_id text,
  description text, url text,
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(name)<=200 AND char_length(issuer)<=200 AND char_length(credential_id)<=200),
  CHECK(char_length(description)<=1500 AND char_length(url)<=2048),
  CHECK(expiry_month IS NULL OR issue_month IS NULL OR expiry_month>=issue_month)
);
CREATE TABLE public.profile_achievements (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  title text, issuer text, achieved_month date, description text, url text,
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(title)<=200 AND char_length(issuer)<=200),
  CHECK(char_length(description)<=1500 AND char_length(url)<=2048)
);
CREATE TABLE public.profile_projects (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  name text, role text, project_month date,
  -- Original user-authored text. Future AI proposals are stored separately.
  description text, url text, technologies text[] NOT NULL DEFAULT '{}',
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(name)<=200 AND char_length(role)<=200),
  CHECK(char_length(description)<=1500 AND char_length(url)<=2048),
  CHECK(cardinality(technologies)<=30)
);
CREATE TABLE public.profile_skills (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(name) BETWEEN 1 AND 100)
);
CREATE TABLE public.profile_languages (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  proficiency text NOT NULL CHECK(proficiency IN ('BASIC','CONVERSATIONAL','PROFESSIONAL','FLUENT','NATIVE')),
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK(char_length(name) BETWEEN 1 AND 100)
);
-- Approved optional-section mechanism (e.g. VOLUNTEER_EXPERIENCE). No write path yet.
CREATE TABLE public.profile_optional_sections (
  id uuid PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES public.career_profiles(id) ON DELETE CASCADE,
  section_type text NOT NULL CHECK(section_type IN ('VOLUNTEER_EXPERIENCE')),
  payload_version integer NOT NULL DEFAULT 1,
  payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),
  sort_order integer NOT NULL DEFAULT 0, version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE FUNCTION public.jobix_name_key(value text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT lower(regexp_replace(public.jobix_trim(value),'[[:space:]]+',' ','g'))
$$;
CREATE UNIQUE INDEX uq_profile_skill_name ON public.profile_skills(profile_id,public.jobix_name_key(name));
CREATE UNIQUE INDEX uq_profile_language_name ON public.profile_languages(profile_id,public.jobix_name_key(name));

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['profile_experiences','profile_education','profile_certifications',
   'profile_achievements','profile_projects','profile_skills','profile_languages','profile_optional_sections'] LOOP
  EXECUTE format('CREATE INDEX %I ON public.%I(profile_id,sort_order,created_at)','ix_'||t||'_profile',t);
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
  EXECUTE format($p$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated
   USING(EXISTS(SELECT 1 FROM public.career_profiles p JOIN public.users u ON u.id=p.user_id
   WHERE p.id=profile_id AND p.user_id=(SELECT auth.uid()) AND p.status='ACTIVE' AND u.status='ACTIVE'))$p$,
   t||'_owner',t);
 END LOOP;
END $$;

-- Field readers: reject wrong types and over-limit text; never truncate.
CREATE FUNCTION public.jobix_text_field(item jsonb, field text, maximum integer) RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE value text; BEGIN
 IF NOT item ? field OR jsonb_typeof(item->field)='null' THEN RETURN NULL; END IF;
 IF jsonb_typeof(item->field)<>'string' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 value:=public.jobix_trim(item->>field);
 IF char_length(value)>maximum THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 RETURN nullif(value,'');
END $$;
CREATE FUNCTION public.jobix_month_field(item jsonb, field text) RETURNS date
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE value text:=public.jobix_text_field(item,field,7); BEGIN
 IF value IS NULL THEN RETURN NULL; END IF;
 IF value !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 -- Day 01 is a storage convention only; clients render month/year.
 RETURN to_date(value||'-01','YYYY-MM-DD');
END $$;
CREATE FUNCTION public.jobix_url_field(item jsonb, field text) RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE value text:=public.jobix_text_field(item,field,2048); BEGIN
 IF value IS NULL THEN RETURN NULL; END IF;
 IF value !~* '^https://' THEN
  IF value ~ '^[A-Za-z][A-Za-z0-9+.-]*:' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  value:='https://'||value;
 END IF;
 IF char_length(value)>2048 OR value !~* '^https://[^[:space:]/?#@]+\.[^[:space:]/?#@]+([/?#][^[:space:]]*)?$'
  THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 RETURN value;
END $$;
CREATE FUNCTION public.jobix_bool_field(item jsonb, field text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$ BEGIN
 IF NOT item ? field OR jsonb_typeof(item->field)='null' THEN RETURN false; END IF;
 IF jsonb_typeof(item->field)<>'boolean' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 RETURN (item->>field)::boolean;
END $$;

-- "Complete" means ready to render; drafts may be saved incomplete.
CREATE FUNCTION public.jobix_experience_complete(e public.profile_experiences) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT public.jobix_meaningful(e.job_title,1) AND public.jobix_meaningful(e.company,1)
  AND e.start_month IS NOT NULL AND (e.is_current OR e.end_month IS NOT NULL)
  AND public.jobix_meaningful(e.description,20)
$$;
CREATE FUNCTION public.jobix_education_complete(e public.profile_education) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT public.jobix_meaningful(e.degree,1) AND public.jobix_meaningful(e.institution,1)
  AND public.jobix_meaningful(e.field_of_study,1)
  AND e.start_month IS NOT NULL AND (e.is_current OR e.end_month IS NOT NULL)
$$;
CREATE FUNCTION public.jobix_project_complete(e public.profile_projects) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT public.jobix_meaningful(e.name,1) AND public.jobix_meaningful(e.role,1)
  AND e.project_month IS NOT NULL AND public.jobix_meaningful(e.description,20)
$$;
CREATE FUNCTION public.jobix_achievement_complete(e public.profile_achievements) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT public.jobix_meaningful(e.title,1) AND public.jobix_meaningful(e.issuer,1)
  AND e.achieved_month IS NOT NULL AND public.jobix_meaningful(e.description,20)
$$;
CREATE FUNCTION public.jobix_certification_complete(e public.profile_certifications) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT public.jobix_meaningful(e.name,1) AND public.jobix_meaningful(e.issuer,1) AND e.issue_month IS NOT NULL
$$;

-- Approved weights: Contact 5+5+5, Evidence 30 then 15 (distinct complete items;
-- Certifications excluded), Skills 15, Summary 10, Languages 10, Target Role 5.
CREATE OR REPLACE FUNCTION public.jobix_recompute_text_profile(profile uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE points integer:=0; p public.profile_personal_data; s text; target text; evidence integer;
BEGIN
 SELECT * INTO p FROM public.profile_personal_data WHERE profile_id=profile;
 IF public.jobix_meaningful(p.full_name,1) AND char_length(p.full_name)<=120 THEN points:=points+5; END IF;
 IF p.email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' AND char_length(p.email)<=254 THEN points:=points+5; END IF;
 IF p.phone ~ '^\+?[0-9 ()-]+$' AND length(regexp_replace(p.phone,'[^0-9]','','g')) BETWEEN 7 AND 15
   AND char_length(p.phone)<=32 THEN points:=points+5; END IF;
 SELECT text INTO s FROM public.profile_summaries WHERE profile_id=profile;
 IF public.jobix_meaningful(s,50) THEN points:=points+10; END IF;
 SELECT target_role INTO target FROM public.career_profiles WHERE id=profile;
 IF public.jobix_meaningful(target,2) THEN points:=points+5; END IF;
 SELECT count(DISTINCT k) INTO evidence FROM (
  SELECT concat_ws('|','experience',public.jobix_name_key(job_title),public.jobix_name_key(company),
    public.jobix_name_key(location),start_month,end_month,is_current,public.jobix_name_key(description)) k
   FROM public.profile_experiences e WHERE e.profile_id=profile AND public.jobix_experience_complete(e)
  UNION ALL SELECT concat_ws('|','education',public.jobix_name_key(degree),public.jobix_name_key(institution),
    public.jobix_name_key(field_of_study),start_month,end_month,is_current,public.jobix_name_key(description))
   FROM public.profile_education e WHERE e.profile_id=profile AND public.jobix_education_complete(e)
  UNION ALL SELECT concat_ws('|','project',public.jobix_name_key(e.name),public.jobix_name_key(e.role),
    project_month,public.jobix_name_key(description),url)
   FROM public.profile_projects e WHERE e.profile_id=profile AND public.jobix_project_complete(e)
  UNION ALL SELECT concat_ws('|','achievement',public.jobix_name_key(title),public.jobix_name_key(issuer),
    achieved_month,public.jobix_name_key(description),url)
   FROM public.profile_achievements e WHERE e.profile_id=profile AND public.jobix_achievement_complete(e)
 ) items;
 points:=points+CASE WHEN evidence>=2 THEN 45 WHEN evidence=1 THEN 30 ELSE 0 END;
 IF EXISTS(SELECT 1 FROM public.profile_skills WHERE profile_id=profile AND public.jobix_meaningful(name,1))
  THEN points:=points+15; END IF;
 IF EXISTS(SELECT 1 FROM public.profile_languages WHERE profile_id=profile AND public.jobix_meaningful(name,1))
  THEN points:=points+10; END IF;
 UPDATE public.career_profiles SET completeness_percent=least(points,100),
   completeness_algorithm_version='core-profile-v2' WHERE id=profile;
END $$;

CREATE FUNCTION public.jobix_month_text(value date) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT to_char(value,'YYYY-MM') $$;

-- One canonical read model: every section, ordered, with server completeness per item.
CREATE OR REPLACE FUNCTION public.jobix_profile_text_snapshot(profile uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('profile_id',p.id,'profile_version',p.profile_version,
  'slot_number',p.slot_number,'cv_language',p.cv_language,
  'personal',to_jsonb(d)-'id'-'profile_id'-'created_at'-'updated_at',
  'summary',coalesce(s.text,''),'target_role',coalesce(p.target_role,''),
  'completeness_percent',p.completeness_percent,
  'completeness_algorithm_version',p.completeness_algorithm_version,
  'summary_state',CASE WHEN coalesce(s.text,'')='' THEN 'UNUSED'
    WHEN public.jobix_meaningful(s.text,50) THEN 'COMPLETE' ELSE 'NEEDS_ATTENTION' END,
  'target_role_state',CASE WHEN coalesce(p.target_role,'')='' THEN 'UNUSED'
    WHEN public.jobix_meaningful(p.target_role,2) THEN 'COMPLETE' ELSE 'NEEDS_ATTENTION' END,
  'experiences',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,
    'job_title',e.job_title,'company',e.company,'location',e.location,
    'start_month',public.jobix_month_text(e.start_month),'end_month',public.jobix_month_text(e.end_month),
    'is_current',e.is_current,'description',e.description,
    'complete',public.jobix_experience_complete(e)) ORDER BY e.sort_order,e.created_at),'[]')
    FROM public.profile_experiences e WHERE e.profile_id=p.id),
  'education',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,
    'degree',e.degree,'institution',e.institution,'field_of_study',e.field_of_study,
    'start_month',public.jobix_month_text(e.start_month),'end_month',public.jobix_month_text(e.end_month),
    'is_current',e.is_current,'description',e.description,
    'complete',public.jobix_education_complete(e)) ORDER BY e.sort_order,e.created_at),'[]')
    FROM public.profile_education e WHERE e.profile_id=p.id),
  'certifications',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,
    'name',e.name,'issuer',e.issuer,'issue_month',public.jobix_month_text(e.issue_month),
    'expiry_month',public.jobix_month_text(e.expiry_month),'credential_id',e.credential_id,
    'description',e.description,'url',e.url,
    'complete',public.jobix_certification_complete(e)) ORDER BY e.sort_order,e.created_at),'[]')
    FROM public.profile_certifications e WHERE e.profile_id=p.id),
  'achievements',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,
    'title',e.title,'issuer',e.issuer,'achieved_month',public.jobix_month_text(e.achieved_month),
    'description',e.description,'url',e.url,
    'complete',public.jobix_achievement_complete(e)) ORDER BY e.sort_order,e.created_at),'[]')
    FROM public.profile_achievements e WHERE e.profile_id=p.id),
  'projects',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,
    'name',e.name,'role',e.role,'project_month',public.jobix_month_text(e.project_month),
    'description',e.description,'url',e.url,'technologies',to_jsonb(e.technologies),
    'complete',public.jobix_project_complete(e)) ORDER BY e.sort_order,e.created_at),'[]')
    FROM public.profile_projects e WHERE e.profile_id=p.id),
  'skills',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,'name',e.name)
    ORDER BY e.sort_order,e.created_at),'[]') FROM public.profile_skills e WHERE e.profile_id=p.id),
  'languages',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'version',e.version,
    'name',e.name,'proficiency',e.proficiency) ORDER BY e.sort_order,e.created_at),'[]')
    FROM public.profile_languages e WHERE e.profile_id=p.id))
 FROM public.career_profiles p JOIN public.profile_personal_data d ON d.profile_id=p.id
 LEFT JOIN public.profile_summaries s ON s.profile_id=p.id WHERE p.id=profile
$$;

CREATE FUNCTION public.jobix_next_order(tbl text, profile uuid) RETURNS integer
LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE result integer; BEGIN
 EXECUTE format('SELECT coalesce(max(sort_order),-1)+1 FROM public.%I WHERE profile_id=$1',tbl)
  INTO result USING profile;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.profile_mutate(command_key uuid, requested_profile uuid,
  expected_profile_version bigint, mutation jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); p public.career_profiles; previous public.idempotency_records;
 section text; kind text; item jsonb; value text; result jsonb; payload_hash text;
 item_id uuid; tbl text; affected integer; allowed text[]; personal jsonb; f text;
 start_d date; end_d date; current_flag boolean; techs text[];
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 kind:=mutation->>'type'; section:=mutation->>'section'; item:=mutation->'value';
 IF command_key IS NULL OR requested_profile IS NULL OR expected_profile_version IS NULL
   OR mutation IS NULL OR jsonb_typeof(mutation)<>'object'
   OR (mutation-ARRAY['type','section','value'])<>'{}'::jsonb
   OR kind IS NULL OR kind NOT IN ('upsert_item','delete_item')
   OR section IS NULL OR jsonb_typeof(item) IS DISTINCT FROM 'object'
   THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 tbl:=CASE section WHEN 'experience' THEN 'profile_experiences' WHEN 'education' THEN 'profile_education'
  WHEN 'certification' THEN 'profile_certifications' WHEN 'achievement' THEN 'profile_achievements'
  WHEN 'project' THEN 'profile_projects' WHEN 'skill' THEN 'profile_skills'
  WHEN 'language' THEN 'profile_languages' END;
 IF section NOT IN ('summary','target_role','personal') AND tbl IS NULL THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 IF kind='delete_item' AND (tbl IS NULL OR (item-'id')<>'{}'::jsonb) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;

 IF section='personal' THEN
  -- Unified entry for Personal Information; the compatibility RPC keeps owning its
  -- durable idempotency records so existing command keys replay identically.
  personal:=item->'personal';
  IF (item-ARRAY['personal','resume_language'])<>'{}'::jsonb OR jsonb_typeof(personal) IS DISTINCT FROM 'object'
    OR (item ? 'resume_language' AND jsonb_typeof(item->'resume_language') NOT IN ('string','null'))
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  FOREACH f IN ARRAY ARRAY['full_name','email','phone','country','city','linkedin_url','github_url','portfolio_url'] LOOP
   PERFORM public.jobix_text_field(personal,f,CASE f WHEN 'full_name' THEN 120 WHEN 'email' THEN 254
     WHEN 'phone' THEN 32 WHEN 'country' THEN 100 WHEN 'city' THEN 100 ELSE 2048 END);
  END LOOP;
  result:=public.save_personal_information(command_key,requested_profile,expected_profile_version,
    personal,item->>'resume_language');
  RETURN jsonb_build_object('request_id',command_key,'operation_id',command_key,'state','SUCCEEDED',
    'data',result,'authoritative_version',(result->>'profile_version')::bigint,'error',NULL);
 END IF;

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

 IF section IN ('summary','target_role') THEN
  IF kind<>'upsert_item' OR (item-'text')<>'{}'::jsonb OR jsonb_typeof(item->'text') IS DISTINCT FROM 'string'
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  value:=public.jobix_trim(item->>'text');
  IF char_length(value)>(CASE WHEN section='summary' THEN 1000 ELSE 200 END) THEN
    RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  IF section='summary' THEN
   INSERT INTO public.profile_summaries(profile_id,text) VALUES(p.id,nullif(value,''))
   ON CONFLICT(profile_id) DO UPDATE SET text=EXCLUDED.text,
     version=public.profile_summaries.version+1,updated_at=now();
  ELSE
   UPDATE public.career_profiles SET target_role=nullif(value,'') WHERE id=p.id;
  END IF;
 ELSE
  IF jsonb_typeof(item->'id') IS DISTINCT FROM 'string'
    OR item->>'id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  item_id:=(item->>'id')::uuid;
  IF kind='delete_item' THEN
   EXECUTE format('DELETE FROM public.%I WHERE id=$1 AND profile_id=$2',tbl) USING item_id,p.id;
   GET DIAGNOSTICS affected=ROW_COUNT;
   IF affected=0 THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;
  ELSE
   allowed:=CASE section
    WHEN 'experience' THEN ARRAY['id','job_title','company','location','start_month','end_month','is_current','description']
    WHEN 'education' THEN ARRAY['id','degree','institution','field_of_study','start_month','end_month','is_current','description']
    WHEN 'certification' THEN ARRAY['id','name','issuer','issue_month','expiry_month','credential_id','description','url']
    WHEN 'achievement' THEN ARRAY['id','title','issuer','achieved_month','description','url']
    WHEN 'project' THEN ARRAY['id','name','role','project_month','description','url','technologies']
    WHEN 'skill' THEN ARRAY['id','name']
    WHEN 'language' THEN ARRAY['id','name','proficiency'] END;
   IF (item-allowed)<>'{}'::jsonb THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
   IF section IN ('experience','education') THEN
    start_d:=public.jobix_month_field(item,'start_month'); end_d:=public.jobix_month_field(item,'end_month');
    current_flag:=public.jobix_bool_field(item,'is_current');
    IF (current_flag AND end_d IS NOT NULL) OR (end_d<start_d) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
   END IF;
   BEGIN
    IF section='experience' THEN
     INSERT INTO public.profile_experiences AS t(id,profile_id,job_title,company,location,start_month,end_month,
       is_current,description,sort_order)
     VALUES(item_id,p.id,public.jobix_text_field(item,'job_title',200),public.jobix_text_field(item,'company',200),
       public.jobix_text_field(item,'location',200),start_d,end_d,current_flag,
       public.jobix_text_field(item,'description',1500),public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET job_title=EXCLUDED.job_title,company=EXCLUDED.company,location=EXCLUDED.location,
       start_month=EXCLUDED.start_month,end_month=EXCLUDED.end_month,is_current=EXCLUDED.is_current,
       description=EXCLUDED.description,version=t.version+1,updated_at=now() WHERE t.profile_id=EXCLUDED.profile_id;
    ELSIF section='education' THEN
     INSERT INTO public.profile_education AS t(id,profile_id,degree,institution,field_of_study,start_month,end_month,
       is_current,description,sort_order)
     VALUES(item_id,p.id,public.jobix_text_field(item,'degree',200),public.jobix_text_field(item,'institution',200),
       public.jobix_text_field(item,'field_of_study',200),start_d,end_d,current_flag,
       public.jobix_text_field(item,'description',1500),public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET degree=EXCLUDED.degree,institution=EXCLUDED.institution,
       field_of_study=EXCLUDED.field_of_study,start_month=EXCLUDED.start_month,end_month=EXCLUDED.end_month,
       is_current=EXCLUDED.is_current,description=EXCLUDED.description,version=t.version+1,updated_at=now()
       WHERE t.profile_id=EXCLUDED.profile_id;
    ELSIF section='certification' THEN
     start_d:=public.jobix_month_field(item,'issue_month'); end_d:=public.jobix_month_field(item,'expiry_month');
     IF end_d<start_d THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
     INSERT INTO public.profile_certifications AS t(id,profile_id,name,issuer,issue_month,expiry_month,credential_id,
       description,url,sort_order)
     VALUES(item_id,p.id,public.jobix_text_field(item,'name',200),public.jobix_text_field(item,'issuer',200),
       start_d,end_d,public.jobix_text_field(item,'credential_id',200),
       public.jobix_text_field(item,'description',1500),public.jobix_url_field(item,'url'),public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,issuer=EXCLUDED.issuer,issue_month=EXCLUDED.issue_month,
       expiry_month=EXCLUDED.expiry_month,credential_id=EXCLUDED.credential_id,description=EXCLUDED.description,
       url=EXCLUDED.url,version=t.version+1,updated_at=now() WHERE t.profile_id=EXCLUDED.profile_id;
    ELSIF section='achievement' THEN
     INSERT INTO public.profile_achievements AS t(id,profile_id,title,issuer,achieved_month,description,url,sort_order)
     VALUES(item_id,p.id,public.jobix_text_field(item,'title',200),public.jobix_text_field(item,'issuer',200),
       public.jobix_month_field(item,'achieved_month'),public.jobix_text_field(item,'description',1500),
       public.jobix_url_field(item,'url'),public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title,issuer=EXCLUDED.issuer,achieved_month=EXCLUDED.achieved_month,
       description=EXCLUDED.description,url=EXCLUDED.url,version=t.version+1,updated_at=now()
       WHERE t.profile_id=EXCLUDED.profile_id;
    ELSIF section='project' THEN
     IF item ? 'technologies' AND jsonb_typeof(item->'technologies')<>'array' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
     SELECT coalesce(array_agg(public.jobix_trim(x.v#>>'{}') ORDER BY x.n),'{}') INTO techs
       FROM jsonb_array_elements(coalesce(item->'technologies','[]')) WITH ORDINALITY x(v,n);
     IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'technologies','[]')) v WHERE jsonb_typeof(v)<>'string')
       OR EXISTS(SELECT 1 FROM unnest(techs) t WHERE char_length(t) NOT BETWEEN 1 AND 100)
       OR cardinality(techs)>30 THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
     INSERT INTO public.profile_projects AS t(id,profile_id,name,role,project_month,description,url,technologies,sort_order)
     VALUES(item_id,p.id,public.jobix_text_field(item,'name',200),public.jobix_text_field(item,'role',200),
       public.jobix_month_field(item,'project_month'),public.jobix_text_field(item,'description',1500),
       public.jobix_url_field(item,'url'),techs,public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,role=EXCLUDED.role,project_month=EXCLUDED.project_month,
       description=EXCLUDED.description,url=EXCLUDED.url,technologies=EXCLUDED.technologies,
       version=t.version+1,updated_at=now() WHERE t.profile_id=EXCLUDED.profile_id;
    ELSIF section='skill' THEN
     value:=public.jobix_text_field(item,'name',100);
     IF value IS NULL THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
     INSERT INTO public.profile_skills AS t(id,profile_id,name,sort_order)
     VALUES(item_id,p.id,value,public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,version=t.version+1,updated_at=now()
       WHERE t.profile_id=EXCLUDED.profile_id;
    ELSE
     value:=public.jobix_text_field(item,'name',100);
     IF value IS NULL OR jsonb_typeof(item->'proficiency') IS DISTINCT FROM 'string'
       OR item->>'proficiency' NOT IN ('BASIC','CONVERSATIONAL','PROFESSIONAL','FLUENT','NATIVE')
       THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
     INSERT INTO public.profile_languages AS t(id,profile_id,name,proficiency,sort_order)
     VALUES(item_id,p.id,value,item->>'proficiency',public.jobix_next_order(tbl,p.id))
     ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,proficiency=EXCLUDED.proficiency,
       version=t.version+1,updated_at=now() WHERE t.profile_id=EXCLUDED.profile_id;
    END IF;
    GET DIAGNOSTICS affected=ROW_COUNT;
   EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'DUPLICATE_ITEM';
   END;
   -- The id belongs to another profile: never move or overwrite it.
   IF affected=0 THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  END IF;
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

REVOKE ALL ON FUNCTION public.jobix_name_key(text),public.jobix_text_field(jsonb,text,integer),
 public.jobix_month_field(jsonb,text),public.jobix_url_field(jsonb,text),public.jobix_bool_field(jsonb,text),
 public.jobix_experience_complete(public.profile_experiences),public.jobix_education_complete(public.profile_education),
 public.jobix_project_complete(public.profile_projects),public.jobix_achievement_complete(public.profile_achievements),
 public.jobix_certification_complete(public.profile_certifications),public.jobix_month_text(date),
 public.jobix_next_order(text,uuid),public.jobix_recompute_text_profile(uuid),
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
