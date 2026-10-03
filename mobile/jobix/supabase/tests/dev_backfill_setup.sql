INSERT INTO public.app_policies(policy_key,minimum_supported_version,recommended_version,policy_version)
  VALUES('mobile','1.0.0','1.0.0','1') ON CONFLICT(policy_key) DO NOTHING;
INSERT INTO auth.users(id) VALUES
  ('61000000-0000-0000-0000-000000000001'),
  ('61000000-0000-0000-0000-000000000002');
-- Emulate a legacy Auth-only actor in a disposable database, never live.
DELETE FROM public.users WHERE id='61000000-0000-0000-0000-000000000001';
UPDATE public.profile_personal_data SET full_name='Preserved fixture'
  WHERE profile_id IN (SELECT id FROM public.career_profiles
    WHERE user_id='61000000-0000-0000-0000-000000000002');
SELECT set_config('jobix.authorized_dev_project','lmouxhbjhtqdtiqijcee',false);
SELECT set_config('jobix.dev_backfill_actor_ids',
  '61000000-0000-0000-0000-000000000001,61000000-0000-0000-0000-000000000002',false);