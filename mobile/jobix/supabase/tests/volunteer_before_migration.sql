-- Populated database, historical acknowledgement and exact pre-migration state.
CREATE TEMP TABLE phase2_legacy_ack (
 owner_id uuid, profile_id uuid, command_key uuid, version bigint,
 mutation jsonb, response jsonb
);
DO $test$
DECLARE uid uuid:=gen_random_uuid(); p uuid; v bigint;
 command uuid:=gen_random_uuid(); mutation jsonb; response jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(uid,'volunteer-fixture-'||uid||'@example.invalid');
 PERFORM set_config('request.jwt.claim.sub',uid::text,true);
 SELECT id,profile_version INTO p,v FROM public.career_profiles WHERE user_id=uid AND slot_number=1;
 mutation:=jsonb_build_object('type','upsert_item','section','summary',
  'value',jsonb_build_object('text','Existing authored summary with sufficient detail for the approved qualification.'));
 response:=public.profile_mutate(command,p,v,mutation);
 ASSERT NOT (response->'data' ? 'volunteer_experiences');
 INSERT INTO phase2_legacy_ack VALUES(uid,p,command,v,mutation,response);
END $test$;
CREATE TEMP TABLE phase2_profiles_before AS
 SELECT id,to_jsonb(p) AS value FROM public.career_profiles p;
CREATE TEMP TABLE phase2_ai_before AS
 SELECT user_id,to_jsonb(a) AS value FROM public.ai_allowance_accounts a;
CREATE TEMP TABLE phase2_ack_before AS
 SELECT user_id,operation_type,idempotency_key,to_jsonb(i) AS value
 FROM public.idempotency_records i;
CREATE TEMP TABLE phase2_algorithm_before AS
 SELECT pg_get_functiondef('public.jobix_recompute_text_profile(uuid)'::regprocedure) AS value;
