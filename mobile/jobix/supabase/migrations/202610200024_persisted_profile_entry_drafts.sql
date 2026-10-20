BEGIN;

-- Drafts live on the existing authoritative section rows. Existing records
-- become Complete by default; no content is copied or rewritten.
ALTER TABLE public.profile_experiences
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_education
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_certifications
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_achievements
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_projects
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_skills
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_languages
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;
ALTER TABLE public.profile_volunteer_experiences
  ADD COLUMN is_draft boolean NOT NULL DEFAULT false;

-- Skill/language drafts may be missing their required value until completion.
ALTER TABLE public.profile_skills ALTER COLUMN name DROP NOT NULL;
ALTER TABLE public.profile_languages
  ALTER COLUMN name DROP NOT NULL,
  ALTER COLUMN proficiency DROP NOT NULL;

-- Volunteer entries use their own existing RPC path and need nullable fields
-- only while explicitly marked as a draft.
ALTER TABLE public.profile_volunteer_experiences
  ALTER COLUMN organization DROP NOT NULL,
  ALTER COLUMN role DROP NOT NULL,
  ALTER COLUMN start_month DROP NOT NULL,
  DROP CONSTRAINT profile_volunteer_experiences_check,
  ADD CONSTRAINT profile_volunteer_experiences_draft_or_valid CHECK (
    is_draft OR (
      organization IS NOT NULL AND role IS NOT NULL AND start_month IS NOT NULL
      AND ((is_current AND end_month IS NULL) OR
           (NOT is_current AND end_month IS NOT NULL AND end_month >= start_month))
    )
  );

-- Existing completeness accounting ignores rows explicitly persisted as Draft.
CREATE OR REPLACE FUNCTION public.jobix_experience_complete(e public.profile_experiences)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT NOT e.is_draft AND public.jobix_meaningful(e.job_title,1)
    AND public.jobix_meaningful(e.company,1) AND e.start_month IS NOT NULL
    AND (e.is_current OR e.end_month IS NOT NULL)
    AND public.jobix_meaningful(e.description,20)
$$;
CREATE OR REPLACE FUNCTION public.jobix_education_complete(e public.profile_education)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT NOT e.is_draft AND public.jobix_meaningful(e.degree,1)
    AND public.jobix_meaningful(e.institution,1)
    AND public.jobix_meaningful(e.field_of_study,1)
    AND e.start_month IS NOT NULL AND (e.is_current OR e.end_month IS NOT NULL)
$$;
CREATE OR REPLACE FUNCTION public.jobix_project_complete(e public.profile_projects)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT NOT e.is_draft AND public.jobix_meaningful(e.name,1)
    AND public.jobix_meaningful(e.role,1) AND e.project_month IS NOT NULL
    AND public.jobix_meaningful(e.description,20)
$$;
CREATE OR REPLACE FUNCTION public.jobix_achievement_complete(e public.profile_achievements)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT NOT e.is_draft AND public.jobix_meaningful(e.title,1)
    AND public.jobix_meaningful(e.issuer,1) AND e.achieved_month IS NOT NULL
    AND public.jobix_meaningful(e.description,20)
$$;

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
  IF EXISTS(SELECT 1 FROM public.profile_skills WHERE profile_id=profile
    AND NOT is_draft AND public.jobix_meaningful(name,1)) THEN points:=points+15; END IF;
  IF EXISTS(SELECT 1 FROM public.profile_languages WHERE profile_id=profile
    AND NOT is_draft AND public.jobix_meaningful(name,1)) THEN points:=points+10; END IF;
  UPDATE public.career_profiles SET completeness_percent=least(points,100),
    completeness_algorithm_version='core-profile-v2' WHERE id=profile;
END
$$;

-- profile_mutate remains the existing validated write path. This transaction-
-- local marker lets its INSERT/UPSERT set the authoritative status before its
-- completeness recomputation, avoiding a transient Complete state for Drafts.
CREATE FUNCTION public.jobix_profile_entry_draft_state() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE requested text;
BEGIN
  requested:=current_setting('jobix.entry_is_draft',true);
  IF requested IN ('true','false') THEN NEW.is_draft:=requested::boolean; END IF;
  RETURN NEW;
END
$$;
DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'profile_experiences','profile_education','profile_certifications',
    'profile_achievements','profile_projects','profile_skills',
    'profile_languages','profile_volunteer_experiences'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER jobix_entry_draft_state BEFORE INSERT OR UPDATE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public.jobix_profile_entry_draft_state()',
      table_name
    );
  END LOOP;
END
$$;

-- Keep the previous canonical read model intact, then filter persisted drafts
-- at the authoritative snapshot boundary used by Preview and PDF export.
ALTER FUNCTION public.jobix_profile_text_snapshot(uuid)
  RENAME TO jobix_profile_text_snapshot_pre_entry_drafts;
REVOKE ALL ON FUNCTION public.jobix_profile_text_snapshot_pre_entry_drafts(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.jobix_visible_profile_items(
  requested_profile uuid, section_name text, items jsonb
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE table_name text; result jsonb;
BEGIN
  table_name := CASE section_name
    WHEN 'experience' THEN 'profile_experiences'
    WHEN 'volunteer' THEN 'profile_volunteer_experiences'
    WHEN 'education' THEN 'profile_education'
    WHEN 'certification' THEN 'profile_certifications'
    WHEN 'achievement' THEN 'profile_achievements'
    WHEN 'project' THEN 'profile_projects'
    WHEN 'skill' THEN 'profile_skills'
    WHEN 'language' THEN 'profile_languages'
    ELSE NULL
  END;
  IF table_name IS NULL THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  EXECUTE format(
    'SELECT coalesce(jsonb_agg(e.item ORDER BY e.ordinality), ''[]''::jsonb)
       FROM jsonb_array_elements(coalesce($2, ''[]''::jsonb))
         WITH ORDINALITY AS e(item, ordinality)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.%I AS row
         WHERE row.profile_id=$1 AND row.id=(e.item->>''id'')::uuid
           AND row.is_draft
      )',
    table_name
  ) INTO result USING requested_profile, items;
  RETURN coalesce(result, '[]'::jsonb);
END
$$;

CREATE FUNCTION public.jobix_profile_text_snapshot(profile uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  result := public.jobix_profile_text_snapshot_pre_entry_drafts(profile);
  result := jsonb_set(result, '{experiences}',
    public.jobix_visible_profile_items(profile,'experience',result->'experiences'),false);
  result := jsonb_set(result, '{volunteer_experiences}',
    public.jobix_visible_profile_items(profile,'volunteer',result->'volunteer_experiences'),false);
  result := jsonb_set(result, '{education}',
    public.jobix_visible_profile_items(profile,'education',result->'education'),false);
  result := jsonb_set(result, '{certifications}',
    public.jobix_visible_profile_items(profile,'certification',result->'certifications'),false);
  result := jsonb_set(result, '{achievements}',
    public.jobix_visible_profile_items(profile,'achievement',result->'achievements'),false);
  result := jsonb_set(result, '{projects}',
    public.jobix_visible_profile_items(profile,'project',result->'projects'),false);
  result := jsonb_set(result, '{skills}',
    public.jobix_visible_profile_items(profile,'skill',result->'skills'),false);
  result := jsonb_set(result, '{languages}',
    public.jobix_visible_profile_items(profile,'language',result->'languages'),false);
  RETURN result;
END
$$;
REVOKE ALL ON FUNCTION public.jobix_visible_profile_items(uuid,text,jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jobix_profile_text_snapshot(uuid)
  FROM PUBLIC, anon, authenticated;

-- The explicit entry-save command carries the draft intent inside the
-- idempotency hash. Non-volunteer writes still pass through profile_mutate;
-- Volunteer retains its non-scoring semantics. Both paths are atomic with
-- the idempotency records and return the filtered canonical snapshot.
CREATE FUNCTION public.save_profile_entry(
  command_key uuid,
  requested_profile uuid,
  expected_profile_version bigint,
  mutation jsonb,
  is_draft boolean
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  uid uuid := auth.uid();
  p public.career_profiles;
  previous public.idempotency_records;
  prior_mutation public.idempotency_records;
  section_name text;
  kind text;
  item jsonb;
  item_id uuid;
  payload_hash text;
  mutation_hash text;
  draft_setting text;
  result jsonb;
  start_value date;
  end_value date;
  current_value boolean;
  affected integer;
  name_value text;
  role_value text;
  location_value text;
  description_value text;
  existing_draft boolean:=false;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF command_key IS NULL OR requested_profile IS NULL
     OR expected_profile_version IS NULL OR is_draft IS NULL
     OR jsonb_typeof(mutation) IS DISTINCT FROM 'object'
     OR (mutation-ARRAY['type','section','value'])<>'{}'::jsonb
     OR mutation->>'type' IS DISTINCT FROM 'upsert_item'
     OR jsonb_typeof(mutation->'value') IS DISTINCT FROM 'object'
  THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;

  PERFORM 1 FROM public.users WHERE id=uid AND status='ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
  SELECT * INTO p FROM public.career_profiles
   WHERE id=requested_profile AND user_id=uid AND status='ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;

  payload_hash:=encode(sha256(convert_to(jsonb_build_object(
    'profile',requested_profile,'version',expected_profile_version,
    'mutation',mutation,'is_draft',is_draft)::text,'UTF8')),'hex');
  SELECT * INTO previous FROM public.idempotency_records
   WHERE user_id=uid AND operation_type='profile.entry.save'
     AND idempotency_key=command_key;
  IF FOUND THEN
    IF previous.payload_hash<>payload_hash THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';
    END IF;
    RETURN previous.response_state;
  END IF;
  SELECT * INTO prior_mutation FROM public.idempotency_records
   WHERE user_id=uid AND operation_type='profile.mutate'
     AND idempotency_key=command_key;
  IF FOUND THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
  IF p.profile_version<>expected_profile_version THEN
    RAISE EXCEPTION 'VERSION_CONFLICT';
  END IF;

  section_name:=mutation->>'section';
  kind:=mutation->>'type';
  item:=mutation->'value';
  IF section_name IS NULL OR section_name NOT IN ('experience','volunteer','education','certification',
     'achievement','project','skill','language')
     OR jsonb_typeof(item->'id') IS DISTINCT FROM 'string'
     OR item->>'id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  item_id:=(item->>'id')::uuid;

  IF NOT is_draft THEN
    IF (section_name='experience' AND (
         nullif(btrim(item->>'job_title'),'') IS NULL OR
         nullif(btrim(item->>'company'),'') IS NULL OR
         nullif(btrim(item->>'start_month'),'') IS NULL OR
         (NOT public.jobix_bool_field(item,'is_current') AND
          nullif(btrim(item->>'end_month'),'') IS NULL)))
       OR (section_name='education' AND (
         nullif(btrim(item->>'degree'),'') IS NULL OR
         nullif(btrim(item->>'institution'),'') IS NULL OR
         nullif(btrim(item->>'field_of_study'),'') IS NULL OR
         nullif(btrim(item->>'start_month'),'') IS NULL OR
         (NOT public.jobix_bool_field(item,'is_current') AND
          nullif(btrim(item->>'end_month'),'') IS NULL)))
       OR (section_name='volunteer' AND (
         nullif(btrim(item->>'organization'),'') IS NULL OR
         nullif(btrim(item->>'role'),'') IS NULL OR
         nullif(btrim(item->>'start_month'),'') IS NULL OR
         (NOT public.jobix_bool_field(item,'is_current') AND
          nullif(btrim(item->>'end_month'),'') IS NULL)))
       OR (section_name='certification' AND (
         nullif(btrim(item->>'name'),'') IS NULL OR
         nullif(btrim(item->>'issuer'),'') IS NULL OR
         nullif(btrim(item->>'issue_month'),'') IS NULL))
       OR (section_name='achievement' AND (
         nullif(btrim(item->>'title'),'') IS NULL OR
         nullif(btrim(item->>'issuer'),'') IS NULL OR
         nullif(btrim(item->>'achieved_month'),'') IS NULL))
       OR (section_name='project' AND (
         nullif(btrim(item->>'name'),'') IS NULL OR
         nullif(btrim(item->>'role'),'') IS NULL OR
         nullif(btrim(item->>'project_month'),'') IS NULL))
       OR (section_name='skill' AND nullif(btrim(item->>'name'),'') IS NULL)
       OR (section_name='language' AND (
         nullif(btrim(item->>'name'),'') IS NULL OR
         nullif(btrim(item->>'proficiency'),'') IS NULL))
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  END IF;

  IF section_name<>'volunteer' THEN
    IF section_name='experience' THEN
      SELECT is_draft INTO existing_draft FROM public.profile_experiences
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='education' THEN
      SELECT is_draft INTO existing_draft FROM public.profile_education
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='certification' THEN
      SELECT is_draft INTO existing_draft FROM public.profile_certifications
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='achievement' THEN
      SELECT is_draft INTO existing_draft FROM public.profile_achievements
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='project' THEN
      SELECT is_draft INTO existing_draft FROM public.profile_projects
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='skill' THEN
      SELECT is_draft INTO existing_draft FROM public.profile_skills
       WHERE id=item_id AND profile_id=p.id;
    ELSE
      SELECT is_draft INTO existing_draft FROM public.profile_languages
       WHERE id=item_id AND profile_id=p.id;
    END IF;
    existing_draft:=coalesce(existing_draft,false);
    -- A nameless Skill or incomplete Language cannot pass the legacy complete
    -- mutation contract. Store those explicit Draft states through this same
    -- atomic command, then retain the old path for promotion to Complete.
    IF is_draft AND section_name IN ('skill','language') THEN
      IF section_name='skill' THEN
        name_value:=public.jobix_text_field(item,'name',100);
        IF (item-ARRAY['id','name'])<>'{}'::jsonb THEN
          RAISE EXCEPTION 'VALIDATION_FAILED';
        END IF;
        INSERT INTO public.profile_skills AS existing(
          id,profile_id,name,sort_order,is_draft
        ) VALUES(item_id,p.id,name_value,
          public.jobix_next_order('profile_skills',p.id),true)
        ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,
          is_draft=true,version=existing.version+1,updated_at=now()
        WHERE existing.profile_id=EXCLUDED.profile_id;
      ELSE
        name_value:=public.jobix_text_field(item,'name',100);
        role_value:=public.jobix_text_field(item,'proficiency',32);
        IF (item-ARRAY['id','name','proficiency'])<>'{}'::jsonb
          OR (role_value IS NOT NULL AND role_value NOT IN
            ('BASIC','CONVERSATIONAL','PROFESSIONAL','FLUENT','NATIVE'))
        THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
        INSERT INTO public.profile_languages AS existing(
          id,profile_id,name,proficiency,sort_order,is_draft
        ) VALUES(item_id,p.id,name_value,role_value,
          public.jobix_next_order('profile_languages',p.id),true)
        ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,
          proficiency=EXCLUDED.proficiency,is_draft=true,
          version=existing.version+1,updated_at=now()
        WHERE existing.profile_id=EXCLUDED.profile_id;
      END IF;
      GET DIAGNOSTICS affected=ROW_COUNT;
      IF affected=0 THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
      PERFORM public.jobix_recompute_text_profile(p.id);
      UPDATE public.career_profiles SET profile_version=profile_version+1,
        updated_at=now() WHERE id=p.id;
      result:=jsonb_build_object(
        'request_id',command_key,'operation_id',command_key,'state','SUCCEEDED',
        'data',public.jobix_profile_text_snapshot(p.id),
        'authoritative_version',p.profile_version+1,'error',NULL
      );
      mutation_hash:=encode(sha256(convert_to(jsonb_build_object(
        'profile',requested_profile,'version',expected_profile_version,
        'mutation',mutation)::text,'UTF8')),'hex');
      INSERT INTO public.idempotency_records(
        user_id,operation_type,idempotency_key,payload_hash,response_state
      ) VALUES(uid,'profile.mutate',command_key,mutation_hash,result);
    ELSE
      draft_setting:=current_setting('jobix.entry_is_draft',true);
      PERFORM set_config('jobix.entry_is_draft',is_draft::text,true);
    -- The legacy mutation performs all existing field, URL, date, ownership,
    -- duplicate, completeness, and profile-version checks.
      BEGIN
        result:=public.profile_mutate(
          command_key,requested_profile,expected_profile_version,mutation
        );
      EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('jobix.entry_is_draft',coalesce(draft_setting,''),true);
        RAISE;
      END;
      PERFORM set_config('jobix.entry_is_draft',coalesce(draft_setting,''),true);
    IF section_name='experience' THEN
      UPDATE public.profile_experiences SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='education' THEN
      UPDATE public.profile_education SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='certification' THEN
      UPDATE public.profile_certifications SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='achievement' THEN
      UPDATE public.profile_achievements SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='project' THEN
      UPDATE public.profile_projects SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    ELSIF section_name='skill' THEN
      UPDATE public.profile_skills SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    ELSE
      UPDATE public.profile_languages SET is_draft=$5,updated_at=now()
       WHERE id=item_id AND profile_id=p.id;
    END IF;
    GET DIAGNOSTICS affected=ROW_COUNT;
    IF affected=0 THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    result:=jsonb_build_object(
      'request_id',command_key,'operation_id',command_key,'state','SUCCEEDED',
      'data',public.jobix_profile_text_snapshot(p.id),
      'authoritative_version',p.profile_version+1,'error',NULL
    );
    UPDATE public.idempotency_records SET response_state=result
     WHERE user_id=uid AND operation_type='profile.mutate'
       AND idempotency_key=command_key;
    END IF;
  ELSE
    IF (item-ARRAY['id','organization','role','location','start_month','end_month',
       'is_current','description'])<>'{}'::jsonb
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
    name_value:=public.jobix_text_field(item,'organization',200);
    role_value:=public.jobix_text_field(item,'role',200);
    location_value:=public.jobix_text_field(item,'location',200);
    description_value:=public.jobix_text_field(item,'description',1500);
    current_value:=public.jobix_bool_field(item,'is_current');
    start_value:=public.jobix_month_field(item,'start_month');
    end_value:=public.jobix_month_field(item,'end_month');
    IF (current_value AND end_value IS NOT NULL)
       OR (end_value IS NOT NULL AND start_value IS NOT NULL AND end_value<start_value)
       OR (NOT is_draft AND start_value IS NULL)
    THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
    INSERT INTO public.profile_volunteer_experiences AS existing(
      id,profile_id,organization,role,location,start_month,end_month,is_current,
      description,sort_order,is_draft
    ) VALUES(
      item_id,p.id,name_value,role_value,location_value,start_value,end_value,
      current_value,description_value,
      public.jobix_next_order('profile_volunteer_experiences',p.id),is_draft
    )
    ON CONFLICT(id) DO UPDATE SET
      organization=EXCLUDED.organization,role=EXCLUDED.role,
      location=EXCLUDED.location,start_month=EXCLUDED.start_month,
      end_month=EXCLUDED.end_month,is_current=EXCLUDED.is_current,
      description=EXCLUDED.description,is_draft=EXCLUDED.is_draft,
      version=existing.version+1,updated_at=now()
    WHERE existing.profile_id=EXCLUDED.profile_id;
    GET DIAGNOSTICS affected=ROW_COUNT;
    IF affected=0 THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    UPDATE public.career_profiles SET profile_version=profile_version+1,
      updated_at=now() WHERE id=p.id;
    result:=jsonb_build_object(
      'request_id',command_key,'operation_id',command_key,'state','SUCCEEDED',
      'data',public.jobix_profile_text_snapshot(p.id),
      'authoritative_version',p.profile_version+1,'error',NULL
    );
    mutation_hash:=encode(sha256(convert_to(jsonb_build_object(
      'profile',requested_profile,'version',expected_profile_version,
      'mutation',mutation)::text,'UTF8')),'hex');
    INSERT INTO public.idempotency_records(
      user_id,operation_type,idempotency_key,payload_hash,response_state
    ) VALUES(uid,'profile.mutate',command_key,mutation_hash,result);
  END IF;

  INSERT INTO public.idempotency_records(
    user_id,operation_type,idempotency_key,payload_hash,response_state
  ) VALUES(uid,'profile.entry.save',command_key,payload_hash,result);
  RETURN result;
END
$$;

REVOKE ALL ON FUNCTION public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.save_profile_entry(uuid,uuid,bigint,jsonb,boolean)
  TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
