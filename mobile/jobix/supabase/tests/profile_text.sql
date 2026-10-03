BEGIN;
INSERT INTO auth.users(id) VALUES('62000000-0000-0000-0000-000000000001'),('62000000-0000-0000-0000-000000000002');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','62000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE p uuid; result jsonb; replay jsonb; v bigint; BEGIN
 SELECT id INTO p FROM public.career_profiles WHERE slot_number=1;
 PERFORM set_config('jobix.test_alice_profile',p::text,true);
 result:=public.save_personal_information('62000000-0000-0000-0000-000000000003',p,1,
   '{"full_name":"Real Contact"}',NULL);
 IF (SELECT completeness_percent FROM public.career_profiles WHERE id=p)<>5 THEN
   RAISE EXCEPTION 'Contact must contribute independently';
 END IF;
 result:=public.profile_mutate('62000000-0000-0000-0000-000000000004',p,2,
   '{"type":"upsert_item","section":"summary","value":{"text":"short draft"}}');
 IF result->'data'->>'summary_state'<>'NEEDS_ATTENTION'
   OR result->'data'->>'completeness_percent'<>'5.00' THEN RAISE EXCEPTION 'Incomplete summary lost or awarded points'; END IF;
 result:=public.profile_mutate('62000000-0000-0000-0000-000000000005',p,3,
   jsonb_build_object('type','upsert_item','section','summary','value',jsonb_build_object('text',
     'أعمل في تطوير البرمجيات وتحليل البيانات وأرغب في تطوير خبرتي المهنية.')));
 IF result->'data'->>'summary_state'<>'COMPLETE'
   OR (result->'data'->>'completeness_percent')::numeric<>15 THEN RAISE EXCEPTION 'Arabic meaningful summary rejected'; END IF;
 replay:=public.profile_mutate('62000000-0000-0000-0000-000000000005',p,3,
   jsonb_build_object('type','upsert_item','section','summary','value',jsonb_build_object('text',
     'أعمل في تطوير البرمجيات وتحليل البيانات وأرغب في تطوير خبرتي المهنية.')));
 IF result<>replay OR (SELECT profile_version FROM public.career_profiles WHERE id=p)<>4 THEN
   RAISE EXCEPTION 'Replay increments version or changes acknowledgement';
 END IF;
 BEGIN
   PERFORM public.profile_mutate('62000000-0000-0000-0000-000000000006',p,1,
     '{"type":"upsert_item","section":"target_role","value":{"text":"Engineer"}}');
   RAISE EXCEPTION 'Conflict accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VERSION_CONFLICT' THEN RAISE; END IF; END;
 BEGIN
   PERFORM public.profile_mutate('62000000-0000-0000-0000-000000000007',p,4,
     jsonb_build_object('type','upsert_item','section','summary','value',jsonb_build_object('text',repeat('x',1001))));
   RAISE EXCEPTION 'Hard limit bypassed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
 BEGIN
   PERFORM public.profile_mutate('62000000-0000-0000-0000-000000000005',p,4,
     '{"type":"upsert_item","section":"summary","value":{"text":"changed"}}');
   RAISE EXCEPTION 'Key reuse accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'IDEMPOTENCY_KEY_REUSE' THEN RAISE; END IF; END;
 result:=public.profile_mutate('62000000-0000-0000-0000-000000000008',p,4,
     '{"type":"upsert_item","section":"target_role","value":{"text":"Software Engineer"}}');
 IF (result->'data'->>'completeness_percent')::numeric<>20 THEN RAISE EXCEPTION 'Target role score missing'; END IF;
 result:=public.profile_mutate('62000000-0000-0000-0000-000000000009',p,5,
     jsonb_build_object('type','upsert_item','section','summary','value',jsonb_build_object('text',repeat('x',60))));
 IF result->'data'->>'summary_state'<>'NEEDS_ATTENTION' THEN RAISE EXCEPTION 'Repeated filler qualified'; END IF;
 IF (SELECT finalized_balance FROM public.credit_accounts)<>5 THEN RAISE EXCEPTION 'Text edits charged Credits'; END IF;
 IF has_table_privilege('authenticated','public.profile_summaries','INSERT,UPDATE,DELETE') THEN
   RAISE EXCEPTION 'Client can bypass mutation'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','62000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.profile_summaries) THEN RAISE EXCEPTION 'Cross-owner summary leak'; END IF;
 BEGIN
   PERFORM public.profile_mutate('62000000-0000-0000-0000-000000000010',
     current_setting('jobix.test_alice_profile')::uuid,6,
     '{"type":"upsert_item","section":"summary","value":{"text":"foreign write"}}');
   RAISE EXCEPTION 'Cross-owner mutation accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'FORBIDDEN' THEN RAISE; END IF; END;
 IF public.first_career_profile()->>'summary'<>''
   THEN RAISE EXCEPTION 'First profile read leaked another owner'; END IF;
END $$;
RESET ROLE;
ROLLBACK;