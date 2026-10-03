-- Core MVP slice: authenticated bootstrap, credits and signup ledger.
-- Additive to the existing Foundation. No provider, reward, export or policy edits.
BEGIN;

CREATE TABLE public.credit_accounts (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  finalized_balance integer NOT NULL DEFAULT 0 CHECK (finalized_balance >= 0),
  reserved_balance integer NOT NULL DEFAULT 0 CHECK (reserved_balance >= 0),
  version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (reserved_balance <= finalized_balance)
);
CREATE TABLE public.credit_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  delta integer NOT NULL CHECK (delta <> 0),
  reference_type text NOT NULL CHECK (reference_type IN
    ('SIGNUP','RESUME_EXPORT','COVER_LETTER_EXPORT','PROFESSIONAL_EMAIL',
     'PROFILE_SLOT','DAILY_REWARD','ADJUSTMENT')),
  reference_id uuid,
  idempotency_key uuid,
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_credit_reference_idempotency
  ON public.credit_transactions(user_id,reference_type,idempotency_key)
  WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX uq_credit_signup ON public.credit_transactions(user_id)
  WHERE reference_type = 'SIGNUP';
CREATE INDEX ix_credit_history ON public.credit_transactions(user_id,created_at DESC,id DESC);

ALTER TABLE public.credit_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.credit_accounts, public.credit_transactions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.credit_accounts, public.credit_transactions TO authenticated;
CREATE POLICY credit_accounts_owner ON public.credit_accounts FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND EXISTS
    (SELECT 1 FROM public.users u WHERE u.id = user_id AND u.status = 'ACTIVE'));
CREATE POLICY credit_transactions_owner ON public.credit_transactions FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND EXISTS
    (SELECT 1 FROM public.users u WHERE u.id = user_id AND u.status = 'ACTIVE'));

-- Historical accounts get a zero-balance wallet, NOT a retroactive grant.
INSERT INTO public.credit_accounts(user_id) SELECT id FROM public.users;

CREATE FUNCTION public.jobix_signup_credits() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.credit_accounts(user_id,finalized_balance) VALUES (NEW.id,5);
  INSERT INTO public.credit_transactions(user_id,delta,reference_type,reference_id,idempotency_key)
    VALUES (NEW.id,5,'SIGNUP',NEW.id,NEW.id);
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.jobix_signup_credits() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER jobix_signup_credit_grant AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.jobix_signup_credits();

CREATE FUNCTION public.credit_balance() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE wallet public.credit_accounts;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE')
    THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
  SELECT * INTO wallet FROM public.credit_accounts WHERE user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
  RETURN jsonb_build_object('finalized',wallet.finalized_balance,
    'reserved',wallet.reserved_balance,
    'available',wallet.finalized_balance-wallet.reserved_balance,'version',wallet.version);
END $$;
REVOKE ALL ON FUNCTION public.credit_balance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.credit_balance() TO authenticated;

CREATE FUNCTION public.credit_transactions_page(page_size integer DEFAULT 25, page_cursor text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  anchor public.credit_transactions;
  anchor_id uuid;
  rows jsonb;
  next_key text;
BEGIN
  PERFORM public.credit_balance();
  IF page_size IS NULL OR page_size < 1 OR page_size > 100 THEN
    RAISE EXCEPTION 'VALIDATION_FAILED';
  END IF;
  IF page_cursor IS NOT NULL THEN
    BEGIN
      anchor_id := convert_from(decode(page_cursor,'base64'),'UTF8')::uuid;
    EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END;
    SELECT * INTO anchor FROM public.credit_transactions
      WHERE id=anchor_id AND user_id=auth.uid();
    IF NOT FOUND THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(t)-'user_id' ORDER BY t.created_at DESC,t.id DESC),'[]')
    INTO rows FROM (
      SELECT * FROM public.credit_transactions
      WHERE user_id=auth.uid() AND
        (page_cursor IS NULL OR (created_at,id)<(anchor.created_at,anchor.id))
      ORDER BY created_at DESC,id DESC LIMIT page_size
    ) t;
  IF jsonb_array_length(rows)=page_size THEN
    anchor_id := (rows->(page_size-1)->>'id')::uuid;
    SELECT * INTO anchor FROM public.credit_transactions WHERE id=anchor_id;
    IF EXISTS(SELECT 1 FROM public.credit_transactions WHERE user_id=auth.uid()
      AND (created_at,id)<(anchor.created_at,anchor.id)) THEN
      next_key := encode(convert_to(anchor_id::text,'UTF8'),'base64');
    END IF;
  END IF;
  RETURN jsonb_build_object('items',rows,'next_cursor',next_key);
END $$;
REVOKE ALL ON FUNCTION public.credit_transactions_page(integer,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.credit_transactions_page(integer,text) TO authenticated;

CREATE FUNCTION public.app_bootstrap(app_version text, app_locale text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE minimum_version text; balance jsonb; profiles jsonb; slots jsonb;
BEGIN
  balance := public.credit_balance();
  IF app_version IS NULL OR app_version !~ '^[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}$'
    OR app_locale IS NULL OR app_locale NOT IN ('en','ar') THEN
    RAISE EXCEPTION 'VALIDATION_FAILED';
  END IF;
  SELECT minimum_supported_version INTO minimum_version FROM public.app_policies WHERE policy_key='mobile';
  IF NOT FOUND OR minimum_version IS NULL THEN RAISE EXCEPTION 'POLICY_UNAVAILABLE'; END IF;
  IF string_to_array(app_version,'.')::integer[] <
      string_to_array(minimum_version,'.')::integer[] THEN RAISE EXCEPTION 'APP_UPDATE_REQUIRED'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(p)-'user_id' ORDER BY p.slot_number),'[]')
    INTO profiles FROM public.career_profiles p WHERE p.user_id=auth.uid() AND p.status='ACTIVE';
  SELECT coalesce(jsonb_agg(to_jsonb(s)-'user_id' ORDER BY s.slot_number),'[]')
    INTO slots FROM public.profile_slots s WHERE s.user_id=auth.uid();
  RETURN jsonb_build_object('request_id',NULL,'operation_id',NULL,'state','SUCCEEDED',
    'data',jsonb_build_object('profiles',profiles,'slots',slots,'balance',balance),
    'authoritative_version',NULL,'error',NULL);
END $$;
REVOKE ALL ON FUNCTION public.app_bootstrap(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_bootstrap(text,text) TO authenticated;
COMMIT;