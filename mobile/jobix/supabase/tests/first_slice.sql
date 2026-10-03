-- Disposable/rollback-only. Does not create real sign-in identities.
BEGIN;
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-4000-8000-000000000011'),
 ('00000000-0000-4000-8000-000000000012');
DO $$ BEGIN
 IF (SELECT count(*) FROM public.career_profiles WHERE user_id IN
   ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012')) <> 2
   OR (SELECT count(*) FROM public.profile_slots WHERE unlocked AND slot_number=1 AND user_id IN
   ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012')) <> 2
   OR EXISTS (SELECT 1 FROM public.profile_personal_data d JOIN public.career_profiles p ON p.id=d.profile_id
     WHERE p.user_id IN ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012')
        AND (d.full_name IS NOT NULL OR d.email IS NOT NULL OR d.phone IS NOT NULL
          OR d.country IS NOT NULL OR d.city IS NOT NULL OR d.linkedin_url IS NOT NULL
          OR d.github_url IS NOT NULL OR d.portfolio_url IS NOT NULL))
   OR EXISTS (SELECT 1 FROM public.career_profiles WHERE user_id IN
     ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012')
     AND (cv_language IS NOT NULL OR name IS NOT NULL))
 THEN RAISE EXCEPTION 'Profile bootstrap must be exactly one empty Profile per account'; END IF;
 BEGIN
   INSERT INTO public.career_profiles(user_id,slot_number) VALUES
     ('00000000-0000-4000-8000-000000000011',1);
   RAISE EXCEPTION 'duplicate profile accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM count(*) FROM public.career_profiles; RAISE EXCEPTION 'anonymous read accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.save_onboarding(gen_random_uuid(),0,'{}'); RAISE EXCEPTION 'anonymous RPC accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.claim_registration_entry(); RAISE EXCEPTION 'anonymous entry claim accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
DO $$
DECLARE p uuid; other uuid; result jsonb; retry jsonb; key uuid := gen_random_uuid();
BEGIN
 IF public.claim_registration_entry() IS DISTINCT FROM true
    OR public.claim_registration_entry() IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'registration entry must be claimed once per account'; END IF;
 IF (SELECT count(*) FROM public.career_profiles) <> 1
   OR (SELECT count(*) FROM public.profile_personal_data) <> 1
   OR (SELECT count(*) FROM public.profile_slots) <> 1
 THEN RAISE EXCEPTION 'cross-account rows visible'; END IF;
 SELECT id INTO p FROM public.career_profiles;
 result := public.save_personal_information(key,p,1,'{"full_name":"Test Name"}','ar');
 retry := public.save_personal_information(key,p,1,'{"full_name":"Test Name"}','ar');
 IF result <> retry OR (SELECT profile_version FROM public.career_profiles) <> 2
   OR (SELECT email FROM public.profile_personal_data) IS NOT NULL
 THEN RAISE EXCEPTION 'partial save/retry failed'; END IF;
 BEGIN
   PERFORM public.save_personal_information(key,p,1,'{"full_name":"Different"}','ar');
   RAISE EXCEPTION 'idempotency-key payload mismatch accepted';
 EXCEPTION WHEN raise_exception THEN
   IF SQLERRM <> 'IDEMPOTENCY_KEY_REUSE' THEN RAISE; END IF;
 END;
 BEGIN
   PERFORM public.save_personal_information(gen_random_uuid(),p,1,'{}',NULL);
   RAISE EXCEPTION 'stale version accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'VERSION_CONFLICT' THEN RAISE; END IF; END;
 BEGIN
   UPDATE public.profile_personal_data SET full_name='write around RPC';
   RAISE EXCEPTION 'direct write accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   PERFORM public.save_personal_information(gen_random_uuid(),p,2,'{"email":"bad email"}','en');
   RAISE EXCEPTION 'invalid email accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'VALIDATION_FAILED' THEN RAISE; END IF; END;
 BEGIN
   PERFORM public.save_personal_information(gen_random_uuid(),gen_random_uuid(),1,'{}','en');
   RAISE EXCEPTION 'unowned profile accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'FORBIDDEN' THEN RAISE; END IF; END;
 key := gen_random_uuid();
 result := public.save_onboarding(key,0,
  '{"career_stage":"student","career_goal":"unsure","desired_work_location":"remote","help_areas":["cv","skills","online"]}');
 retry := public.save_onboarding(key,0,
  '{"career_stage":"student","career_goal":"unsure","desired_work_location":"remote","help_areas":["cv","skills","online"]}');
 IF result <> retry THEN RAISE EXCEPTION 'context retry failed'; END IF;
 BEGIN
  PERFORM public.save_onboarding(gen_random_uuid(),1,
   '{"career_stage":"student","career_goal":"unsure","desired_work_location":"remote","help_areas":["cv","skills","online","paths"]}');
  RAISE EXCEPTION 'Q4 greater than three accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'VALIDATION_FAILED' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.save_onboarding(gen_random_uuid(),1,
   '{"career_stage":"student","career_goal":"unsure","desired_work_location":"remote","help_areas":["cv","cv"]}');
  RAISE EXCEPTION 'duplicate choices accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'VALIDATION_FAILED' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.career_profiles) <> 1
   OR (SELECT full_name FROM public.profile_personal_data) IS NOT NULL
   OR EXISTS (SELECT 1 FROM public.onboarding_context)
 THEN RAISE EXCEPTION 'second account isolation failed'; END IF;
 IF public.claim_registration_entry() IS DISTINCT FROM true
 THEN RAISE EXCEPTION 'first account consumed second account entry'; END IF;
END $$;
RESET ROLE;
UPDATE public.users SET status='DELETING' WHERE id='00000000-0000-4000-8000-000000000011';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.career_profiles) OR EXISTS(SELECT 1 FROM public.profile_personal_data)
   OR EXISTS(SELECT 1 FROM public.onboarding_context) THEN RAISE EXCEPTION 'deleting data visible'; END IF;
 BEGIN
  PERFORM public.claim_registration_entry(); RAISE EXCEPTION 'deleting entry accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'AUTH_REQUIRED' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.save_onboarding(gen_random_uuid(),1,'{}');
  RAISE EXCEPTION 'deleting mutation accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ACCOUNT_DELETING' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
ROLLBACK;