-- Disposable local PostgreSQL only. No persistent fixtures.
BEGIN;
DO $test$
DECLARE actor uuid:=gen_random_uuid(); other_actor uuid:=gen_random_uuid();
 profile uuid; v bigint; cmd uuid:=gen_random_uuid(); result jsonb; replay jsonb;
 ordering jsonb:='["language","skill","summary","target_role","experience","volunteer","education","certification","achievement","project"]';
 baseline_balance jsonb; baseline_content jsonb; before_gate jsonb; before_policy jsonb;
 old_version bigint;
BEGIN
 SELECT to_jsonb(s) INTO before_gate FROM public.export_settings s;
 SELECT to_jsonb(s) INTO before_policy FROM public.export_cost_budget_policy s;
 ASSERT NOT has_function_privilege('anon',
   'public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)','EXECUTE');
 ASSERT NOT has_function_privilege('service_role',
   'public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)','EXECUTE');
 ASSERT has_function_privilege('authenticated',
   'public.save_resume_layout(uuid,uuid,bigint,bigint,text,jsonb,jsonb)','EXECUTE');
 INSERT INTO auth.users(id,email) VALUES(actor,'layout-fixture@example.invalid'),
 (other_actor,'layout-other@example.invalid');
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 SELECT id,profile_version INTO profile,v FROM public.career_profiles WHERE user_id=actor;
 baseline_content:=public.jobix_profile_text_snapshot(profile)-'profile_version';
 baseline_balance:=public.credit_balance();
 SET LOCAL ROLE authenticated;
 result:=public.save_resume_layout(cmd,profile,v,0,'ar','["education","summary"]',ordering);
 ASSERT result->'section_order'=ordering;
 ASSERT result->'section_visibility'='{"education":false,"summary":false}'::jsonb;
 ASSERT result->>'language'='ar';
 ASSERT result->>'render_config_version'='export-layout-v1';
 ASSERT result->>'template_version'='3';
 replay:=public.save_resume_layout(cmd,profile,v,0,'ar','["education","summary"]',ordering);
 ASSERT replay=result, 'same-key replay must preserve ACK';
 BEGIN
  PERFORM public.save_resume_layout(cmd,profile,v,0,'en','[]',ordering);
  RAISE EXCEPTION 'key reuse accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='IDEMPOTENCY_KEY_REUSE'; END;
 BEGIN
  PERFORM public.save_resume_layout(gen_random_uuid(),profile,v,0,'ar','[]',ordering);
  RAISE EXCEPTION 'stale accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='VERSION_CONFLICT'; END;
 BEGIN
  PERFORM public.save_resume_layout(gen_random_uuid(),profile,v+1,1,'ar','[]','["summary","summary"]');
  RAISE EXCEPTION 'invalid order accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='VALIDATION_FAILED'; END;
 PERFORM set_config('request.jwt.claim.sub',other_actor::text,true);
 BEGIN
  PERFORM public.save_resume_layout(gen_random_uuid(),profile,v+1,1,'ar','[]',ordering);
  RAISE EXCEPTION 'foreign profile accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='FORBIDDEN'; END;
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM public.save_resume_layout(gen_random_uuid(),profile,v+1,1,'ar','[]',ordering);
  RAISE EXCEPTION 'anonymous accepted';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='AUTH_REQUIRED'; END;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 ASSERT (SELECT profile_version FROM public.career_profiles WHERE id=profile)=v+1;
 ASSERT public.jobix_profile_text_snapshot(profile)-'profile_version'=baseline_content;
 ASSERT public.credit_balance()=baseline_balance;
 ASSERT NOT EXISTS(SELECT FROM public.export_jobs WHERE user_id=actor);
 ASSERT (SELECT to_jsonb(s) FROM public.export_settings s)=before_gate;
 ASSERT (SELECT to_jsonb(s) FROM public.export_cost_budget_policy s)=before_policy;
 -- Legacy visibility RPC must preserve the explicit ordering and renderer mode.
 result:=public.save_resume_presentation(gen_random_uuid(),profile,v+1,1,'en','[]');
 ASSERT result->'section_order'=ordering;
 ASSERT result->>'render_config_version'='export-layout-v1';
 ASSERT (SELECT profile_version FROM public.career_profiles WHERE id=profile)=v+2;
 old_version:=(result->>'version')::bigint;
 -- Reset defaults is an explicit layout save, not deletion of profile content.
 result:=public.save_resume_layout(gen_random_uuid(),profile,v+2,old_version,'en','[]',
 '["summary","target_role","experience","volunteer","education","certification","achievement","project","skill","language"]');
 ASSERT result->'section_visibility'='{}'::jsonb;
 ASSERT (result->>'version')::bigint=old_version+1;
 ASSERT public.jobix_profile_text_snapshot(profile)-'profile_version'=baseline_content;
 ASSERT public.credit_balance()=baseline_balance;
END $test$;
ROLLBACK;
