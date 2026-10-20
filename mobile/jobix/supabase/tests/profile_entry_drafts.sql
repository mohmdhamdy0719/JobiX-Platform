BEGIN;
INSERT INTO auth.users(id) VALUES
  ('65000000-0000-0000-0000-000000000001'),
  ('65000000-0000-0000-0000-000000000002');
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
BEGIN
  SELECT id,profile_version INTO p_id,version_now
    FROM public.career_profiles
    WHERE user_id='65000000-0000-0000-0000-000000000001'
      AND slot_number=1 AND status='ACTIVE';
  ASSERT p_id IS NOT NULL, 'synthetic profile fixture missing';

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
RESET ROLE;
ROLLBACK;
