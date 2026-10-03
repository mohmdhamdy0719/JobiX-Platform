-- Administrator-only maintenance, never a mobile RPC or a general migration.
-- The protected runner sets the exact isolated-dev project and two actor UUIDs.
BEGIN;
DROP TABLE IF EXISTS pg_temp.jobix_backfill_result;
CREATE TEMP TABLE jobix_backfill_result(created integer, preserved integer);
LOCK TABLE public.users IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
  IF current_setting('jobix.authorized_dev_project',true) IS DISTINCT FROM 'lmouxhbjhtqdtiqijcee'
    OR cardinality(string_to_array(current_setting('jobix.dev_backfill_actor_ids',true),',')) IS DISTINCT FROM 2
    THEN RAISE EXCEPTION 'AUTHORIZED_DEV_ACTORS_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.users'::regclass AND tgname='jobix_signup_credit_grant'
      AND tgenabled='O' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'EXPECTED_SIGNUP_TRIGGER_REQUIRED';
  END IF;
END $$;
-- DDL is transactional, and the table lock blocks concurrent user inserts.
-- Other sessions never see a committed disabled grant trigger. On any failure,
-- rollback restores it. This avoids creating/deleting a retroactive ledger grant.
ALTER TABLE public.users DISABLE TRIGGER jobix_signup_credit_grant;
DO $$
DECLARE
  actor uuid; profile uuid; created integer := 0; preserved integer := 0;
  actors uuid[] := string_to_array(current_setting('jobix.dev_backfill_actor_ids'),',')::uuid[];
BEGIN
  IF actors[1]=actors[2] THEN RAISE EXCEPTION 'DISTINCT_DEV_ACTORS_REQUIRED'; END IF;
  FOREACH actor IN ARRAY actors LOOP
    PERFORM 1 FROM auth.users WHERE id=actor FOR KEY SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'EXISTING_AUTH_ACTOR_REQUIRED'; END IF;
    IF EXISTS(SELECT 1 FROM public.users WHERE id=actor) THEN
      -- Includes inactive accounts: never revive, repair or grant to them here.
      preserved := preserved+1;
      CONTINUE;
    END IF;
    INSERT INTO public.users(id,first_profile_entry_pending) VALUES(actor,true);
    INSERT INTO public.credit_accounts(user_id,finalized_balance,reserved_balance)
      VALUES(actor,0,0);
    INSERT INTO public.profile_slots(user_id,slot_number,unlocked,unlocked_at)
      VALUES(actor,1,true,now());
    INSERT INTO public.career_profiles(user_id,slot_number)
      VALUES(actor,1) RETURNING id INTO profile;
    INSERT INTO public.profile_personal_data(profile_id) VALUES(profile);
    IF EXISTS(SELECT 1 FROM public.credit_transactions WHERE user_id=actor)
      OR (SELECT finalized_balance<>0 OR reserved_balance<>0
          FROM public.credit_accounts WHERE user_id=actor) THEN
      RAISE EXCEPTION 'ZERO_CREDIT_BACKFILL_INVARIANT_FAILED';
    END IF;
    created := created+1;
  END LOOP;
  INSERT INTO jobix_backfill_result VALUES(created,preserved);
END $$;
ALTER TABLE public.users ENABLE TRIGGER jobix_signup_credit_grant;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.users'::regclass
    AND tgname='jobix_signup_credit_grant' AND tgenabled='O') THEN
    RAISE EXCEPTION 'SIGNUP_TRIGGER_NOT_RESTORED';
  END IF;
END $$;
COMMIT;
SELECT 'BACKFILL_RESULT:'||created||':'||preserved FROM jobix_backfill_result;