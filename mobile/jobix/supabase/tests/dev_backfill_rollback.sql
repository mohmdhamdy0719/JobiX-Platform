DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.users'::regclass
    AND tgname='jobix_signup_credit_grant' AND tgenabled='O') THEN
    RAISE EXCEPTION 'Failed maintenance left signup grant disabled';
  END IF;
END $$;
INSERT INTO auth.users(id) VALUES('61000000-0000-0000-0000-000000000004');
DO $$ BEGIN
  IF (SELECT finalized_balance FROM public.credit_accounts
    WHERE user_id='61000000-0000-0000-0000-000000000004')<>5 THEN
    RAISE EXCEPTION 'Signup grant did not survive maintenance rollback';
  END IF;
END $$;