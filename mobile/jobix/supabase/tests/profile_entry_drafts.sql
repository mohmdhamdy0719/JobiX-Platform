BEGIN;
INSERT INTO auth.users(id) VALUES
  ('65000000-0000-0000-0000-000000000001'),
  ('65000000-0000-0000-0000-000000000002'),
  ('65000000-0000-0000-0000-000000000003');
SET ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '65000000-0000-0000-0000-000000000001',
  true
);

DO $test$
DECLARE
  p_id uuid;
  version_now bigint;
  item_id uuid:='65000000-0000-0000-0000-00000000e001';
  command_id uuid:='65000000-0000-0000-0000-000000000101';
  mutation jsonb;
  response jsonb;
  replay jsonb;
  score_before numeric;
  section_key text;
  config_before jsonb;
BEGIN
  SELECT id,profile_version INTO p_id,version_now
    FROM public.career_profiles
    WHERE user_id='65000000-0000-0000-0000-000000000001'
      AND slot_number=1 AND status='ACTIVE';
  ASSERT p_id IS NOT NULL, 'synthetic profile fixture missing';
  PERFORM public.save_resume_layout(
    gen_random_uuid(),p_id,version_now,0,'en','["certification"]',
    '["skill","summary","target_role","experience","volunteer","education","certification","achievement","project","language"]'
  );
  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  config_before:=public.read_resume_configuration(p_id);
  ASSERT config_before IS NOT NULL, 'saved Layout fixture missing';
  FOREACH section_key IN ARRAY ARRAY[
    'experience','volunteer','education','certification','achievement',
    'project','skill','language'
  ] LOOP
    BEGIN
      PERFORM public.save_profile_entry(
        gen_random_uuid(),p_id,version_now,
        jsonb_build_object('type','upsert_item','section',section_key,
          'value',jsonb_build_object('id',gen_random_uuid())),
        false
      );
      RAISE EXCEPTION 'assertion: incomplete entry became Complete';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF;
    END;
  END LOOP;
  ASSERT (SELECT cp.profile_version FROM public.career_profiles cp WHERE cp.id=p_id)
    =version_now, 'rejected incomplete saves changed the profile';

  mutation:=jsonb_build_object(
    'type','upsert_item','section','experience',
    'value',jsonb_build_object('id',item_id,'job_title','Analyst')
  );
  response:=public.save_profile_entry(
    command_id,p_id,version_now,mutation,true
  );
  ASSERT response->>'state'='SUCCEEDED', 'incomplete entry was not saved';
  ASSERT (SELECT e.is_draft FROM public.profile_experiences e
    WHERE e.id=item_id AND e.profile_id=p_id), 'entry status was not Draft';
  ASSERT jsonb_array_length(response->'data'->'experiences')=0,
    'Draft leaked into canonical Resume snapshot';
  ASSERT (SELECT cp.profile_version FROM public.career_profiles cp WHERE cp.id=p_id)
    =version_now+1, 'Draft save did not advance authoritative version';

  replay:=public.save_profile_entry(
    command_id,p_id,version_now,mutation,true
  );
  ASSERT replay=response, 'same request did not replay its acknowledged result';
  BEGIN
    PERFORM public.save_profile_entry(
      command_id,p_id,version_now,mutation,false
    );
    RAISE EXCEPTION 'assertion: idempotency key reuse accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'IDEMPOTENCY_KEY_REUSE' THEN RAISE; END IF;
  END;

  -- Completing the same item promotes its original ID only after an
  -- authoritative save; the renderer now sees it.
  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  mutation:=jsonb_build_object(
    'type','upsert_item','section','experience',
    'value',jsonb_build_object(
      'id',item_id,'job_title','Analyst','company','Example Company',
      'start_month','2022-01','is_current',true,
      'description','Reviewed records and prepared reliable reports for the team.'
    )
  );
  response:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000102',
    p_id,version_now,mutation,false
  );
  ASSERT NOT (SELECT e.is_draft FROM public.profile_experiences e
    WHERE e.id=item_id AND e.profile_id=p_id), 'Complete save remained Draft';
  ASSERT response->'data'->'experiences'->0->>'id'=item_id::text,
    'completion created a different record identity';

  -- A fully populated row explicitly marked Draft is still filtered and does
  -- not contribute completeness while the trigger is active.
  SELECT cp.completeness_percent INTO score_before
    FROM public.career_profiles cp WHERE cp.id=p_id;
  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  mutation:=jsonb_build_object(
    'type','upsert_item','section','project',
    'value',jsonb_build_object(
      'id','65000000-0000-0000-0000-00000000f001',
      'name','Example project','role','Contributor',
      'project_month','2023-03',
      'description','A complete illustrative project entry with sufficient detail.'
    )
  );
  response:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000103',
    p_id,version_now,mutation,true
  );
  ASSERT (SELECT cp.completeness_percent FROM public.career_profiles cp
    WHERE cp.id=p_id)=score_before, 'Draft changed profile completeness';
  ASSERT jsonb_array_length(response->'data'->'projects')=0,
    'Draft project leaked into the canonical snapshot';

  -- Nullable Volunteer, Skill, and Language fields can also be retained as
  -- drafts, and are absent from all canonical arrays.
  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  mutation:=jsonb_build_object(
    'type','upsert_item','section','volunteer',
    'value',jsonb_build_object(
      'id','65000000-0000-0000-0000-000000007001',
      'organization','Community Group','role',''
    )
  );
  response:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000104',
    p_id,version_now,mutation,true
  );
  ASSERT jsonb_array_length(response->'data'->'volunteer_experiences')=0;

  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  mutation:=jsonb_build_object(
    'type','upsert_item','section','skill',
    'value',jsonb_build_object('id','65000000-0000-0000-0000-000000008001')
  );
  response:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000105',
    p_id,version_now,mutation,true
  );
  ASSERT jsonb_array_length(response->'data'->'skills')=0;

  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  mutation:=jsonb_build_object(
    'type','upsert_item','section','language',
    'value',jsonb_build_object(
      'id','65000000-0000-0000-0000-000000009001','name','Arabic'
    )
  );
  response:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000106',
    p_id,version_now,mutation,true
  );
  ASSERT jsonb_array_length(response->'data'->'languages')=0;

  FOREACH section_key IN ARRAY ARRAY['education','certification','achievement'] LOOP
    SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
      WHERE cp.id=p_id;
    response:=public.save_profile_entry(
      gen_random_uuid(),p_id,version_now,
      jsonb_build_object('type','upsert_item','section',section_key,
        'value',jsonb_build_object('id',gen_random_uuid())),
      true
    );
  END LOOP;
  ASSERT jsonb_array_length(response->'data'->'education')=0;
  ASSERT jsonb_array_length(response->'data'->'certifications')=0;
  ASSERT jsonb_array_length(response->'data'->'achievements')=0;
  ASSERT public.read_resume_configuration(p_id)=config_before,
    'saving Drafts changed saved Resume Layout configuration';

  -- Discard is also status-guarded on the server. A stale Draft card must not
  -- delete a now-Complete entry even with a freshly loaded profile version.
  SELECT cp.profile_version INTO version_now FROM public.career_profiles cp
    WHERE cp.id=p_id;
  BEGIN
    PERFORM public.save_profile_entry(
      gen_random_uuid(),p_id,version_now,
      jsonb_build_object('type','delete_item','section','experience',
        'value',jsonb_build_object('id',item_id)),
      true
    );
    RAISE EXCEPTION 'assertion: Draft discard removed a Complete entry';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'VERSION_CONFLICT' THEN RAISE; END IF;
  END;
  ASSERT EXISTS(SELECT 1 FROM public.profile_experiences e
    WHERE e.id=item_id AND NOT e.is_draft);
  mutation:=jsonb_build_object('type','delete_item','section','project',
    'value',jsonb_build_object('id','65000000-0000-0000-0000-00000000f001'));
  response:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000109',
    p_id,version_now,mutation,true
  );
  replay:=public.save_profile_entry(
    '65000000-0000-0000-0000-000000000109',
    p_id,version_now,mutation,true
  );
  ASSERT replay=response, 'Draft discard retry did not replay the same result';
  ASSERT NOT EXISTS(SELECT 1 FROM public.profile_projects e
    WHERE e.id='65000000-0000-0000-0000-00000000f001');
  ASSERT EXISTS(SELECT 1 FROM public.profile_experiences e WHERE e.id=item_id);

  -- RLS prevents another account from discovering these persisted Drafts.
  PERFORM set_config(
    'request.jwt.claim.sub',
    '65000000-0000-0000-0000-000000000002',
    true
  );
  ASSERT NOT EXISTS(SELECT 1 FROM public.profile_experiences e
    WHERE e.id=item_id), 'another account read a Draft row';
  ASSERT NOT EXISTS(SELECT 1 FROM public.profile_projects e
    WHERE e.id='65000000-0000-0000-0000-00000000f001'),
    'another account read a project Draft';
  BEGIN
    PERFORM public.save_profile_entry(
      '65000000-0000-0000-0000-000000000107',
      p_id,1,mutation,true
    );
    RAISE EXCEPTION 'assertion: cross-account draft mutation succeeded';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'FORBIDDEN' THEN RAISE; END IF;
  END;
END
$test$;

-- The Complete -> incomplete edit case must preserve the authoritative entry
-- for every section, including legacy-created records and non-scoring Volunteer.
DO $test$
DECLARE
  actor uuid:='65000000-0000-0000-0000-000000000003';
  p_id uuid;
  version_now bigint;
  original_id uuid;
  draft_id uuid;
  discard_id uuid;
  command_id uuid;
  section_key text;
  table_name text;
  array_key text;
  complete_value jsonb;
  original_row jsonb;
  actual_row jsonb;
  original_array jsonb;
  mutation jsonb;
  response jsonb;
  replay jsonb;
  config_before jsonb;
  rejected_keys uuid[]:=ARRAY[]::uuid[];
  rejected_key uuid;
  original_entries jsonb:='{}';
  score_before numeric;
  visible boolean;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  SELECT cp.id,cp.profile_version INTO p_id,version_now
    FROM public.career_profiles cp WHERE cp.user_id=actor AND cp.slot_number=1;
  PERFORM public.save_resume_layout(
    gen_random_uuid(),p_id,version_now,0,'en','["certification"]',
    '["skill","summary","target_role","experience","volunteer","education","certification","achievement","project","language"]'
  );
  config_before:=public.read_resume_configuration(p_id);
  ASSERT config_before IS NOT NULL;
  FOREACH section_key IN ARRAY ARRAY[
    'experience','volunteer','education','certification','achievement',
    'project','skill','language'
  ] LOOP
    table_name:=CASE section_key
      WHEN 'experience' THEN 'profile_experiences'
      WHEN 'volunteer' THEN 'profile_volunteer_experiences'
      WHEN 'education' THEN 'profile_education'
      WHEN 'certification' THEN 'profile_certifications'
      WHEN 'achievement' THEN 'profile_achievements'
      WHEN 'project' THEN 'profile_projects'
      WHEN 'skill' THEN 'profile_skills'
      WHEN 'language' THEN 'profile_languages' END;
    array_key:=CASE section_key
      WHEN 'experience' THEN 'experiences'
      WHEN 'volunteer' THEN 'volunteer_experiences'
      WHEN 'certification' THEN 'certifications'
      WHEN 'achievement' THEN 'achievements'
      WHEN 'project' THEN 'projects'
      WHEN 'skill' THEN 'skills'
      WHEN 'language' THEN 'languages'
      ELSE 'education' END;
    complete_value:=CASE section_key
      WHEN 'experience' THEN '{"job_title":"Analyst","company":"Example","start_month":"2022-01","is_current":true}'
      WHEN 'volunteer' THEN '{"organization":"Community Group","role":"Coordinator","start_month":"2022-01","is_current":true}'
      WHEN 'education' THEN '{"degree":"Bachelor","institution":"Example University","field_of_study":"Commerce","start_month":"2018-01","end_month":"2022-01"}'
      WHEN 'certification' THEN '{"name":"Example certificate","issuer":"Example","issue_month":"2022-01"}'
      WHEN 'achievement' THEN '{"title":"Example achievement","issuer":"Example","achieved_month":"2022-01"}'
      WHEN 'project' THEN '{"name":"Example project","role":"Coordinator","project_month":"2022-01"}'
      WHEN 'skill' THEN '{"name":"Communication"}'
      WHEN 'language' THEN '{"name":"Arabic","proficiency":"NATIVE"}'
      END::jsonb;
    original_id:=gen_random_uuid();
    SELECT cp.profile_version INTO version_now FROM public.career_profiles cp WHERE cp.id=p_id;
    -- The legacy protocol still creates visible, non-Draft rows by default.
    response:=public.profile_mutate(gen_random_uuid(),p_id,version_now,
      jsonb_build_object('type','upsert_item','section',section_key,
        'value',complete_value||jsonb_build_object('id',original_id)));
    EXECUTE format('SELECT to_jsonb(e) FROM public.%I e WHERE e.id=$1',table_name)
      INTO original_row USING original_id;
    ASSERT original_row->>'is_draft'='false', 'legacy row became a Draft';
    original_array:=response->'data'->array_key;
    ASSERT jsonb_array_length(original_array)=1, 'legacy row not visible';
    SELECT cp.profile_version,cp.completeness_percent INTO version_now,score_before
      FROM public.career_profiles cp WHERE cp.id=p_id;
    rejected_key:=gen_random_uuid();
    rejected_keys:=array_append(rejected_keys,rejected_key);
    BEGIN
      PERFORM public.save_profile_entry(rejected_key,p_id,version_now,
        jsonb_build_object('type','upsert_item','section',section_key,
          'value',jsonb_build_object('id',original_id)),true);
      RAISE EXCEPTION 'assertion: Complete entry was converted to Draft';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF;
    END;
    EXECUTE format('SELECT to_jsonb(e) FROM public.%I e WHERE e.id=$1',table_name)
      INTO actual_row USING original_id;
    ASSERT actual_row=original_row, 'rejected edit changed saved fields/status/metadata';
    ASSERT (SELECT cp.profile_version=version_now AND cp.completeness_percent=score_before
      FROM public.career_profiles cp WHERE cp.id=p_id), 'rejected edit changed profile';
    -- The private ledger and canonical helper are intentionally unavailable
    -- to authenticated. Their assertions run after RESET ROLE below, using
    -- only these synthetic fixture keys and original IDs.
    original_entries:=original_entries||
      jsonb_build_object(array_key,jsonb_build_object('id',original_id));

    -- Genuine new Drafts remain valid and retain their identity after reopening.
    draft_id:=gen_random_uuid();
    command_id:=gen_random_uuid();
    mutation:=jsonb_build_object('type','upsert_item','section',section_key,
      'value',jsonb_build_object('id',draft_id));
    response:=public.save_profile_entry(command_id,p_id,version_now,mutation,true);
    replay:=public.save_profile_entry(command_id,p_id,version_now,mutation,true);
    ASSERT replay=response, 'Draft replay changed its result';
    ASSERT response->'data'->array_key=original_array, 'new Draft hid the existing entry';
    EXECUTE format('SELECT e.is_draft FROM public.%I e WHERE e.id=$1',table_name)
      INTO visible USING draft_id;
    ASSERT visible, 'saved Draft not available to its owner';

    PERFORM set_config('request.jwt.claim.sub','65000000-0000-0000-0000-000000000002',true);
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I e WHERE e.id=$1)',table_name)
      INTO visible USING draft_id;
    ASSERT NOT visible, 'another account can read the saved Draft';
    BEGIN
      PERFORM public.save_profile_entry(gen_random_uuid(),p_id,version_now,mutation,true);
      RAISE EXCEPTION 'assertion: another account changed the saved Draft';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'FORBIDDEN' THEN RAISE; END IF;
    END;
    PERFORM set_config('request.jwt.claim.sub',actor::text,true);

    -- Stale promotion must not modify either the Draft or the Complete row.
    IF section_key IN ('skill','language') THEN
      SELECT cp.profile_version INTO version_now FROM public.career_profiles cp WHERE cp.id=p_id;
      BEGIN
        PERFORM public.save_profile_entry(gen_random_uuid(),p_id,version_now,
          jsonb_build_object('type','upsert_item','section',section_key,
            'value',complete_value||jsonb_build_object('id',draft_id)),false);
        RAISE EXCEPTION 'assertion: duplicate Complete name accepted';
      EXCEPTION WHEN raise_exception THEN
        IF SQLERRM<>'DUPLICATE_ITEM' THEN RAISE; END IF;
      END;
      -- Keep the stale-version test below stale after this read-only failure.
      version_now:=version_now-1;
      complete_value:=complete_value||jsonb_build_object('name','Second '||section_key);
    END IF;
    mutation:=jsonb_build_object('type','upsert_item','section',section_key,
      'value',complete_value||jsonb_build_object('id',draft_id));
    BEGIN
      PERFORM public.save_profile_entry(gen_random_uuid(),p_id,version_now,mutation,false);
      RAISE EXCEPTION 'assertion: stale Draft promotion succeeded';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'VERSION_CONFLICT' THEN RAISE; END IF;
    END;
    SELECT cp.profile_version INTO version_now FROM public.career_profiles cp WHERE cp.id=p_id;
    command_id:=gen_random_uuid();
    response:=public.save_profile_entry(command_id,p_id,version_now,mutation,false);
    replay:=public.save_profile_entry(command_id,p_id,version_now,mutation,false);
    ASSERT replay=response, 'completion retry was not idempotent';
    ASSERT jsonb_array_length(response->'data'->array_key)=2;
    ASSERT (response->'data'->array_key) @> jsonb_build_array(jsonb_build_object('id',draft_id)),
      'completion did not preserve Draft identity';
    EXECUTE format('SELECT NOT e.is_draft FROM public.%I e WHERE e.id=$1',table_name)
      INTO visible USING draft_id;
    ASSERT visible, 'promoted entry is not Complete';
    SELECT cp.profile_version INTO version_now FROM public.career_profiles cp WHERE cp.id=p_id;
    BEGIN
      PERFORM public.save_profile_entry(gen_random_uuid(),p_id,version_now,
        jsonb_build_object('type','delete_item','section',section_key,
          'value',jsonb_build_object('id',draft_id)),true);
      RAISE EXCEPTION 'assertion: stale Draft discard deleted a Complete entry';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'VERSION_CONFLICT' THEN RAISE; END IF;
    END;

    discard_id:=gen_random_uuid();
    PERFORM public.save_profile_entry(gen_random_uuid(),p_id,version_now,
      jsonb_build_object('type','upsert_item','section',section_key,
        'value',jsonb_build_object('id',discard_id)),true);
    SELECT cp.profile_version INTO version_now FROM public.career_profiles cp WHERE cp.id=p_id;
    mutation:=jsonb_build_object('type','delete_item','section',section_key,
      'value',jsonb_build_object('id',discard_id));
    command_id:=gen_random_uuid();
    response:=public.save_profile_entry(command_id,p_id,version_now,mutation,true);
    replay:=public.save_profile_entry(command_id,p_id,version_now,mutation,true);
    ASSERT replay=response, 'discard retry was not idempotent';
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I e WHERE e.id=$1)',table_name)
      INTO visible USING discard_id;
    ASSERT NOT visible, 'discard did not remove the Draft';
    EXECUTE format('SELECT to_jsonb(e) FROM public.%I e WHERE e.id=$1',table_name)
      INTO actual_row USING original_id;
    ASSERT actual_row=original_row, 'Draft lifecycle changed the original Complete entry';
    ASSERT public.read_resume_configuration(p_id)=config_before,
      'Draft lifecycle changed saved Layout order/visibility';
    RAISE NOTICE 'PASS: % Complete preservation, Draft replay/promotion/discard, RLS and Layout', section_key;
  END LOOP;
  PERFORM set_config('jobix.test_rejected_entry_keys',to_jsonb(rejected_keys)::text,true);
  PERFORM set_config('jobix.test_original_entries',original_entries::text,true);
END
$test$;
RESET ROLE;
DO $test$
DECLARE
  actor uuid:='65000000-0000-0000-0000-000000000001';
  p_id uuid;
  document_source jsonb;
  array_key text;
BEGIN
  ASSERT jsonb_array_length(current_setting('jobix.test_rejected_entry_keys')::jsonb)=8;
  ASSERT NOT EXISTS(
    SELECT 1 FROM public.idempotency_records r
    WHERE r.idempotency_key::text IN (
      SELECT jsonb_array_elements_text(current_setting('jobix.test_rejected_entry_keys')::jsonb)
    )
  ), 'rejected edit recorded an acknowledgement';
  SELECT cp.id INTO p_id FROM public.career_profiles cp
    WHERE cp.user_id=actor AND cp.slot_number=1;
  -- This is the actual server document-source function, not a Flutter filter.
  -- It prepares no document, creates no export, and consumes no Credits.
  document_source:=public.jobix_export_source(actor,p_id)->'source';
  ASSERT jsonb_array_length(document_source#>'{profile,experiences}')=1;
  FOREACH array_key IN ARRAY ARRAY[
    'volunteer_experiences','education','certifications','achievements',
    'projects','skills','languages'
  ] LOOP
    ASSERT jsonb_array_length(document_source->'profile'->array_key)=0,
      'Draft leaked into server-authoritative PDF source';
  END LOOP;
  ASSERT NOT EXISTS(SELECT 1 FROM public.export_jobs e WHERE e.user_id=actor);
  ASSERT NOT EXISTS(SELECT 1 FROM public.credit_transactions c
    WHERE c.user_id=actor AND c.delta<0);
  actor:='65000000-0000-0000-0000-000000000003';
  SELECT cp.id INTO p_id FROM public.career_profiles cp
    WHERE cp.user_id=actor AND cp.slot_number=1;
  document_source:=public.jobix_export_source(actor,p_id)->'source';
  FOREACH array_key IN ARRAY ARRAY[
    'experiences','volunteer_experiences','education','certifications',
    'achievements','projects','skills','languages'
  ] LOOP
    ASSERT jsonb_array_length(document_source->'profile'->array_key)=2,
      'PDF source lost an original or same-ID promoted Complete entry';
    ASSERT (document_source->'profile'->array_key) @>
      jsonb_build_array(current_setting('jobix.test_original_entries')::jsonb->array_key),
      'rejected edit removed the original Complete entry from canonical PDF output';
  END LOOP;
  ASSERT NOT EXISTS(SELECT 1 FROM public.export_jobs e WHERE e.user_id=actor);
  ASSERT NOT EXISTS(SELECT 1 FROM public.credit_transactions c
    WHERE c.user_id=actor AND c.delta<0);
END
$test$;
ROLLBACK;
