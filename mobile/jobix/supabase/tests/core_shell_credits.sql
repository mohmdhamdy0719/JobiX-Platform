-- Disposable database only; all new fixtures and policy changes are rolled back.
BEGIN;
INSERT INTO public.app_policies(policy_key,minimum_supported_version,recommended_version,policy_version)
  VALUES ('mobile','1.0.0','1.0.0','1')
  ON CONFLICT (policy_key) DO NOTHING;
INSERT INTO auth.users(id) VALUES
  ('52000000-0000-0000-0000-000000000001'),
  ('52000000-0000-0000-0000-000000000002');
-- A replay of registration cannot grant Credits again.
INSERT INTO auth.users(id) VALUES ('52000000-0000-0000-0000-000000000001')
  ON CONFLICT (id) DO NOTHING;
DO $$ BEGIN
  IF (SELECT finalized_balance FROM public.credit_accounts
      WHERE user_id='51000000-0000-0000-0000-000000000001')<>0 OR
    EXISTS(SELECT 1 FROM public.credit_transactions
      WHERE user_id='51000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'Historical accounts received an unauthorized grant';
  END IF;
  IF (SELECT finalized_balance FROM public.credit_accounts
      WHERE user_id='52000000-0000-0000-0000-000000000001')<>5 OR
    (SELECT count(*) FROM public.credit_transactions
      WHERE user_id='52000000-0000-0000-0000-000000000001'
        AND reference_type='SIGNUP')<>1 THEN
    RAISE EXCEPTION 'Signup grant not exactly once';
  END IF;
  IF (SELECT count(*) FROM public.career_profiles
      WHERE user_id='52000000-0000-0000-0000-000000000001')<>1 THEN
    RAISE EXCEPTION 'Existing profile bootstrap changed';
  END IF;
END $$;

SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN PERFORM public.credit_balance();
    RAISE EXCEPTION 'Anonymous balance access allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.app_bootstrap('1.0.0','en');
    RAISE EXCEPTION 'Anonymous bootstrap access allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE v jsonb; BEGIN
  v:=public.credit_balance();
  IF v->>'finalized'<>'5' OR v->>'reserved'<>'0' OR v->>'available'<>'5' THEN
    RAISE EXCEPTION 'Authoritative balance is incorrect';
  END IF;
  IF (SELECT count(*) FROM public.credit_accounts)<>1 OR
    (SELECT count(*) FROM public.credit_transactions)<>1 THEN
    RAISE EXCEPTION 'Credit RLS ownership failed';
  END IF;
  v:=public.app_bootstrap('1.0.0','ar');
  IF (v->>'request_id') IS NULL OR
    v->'data'->'user'->>'id'<>auth.uid()::text OR
    v->'data'->'policy'->>'minimum_supported_version'<>'1.0.0' THEN
    RAISE EXCEPTION 'Bootstrap user/policy/transport metadata missing';
  END IF;
  IF v->>'state'<>'SUCCEEDED' OR jsonb_array_length(v->'data'->'profiles')<>1
    OR v->'data'->'balance'->>'available'<>'5' THEN
    RAISE EXCEPTION 'Bootstrap contract failed';
  END IF;
  IF (v->'data'->'profiles'->0) ? 'user_id' THEN
    RAISE EXCEPTION 'Bootstrap exposes unnecessary owner data';
  END IF;
  v:=public.credit_transactions_page();
  IF jsonb_array_length(v->'items')<>1 OR v->'next_cursor'<>'null'::jsonb THEN
    RAISE EXCEPTION 'History single-page result failed';
  END IF;
  BEGIN UPDATE public.credit_accounts SET finalized_balance=100;
    RAISE EXCEPTION 'Client balance write allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.credit_transactions(user_id,delta,reference_type)
    VALUES(auth.uid(),10,'ADJUSTMENT');
    RAISE EXCEPTION 'Client credit grant allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.credit_transactions_page(101);
    RAISE EXCEPTION 'Oversized history page allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
  BEGIN PERFORM public.credit_transactions_page(1,'invalid cursor');
    RAISE EXCEPTION 'Invalid cursor accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
  BEGIN PERFORM public.app_bootstrap('0.9.9','en');
    RAISE EXCEPTION 'Outdated client accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'APP_UPDATE_REQUIRED' THEN RAISE; END IF; END;
  BEGIN PERFORM public.app_bootstrap('1.0.0','fr');
    RAISE EXCEPTION 'Unsupported locale accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
END $$;
RESET ROLE;

-- Server fixtures for pagination/reserved-balance reads, not client writes.
INSERT INTO public.credit_transactions(user_id,delta,reference_type)
  SELECT '52000000-0000-0000-0000-000000000001',1,'ADJUSTMENT' FROM generate_series(1,3);
UPDATE public.credit_accounts SET finalized_balance=8,reserved_balance=2,version=version+1
  WHERE user_id='52000000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE a jsonb; b jsonb; BEGIN
  a:=public.credit_balance();
  IF a->>'finalized'<>'8' OR a->>'reserved'<>'2' OR a->>'available'<>'6'
    THEN RAISE EXCEPTION 'Reserved credits read failed'; END IF;
  a:=public.credit_transactions_page(2);
  b:=public.credit_transactions_page(2,a->>'next_cursor');
  IF jsonb_array_length(a->'items')<>2 OR jsonb_array_length(b->'items')<>2
    OR b->'next_cursor'<>'null'::jsonb THEN RAISE EXCEPTION 'History pagination failed'; END IF;
  IF a->'items'->0->>'id'=b->'items'->0->>'id' THEN
    RAISE EXCEPTION 'History repeated a page';
  END IF;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
  IF (public.credit_balance()->>'available')<>'5' OR
    jsonb_array_length(public.credit_transactions_page()->'items')<>1 THEN
    RAISE EXCEPTION 'Cross-account balance or history leakage';
  END IF;
  BEGIN PERFORM public.credit_transactions_page(2,encode(convert_to(
    (SELECT id::text FROM public.credit_transactions LIMIT 1),'UTF8'),'base64')||'!');
    RAISE EXCEPTION 'Tampered cursor accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VALIDATION_FAILED' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
UPDATE public.users SET status='DELETING' WHERE id='52000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN PERFORM public.credit_balance();
    RAISE EXCEPTION 'Deleting account allowed to use wallet';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'ACCOUNT_DELETING' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
DELETE FROM public.app_policies WHERE policy_key='mobile';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000001',true);
DO $$ BEGIN
  BEGIN PERFORM public.app_bootstrap('1.0.0','en');
    RAISE EXCEPTION 'Missing policy did not fail closed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'POLICY_UNAVAILABLE' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
ROLLBACK;