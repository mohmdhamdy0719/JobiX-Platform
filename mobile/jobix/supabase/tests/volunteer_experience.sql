DO $test$
BEGIN
 ASSERT NOT EXISTS(
  (SELECT id,value FROM phase2_profiles_before EXCEPT SELECT id,to_jsonb(p) FROM public.career_profiles p)
  UNION ALL
  (SELECT id,to_jsonb(p) FROM public.career_profiles p EXCEPT SELECT id,value FROM phase2_profiles_before)
 ), 'migration changed an existing profile';
 ASSERT NOT EXISTS(
  (SELECT user_id,value FROM phase2_ai_before EXCEPT SELECT user_id,to_jsonb(a) FROM public.ai_allowance_accounts a)
  UNION ALL
  (SELECT user_id,to_jsonb(a) FROM public.ai_allowance_accounts a EXCEPT SELECT user_id,value FROM phase2_ai_before)
 ), 'migration changed AI state';
 ASSERT NOT EXISTS(SELECT 1 FROM phase2_ack_before b JOIN public.idempotency_records i
  USING(user_id,operation_type,idempotency_key) WHERE b.value<>to_jsonb(i));
 ASSERT (SELECT value FROM phase2_algorithm_before)=
  pg_get_functiondef('public.jobix_recompute_text_profile(uuid)'::regprocedure);
 ASSERT NOT has_function_privilege('authenticated','public.jobix_profile_mutate_pre_volunteer(uuid,uuid,bigint,jsonb)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.jobix_profile_text_snapshot_pre_volunteer(uuid)','EXECUTE');
 ASSERT NOT has_function_privilege('anon','public.profile_mutate(uuid,uuid,bigint,jsonb)','EXECUTE');
 ASSERT NOT has_table_privilege('authenticated','public.profile_volunteer_experiences','INSERT');
 ASSERT NOT has_table_privilege('authenticated','public.profile_volunteer_experiences','UPDATE');
 ASSERT NOT has_table_privilege('authenticated','public.profile_volunteer_experiences','DELETE');
END $test$;

CREATE FUNCTION pg_temp.volunteer_state(profile uuid) RETURNS jsonb
LANGUAGE sql AS $$
 SELECT jsonb_build_object(
  'profile',(SELECT to_jsonb(p)-ARRAY['profile_version','updated_at'] FROM public.career_profiles p WHERE id=profile),
  'ai',(SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY user_id),'[]') FROM public.ai_allowance_accounts a),
  'wallet',(SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY user_id),'[]') FROM public.credit_accounts c),
  'ledger',(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]') FROM public.credit_transactions t)
 )
$$;
CREATE FUNCTION pg_temp.expect_volunteer_error(profile uuid, version bigint, mutation jsonb, wanted text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN
  PERFORM public.profile_mutate(gen_random_uuid(),profile,version,mutation);
  RAISE EXCEPTION 'assertion: accepted invalid/forbidden command';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>wanted THEN RAISE; END IF;
 END;
END $$;
CREATE TEMP TABLE phase2_security_fixture(owner_id uuid, other_id uuid, profile_id uuid, item_id uuid);
DO $test$
DECLARE legacy phase2_legacy_ack; p public.career_profiles; response jsonb;
 other uuid:=gen_random_uuid(); other_profile uuid; item_id uuid; command uuid;
 mutation jsonb; original jsonb; state_before jsonb; version_before bigint;
 percentage integer; invalid jsonb;
BEGIN
 SELECT * INTO legacy FROM phase2_legacy_ack;
 PERFORM set_config('request.jwt.claim.sub',legacy.owner_id::text,true);
 ASSERT public.profile_mutate(legacy.command_key,legacy.profile_id,legacy.version,legacy.mutation)=legacy.response,
  'old acknowledgement must replay byte-for-byte even without the new array';
 ASSERT public.first_career_profile()->'volunteer_experiences'='[]'::jsonb;
 INSERT INTO auth.users(id,email) VALUES(other,'other-volunteer-'||other||'@example.invalid');
 SELECT id INTO other_profile FROM public.career_profiles WHERE user_id=other AND slot_number=1;
 original:=jsonb_build_object('id',gen_random_uuid(),'organization',' Community Group ',
  'role',' Coordinator ','start_month','2024-01','is_current',true,'end_month','stale ignored input',
  'description','');

 -- No credit/transition effects with empty, short or long descriptions. These
 -- are disposable fixture states, not production writes or a new formula.
 FOREACH percentage IN ARRAY ARRAY[0,45,50,55] LOOP
  UPDATE public.career_profiles SET completeness_percent=percentage WHERE id=legacy.profile_id;
  state_before:=pg_temp.volunteer_state(legacy.profile_id);
  SELECT * INTO p FROM public.career_profiles WHERE id=legacy.profile_id;
  item_id:=gen_random_uuid(); command:=gen_random_uuid();
  mutation:=jsonb_build_object('type','upsert_item','section','volunteer',
   'value',original||jsonb_build_object('id',item_id));
  response:=public.profile_mutate(command,p.id,p.profile_version,mutation);
  ASSERT (response->'data'->>'completeness_percent')::numeric=percentage;
  ASSERT response->'data'->'volunteer_experiences'->0->>'organization'='Community Group';
  ASSERT response->'data'->'volunteer_experiences'->0->>'role'='Coordinator';
  ASSERT response->'data'->'volunteer_experiences'->0->>'end_month' IS NULL;
  ASSERT response->'data'->'volunteer_experiences'->0->'complete'='false'::jsonb;
  ASSERT pg_temp.volunteer_state(p.id)=state_before;
  ASSERT public.profile_mutate(command,p.id,p.profile_version,mutation)=response;
  ASSERT pg_temp.volunteer_state(p.id)=state_before;
  BEGIN
   PERFORM public.profile_mutate(command,p.id,p.profile_version,
    mutation||jsonb_build_object('value',original||jsonb_build_object('id',item_id,'role','Changed')));
   RAISE EXCEPTION 'assertion: key reuse accepted';
  EXCEPTION WHEN raise_exception THEN
   IF SQLERRM<>'IDEMPOTENCY_KEY_REUSE' THEN RAISE; END IF;
  END;
  PERFORM pg_temp.expect_volunteer_error(p.id,p.profile_version,mutation,'VERSION_CONFLICT');
  SELECT profile_version INTO version_before FROM public.career_profiles WHERE id=p.id;
  -- Update; sort order is retained, item version advances and short prose saves.
  response:=public.profile_mutate(gen_random_uuid(),p.id,version_before,
   jsonb_build_object('type','upsert_item','section','volunteer',
    'value',original||jsonb_build_object('id',item_id,'is_current',false,
    'end_month','2024-12','description','Short')));
  ASSERT response->'data'->'volunteer_experiences'->0->>'version'='2';
  ASSERT response->'data'->'volunteer_experiences'->0->>'description'='Short';
  ASSERT pg_temp.volunteer_state(p.id)=state_before;
  -- Another distinct ID with identical identity/content cannot multiply credit.
  response:=public.profile_mutate(gen_random_uuid(),p.id,(response->>'authoritative_version')::bigint,
   jsonb_build_object('type','upsert_item','section','volunteer',
    'value',original||jsonb_build_object('id',gen_random_uuid(),'description',repeat('Detailed content. ',20))));
  ASSERT jsonb_array_length(response->'data'->'volunteer_experiences')=2;
  ASSERT pg_temp.volunteer_state(p.id)=state_before;
  FOR item_id IN SELECT id FROM public.profile_volunteer_experiences WHERE profile_id=p.id LOOP
   SELECT profile_version INTO version_before FROM public.career_profiles WHERE id=p.id;
   PERFORM public.profile_mutate(gen_random_uuid(),p.id,version_before,
    jsonb_build_object('type','delete_item','section','volunteer','value',jsonb_build_object('id',item_id)));
  END LOOP;
  ASSERT pg_temp.volunteer_state(p.id)=state_before;
  ASSERT public.first_career_profile()->'volunteer_experiences'='[]'::jsonb;
 END LOOP;
 -- Above threshold but with no allowance row: Volunteer must not manufacture it.
 DELETE FROM public.ai_allowance_accounts WHERE user_id=legacy.owner_id;
 SELECT * INTO p FROM public.career_profiles WHERE id=legacy.profile_id;
 state_before:=pg_temp.volunteer_state(p.id);
 response:=public.profile_mutate(gen_random_uuid(),p.id,p.profile_version,
  jsonb_build_object('type','upsert_item','section','volunteer','value',original));
 ASSERT pg_temp.volunteer_state(p.id)=state_before;
 ASSERT NOT EXISTS(SELECT 1 FROM public.ai_allowance_accounts WHERE user_id=legacy.owner_id);
 SELECT profile_version INTO version_before FROM public.career_profiles WHERE id=p.id;
 FOR invalid IN SELECT value FROM jsonb_array_elements(jsonb_build_array(
  original||'{"organization":null}',original||'{"role":""}',original||'{"start_month":"0000-01"}',
  original||'{"start_month":"2024-13"}',original||'{"is_current":"true"}',
  original||'{"is_current":false}',original||'{"is_current":false,"end_month":"2023-12"}',
  original||'{"is_current":false,"end_month":"0000-01"}',
  original||'{"id":"invalid"}',original||'{"paid":true}',
  original||jsonb_build_object('organization',repeat('x',201)),
  original||jsonb_build_object('description',repeat('x',1501))
 )) LOOP
  PERFORM pg_temp.expect_volunteer_error(p.id,version_before,
   jsonb_build_object('type','upsert_item','section','volunteer','value',invalid),'VALIDATION_FAILED');
 END LOOP;
 ASSERT pg_temp.volunteer_state(p.id)=state_before;
 PERFORM pg_temp.expect_volunteer_error(p.id,version_before,
  jsonb_build_object('type','delete_item','section','volunteer',
  'value',jsonb_build_object('id',gen_random_uuid())),'ITEM_NOT_FOUND');
 INSERT INTO phase2_security_fixture VALUES(legacy.owner_id,other,p.id,(original->>'id')::uuid);
 PERFORM set_config('request.jwt.claim.sub',other::text,true);
 PERFORM pg_temp.expect_volunteer_error(p.id,version_before,
  jsonb_build_object('type','upsert_item','section','volunteer','value',original),'FORBIDDEN');
 -- A foreign item ID cannot move to this owner's otherwise authorized profile.
 SELECT profile_version INTO version_before FROM public.career_profiles WHERE id=other_profile;
 PERFORM pg_temp.expect_volunteer_error(other_profile,version_before,
  jsonb_build_object('type','upsert_item','section','volunteer','value',original),'FORBIDDEN');
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM pg_temp.expect_volunteer_error(p.id,version_before,
  jsonb_build_object('type','upsert_item','section','volunteer','value',original),'AUTH_REQUIRED');
 PERFORM set_config('request.jwt.claim.sub',legacy.owner_id::text,true);
 SELECT profile_version INTO version_before FROM public.career_profiles WHERE id=p.id;
 UPDATE public.users SET status='DELETING' WHERE id=legacy.owner_id;
 PERFORM pg_temp.expect_volunteer_error(p.id,version_before,
  jsonb_build_object('type','upsert_item','section','volunteer','value',original),'ACCOUNT_DELETING');
 UPDATE public.users SET status='DELETED' WHERE id=legacy.owner_id;
 PERFORM pg_temp.expect_volunteer_error(p.id,version_before,
  jsonb_build_object('type','upsert_item','section','volunteer','value',original),'ACCOUNT_DELETING');
 UPDATE public.users SET status='ACTIVE' WHERE id=legacy.owner_id;
 -- Ordinary legacy mutations retain their established scoring and Volunteer.
 response:=public.profile_mutate(gen_random_uuid(),p.id,version_before,
  jsonb_build_object('type','upsert_item','section','experience','value',jsonb_build_object(
   'id',gen_random_uuid(),'job_title','Paid role','company','Company','start_month','2023-01',
   'is_current',true,'description','Meaningful paid role description.')));
 ASSERT (response->'data'->>'completeness_percent')::numeric=40; -- summary 10 + first evidence 30
 ASSERT jsonb_array_length(response->'data'->'volunteer_experiences')=1;
 response:=public.profile_mutate(gen_random_uuid(),p.id,(response->>'authoritative_version')::bigint,
  jsonb_build_object('type','upsert_item','section','experience','value',jsonb_build_object(
   'id',gen_random_uuid(),'job_title','Second paid role','company','Other Company','start_month','2023-01',
   'is_current',true,'description','Meaningful second paid role description.')));
 ASSERT (response->'data'->>'completeness_percent')::numeric=55; -- summary 10 + 30 + 15
END $test$;

-- Exercise actual role permissions and the owner SELECT policy.
GRANT SELECT ON phase2_security_fixture TO authenticated;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',(SELECT owner_id::text FROM phase2_security_fixture),false);
DO $test$ BEGIN
 ASSERT (SELECT count(*) FROM public.profile_volunteer_experiences)=1;
 ASSERT jsonb_array_length(public.first_career_profile()->'volunteer_experiences')=1;
 BEGIN
  DELETE FROM public.profile_volunteer_experiences;
  RAISE EXCEPTION 'assertion: client direct mutation allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.jobix_profile_text_snapshot((SELECT profile_id FROM phase2_security_fixture));
  RAISE EXCEPTION 'assertion: private snapshot accessible';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('request.jwt.claim.sub',(SELECT other_id::text FROM phase2_security_fixture),false);
DO $test$ BEGIN
 ASSERT (SELECT count(*) FROM public.profile_volunteer_experiences)=0;
END $test$;
RESET ROLE;
SET ROLE anon;
DO $test$ BEGIN
 BEGIN
  PERFORM 1 FROM public.profile_volunteer_experiences;
  RAISE EXCEPTION 'assertion: anonymous read allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
