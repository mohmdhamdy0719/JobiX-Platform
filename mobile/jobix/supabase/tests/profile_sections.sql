BEGIN;
INSERT INTO auth.users(id) VALUES('63000000-0000-0000-0000-000000000001'),('63000000-0000-0000-0000-000000000002');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','63000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE p uuid; v bigint; r jsonb; replay jsonb;
BEGIN
 SELECT id,profile_version INTO p,v FROM public.career_profiles
  WHERE user_id='63000000-0000-0000-0000-000000000001' AND slot_number=1;
 PERFORM set_config('jobix.test_section_profile',p::text,true);
 -- Personal Information through the unified command.
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000101',p,v,
  '{"type":"upsert_item","section":"personal","value":{"personal":{"full_name":"Lina Ahmed","email":"lina@example.org","phone":"+20 100 123 4567"},"resume_language":"en"}}');
 IF r->>'state'<>'SUCCEEDED' OR (r->'data'->>'completeness_percent')::numeric<>15 THEN
  RAISE EXCEPTION 'Personal via profile_mutate failed: %',r; END IF;
 replay:=public.profile_mutate('63000000-0000-0000-0000-000000000101',p,v,
  '{"type":"upsert_item","section":"personal","value":{"personal":{"full_name":"Lina Ahmed","email":"lina@example.org","phone":"+20 100 123 4567"},"resume_language":"en"}}');
 IF replay->'data'<>r->'data' THEN RAISE EXCEPTION 'Personal replay differs'; END IF;
 v:=(r->>'authoritative_version')::bigint;
 -- Incomplete experience saves, earns nothing.
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000102',p,v,
  '{"type":"upsert_item","section":"experience","value":{"id":"63000000-0000-0000-0000-00000000e001","job_title":"Data Analyst"}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>15 OR (r->'data'->'experiences'->0->>'complete')::boolean THEN
  RAISE EXCEPTION 'Incomplete experience awarded'; END IF;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000103',p,v,
  '{"type":"upsert_item","section":"experience","value":{"id":"63000000-0000-0000-0000-00000000e001","job_title":"Data Analyst","company":"Nile Analytics","start_month":"2021-03","is_current":true,"description":"Built weekly sales dashboards for regional teams."}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>45 OR r->'data'->'experiences'->0->>'start_month'<>'2021-03' THEN
  RAISE EXCEPTION 'First evidence must add 30: %',r->'data'; END IF;
 -- Exact duplicate evidence counts once.
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000104',p,v,
  '{"type":"upsert_item","section":"experience","value":{"id":"63000000-0000-0000-0000-00000000e002","job_title":"data  analyst","company":"Nile Analytics","start_month":"2021-03","is_current":true,"description":"Built weekly sales dashboards for regional teams."}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>45 THEN RAISE EXCEPTION 'Duplicate evidence double counted'; END IF;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000105',p,v,
  '{"type":"upsert_item","section":"education","value":{"id":"63000000-0000-0000-0000-00000000d001","degree":"BSc","institution":"Cairo University","field_of_study":"Statistics","start_month":"2016-09","end_month":"2020-06"}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>60 THEN RAISE EXCEPTION 'Second evidence must add 15'; END IF;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000106',p,v,
  '{"type":"upsert_item","section":"project","value":{"id":"63000000-0000-0000-0000-00000000f001","name":"Churn model","role":"Lead","project_month":"2022-01","description":"Predicted churn for a telecom operator.","url":"github.com/lina/churn","technologies":["Python","SQL"]}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>60 OR r->'data'->'projects'->0->>'url'<>'https://github.com/lina/churn' THEN
  RAISE EXCEPTION 'Third evidence must add nothing / URL normalized'; END IF;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000107',p,v,
  '{"type":"upsert_item","section":"skill","value":{"id":"63000000-0000-0000-0000-00000000a001","name":"SQL"}}');
 v:=v+1;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000108',p,v,
  '{"type":"upsert_item","section":"language","value":{"id":"63000000-0000-0000-0000-00000000b001","name":"Arabic","proficiency":"NATIVE"}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>85 THEN RAISE EXCEPTION 'Skills/languages weights wrong'; END IF;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000109',p,v,
  '{"type":"upsert_item","section":"certification","value":{"id":"63000000-0000-0000-0000-00000000c001","name":"PMP","issuer":"PMI","issue_month":"2023-05"}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>85 OR NOT (r->'data'->'certifications'->0->>'complete')::boolean THEN
  RAISE EXCEPTION 'Certification must not add evidence'; END IF;
 -- Duplicate skill (normalized) rejected.
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000110',p,v,
   '{"type":"upsert_item","section":"skill","value":{"id":"63000000-0000-0000-0000-00000000a002","name":"  sql "}}');
  RAISE EXCEPTION 'Duplicate accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'DUPLICATE_ITEM' THEN RAISE; END IF; END;
 -- Invalid range, unsafe URL, unknown key, over-limit.
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000111',p,v,
   '{"type":"upsert_item","section":"education","value":{"id":"63000000-0000-0000-0000-00000000d002","start_month":"2020-01","end_month":"2019-01"}}');
  RAISE EXCEPTION 'Range accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000112',p,v,
   '{"type":"upsert_item","section":"achievement","value":{"id":"63000000-0000-0000-0000-00000000g001","url":"javascript:alert(1)"}}');
  RAISE EXCEPTION 'Unsafe URL accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT IN ('VALIDATION_FAILED') THEN RAISE; END IF;
  WHEN invalid_text_representation THEN NULL; END;
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000113',p,v,
   '{"type":"upsert_item","section":"skill","value":{"id":"63000000-0000-0000-0000-00000000a003","name":"Go","extra":1}}');
  RAISE EXCEPTION 'Unknown key accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000114',p,v,
   jsonb_build_object('type','upsert_item','section','experience','value',
    jsonb_build_object('id','63000000-0000-0000-0000-00000000e003','description',repeat('x',1501))));
  RAISE EXCEPTION 'Over-limit accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000115',p,v-1,
   '{"type":"delete_item","section":"skill","value":{"id":"63000000-0000-0000-0000-00000000a001"}}');
  RAISE EXCEPTION 'Stale delete accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VERSION_CONFLICT' THEN RAISE; END IF; END;
 r:=public.profile_mutate('63000000-0000-0000-0000-000000000116',p,v,
  '{"type":"delete_item","section":"skill","value":{"id":"63000000-0000-0000-0000-00000000a001"}}');
 v:=v+1;
 IF (r->'data'->>'completeness_percent')::numeric<>70 OR jsonb_array_length(r->'data'->'skills')<>0 THEN
  RAISE EXCEPTION 'Delete did not recompute'; END IF;
 IF (SELECT completeness_algorithm_version FROM public.career_profiles WHERE id=p)<>'core-profile-v2' THEN
  RAISE EXCEPTION 'Algorithm version not recorded'; END IF;
 -- Direct writes are impossible for clients.
 BEGIN
  INSERT INTO public.profile_skills(id,profile_id,name) VALUES(gen_random_uuid(),p,'Hack');
  RAISE EXCEPTION 'Direct insert allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- Another user cannot read or mutate these rows, nor hijack ids.
SELECT set_config('request.jwt.claim.sub','63000000-0000-0000-0000-000000000002',true);
DO $$ DECLARE mine uuid; v bigint; BEGIN
 IF EXISTS(SELECT 1 FROM public.profile_experiences) OR EXISTS(SELECT 1 FROM public.profile_projects) THEN
  RAISE EXCEPTION 'Cross-user section read'; END IF;
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000201',
   current_setting('jobix.test_section_profile')::uuid,1,
   '{"type":"delete_item","section":"education","value":{"id":"63000000-0000-0000-0000-00000000d001"}}');
  RAISE EXCEPTION 'Cross-user mutate allowed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'FORBIDDEN' THEN RAISE; END IF; END;
 SELECT id,profile_version INTO mine,v FROM public.career_profiles
  WHERE user_id='63000000-0000-0000-0000-000000000002' AND slot_number=1;
 BEGIN
  PERFORM public.profile_mutate('63000000-0000-0000-0000-000000000202',mine,v,
   '{"type":"upsert_item","section":"experience","value":{"id":"63000000-0000-0000-0000-00000000e001","job_title":"Stolen"}}');
  RAISE EXCEPTION 'Foreign id overwritten';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'FORBIDDEN' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
ROLLBACK;
