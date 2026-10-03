DO $$ BEGIN
  IF (SELECT finalized_balance FROM public.credit_accounts
    WHERE user_id='61000000-0000-0000-0000-000000000001') IS DISTINCT FROM 0
    OR EXISTS(SELECT 1 FROM public.credit_transactions
      WHERE user_id='61000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Legacy actor received a retroactive credit grant';
  END IF;
  IF (SELECT count(*) FROM public.career_profiles
    WHERE user_id='61000000-0000-0000-0000-000000000001')<>1
    OR NOT (SELECT first_profile_entry_pending FROM public.users
      WHERE id='61000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Missing actor profile/entry initialization failed';
  END IF;
  IF (SELECT finalized_balance FROM public.credit_accounts
    WHERE user_id='61000000-0000-0000-0000-000000000002')<>5
    OR (SELECT count(*) FROM public.credit_transactions
      WHERE user_id='61000000-0000-0000-0000-000000000002')<>1
    OR NOT EXISTS(SELECT 1 FROM public.profile_personal_data d
      JOIN public.career_profiles p ON p.id=d.profile_id
      WHERE p.user_id='61000000-0000-0000-0000-000000000002'
        AND d.full_name='Preserved fixture') THEN
    RAISE EXCEPTION 'Existing actor data changed';
  END IF;
END $$;
-- Genuine subsequent signup must still get +5, not the maintenance exemption.
INSERT INTO auth.users(id) VALUES ('61000000-0000-0000-0000-000000000003');
DO $$ BEGIN
  IF (SELECT finalized_balance FROM public.credit_accounts
    WHERE user_id='61000000-0000-0000-0000-000000000003')<>5 OR
    (SELECT count(*) FROM public.credit_transactions
      WHERE user_id='61000000-0000-0000-0000-000000000003'
        AND reference_type='SIGNUP')<>1 THEN
    RAISE EXCEPTION 'New signup grant was weakened';
  END IF;
END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61000000-0000-0000-0000-000000000001',false);
DO $$ BEGIN
  IF public.credit_balance()->>'available'<>'0'
    OR jsonb_array_length(public.app_bootstrap('1.0.0','en')->'data'->'profiles')<>1 THEN
    RAISE EXCEPTION 'Provisioned actor cannot read its core bootstrap';
  END IF;
  IF (SELECT count(*) FROM public.credit_accounts)<>1 THEN
    RAISE EXCEPTION 'Backfill weakened wallet RLS';
  END IF;
END $$;
RESET ROLE;