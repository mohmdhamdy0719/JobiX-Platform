BEGIN;
CREATE TABLE public.credit_reservations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
 operation_id uuid NOT NULL UNIQUE,
 purpose text NOT NULL CHECK(purpose='RESUME_EXPORT'),
 amount integer NOT NULL CHECK(amount=2),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','CONSUMED','RELEASED','EXPIRED')),
 fencing_token uuid NOT NULL DEFAULT gen_random_uuid(),
 expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.credit_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.credit_reservations FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.credit_reservations TO authenticated;
CREATE POLICY reservation_owner ON public.credit_reservations FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE'));

-- Worker-only contract. No Flutter reservation/consume endpoint and no export
-- success simulated before the future worker validates its private PDF object.
CREATE FUNCTION public.reserve_resume_credits(owner_id uuid, operation uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE wallet public.credit_accounts; reservation public.credit_reservations;
BEGIN
 PERFORM 1 FROM public.users WHERE id=owner_id AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO wallet FROM public.credit_accounts WHERE user_id=owner_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 SELECT * INTO reservation FROM public.credit_reservations WHERE operation_id=operation FOR UPDATE;
 IF FOUND THEN
  IF reservation.user_id<>owner_id THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  RETURN to_jsonb(reservation);
 END IF;
 IF wallet.finalized_balance-wallet.reserved_balance<2 THEN RAISE EXCEPTION 'INSUFFICIENT_CREDITS'; END IF;
 INSERT INTO public.credit_reservations(user_id,operation_id,purpose,amount,expires_at)
 VALUES(owner_id,operation,'RESUME_EXPORT',2,now()+interval '30 minutes') RETURNING * INTO reservation;
 UPDATE public.credit_accounts SET reserved_balance=reserved_balance+2,version=version+1,updated_at=now()
 WHERE user_id=owner_id;
 RETURN to_jsonb(reservation);
END $$;
CREATE FUNCTION public.finish_resume_credits(operation uuid,fence uuid,successful boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE reservation public.credit_reservations; owner_id uuid;
BEGIN
 SELECT user_id INTO owner_id FROM public.credit_reservations WHERE operation_id=operation;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 PERFORM 1 FROM public.users WHERE id=owner_id AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND AND successful THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 PERFORM 1 FROM public.credit_accounts WHERE user_id=owner_id FOR UPDATE;
 SELECT * INTO reservation FROM public.credit_reservations WHERE operation_id=operation FOR UPDATE;
 IF fence IS DISTINCT FROM reservation.fencing_token THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
 IF reservation.state IN ('CONSUMED','RELEASED') THEN RETURN reservation.state; END IF;
 IF successful AND (reservation.expires_at<=now() OR reservation.state='EXPIRED') THEN
   RAISE EXCEPTION 'STALE_LEASE';
 END IF;
 IF successful THEN
   INSERT INTO public.credit_transactions(user_id,delta,reference_type,reference_id,idempotency_key)
   VALUES(owner_id,-2,'RESUME_EXPORT',operation,operation);
 END IF;
 UPDATE public.credit_accounts SET reserved_balance=reserved_balance-reservation.amount,
 finalized_balance=finalized_balance-CASE WHEN successful THEN reservation.amount ELSE 0 END,
 version=version+1,updated_at=now() WHERE user_id=owner_id;
 UPDATE public.credit_reservations SET state=CASE WHEN successful THEN 'CONSUMED' ELSE 'RELEASED' END,
 updated_at=now() WHERE id=reservation.id RETURNING * INTO reservation;
 RETURN reservation.state;
END $$;
CREATE FUNCTION public.expire_resume_credits() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.credit_reservations; count integer:=0;
BEGIN
 FOR r IN SELECT * FROM public.credit_reservations
 WHERE state='PENDING' AND expires_at<=now() ORDER BY user_id,id LOOP
  PERFORM public.finish_resume_credits(r.operation_id,r.fencing_token,false);
  count:=count+1;
 END LOOP;
 RETURN count;
END $$;
REVOKE ALL ON FUNCTION public.reserve_resume_credits(uuid,uuid),
 public.finish_resume_credits(uuid,uuid,boolean),public.expire_resume_credits() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_resume_credits(uuid,uuid),
 public.finish_resume_credits(uuid,uuid,boolean),public.expire_resume_credits() TO service_role;

CREATE TABLE public.ai_allowance_accounts (
 user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
 first_profile_id uuid REFERENCES public.career_profiles(id) ON DELETE SET NULL,
 first_total integer NOT NULL DEFAULT 6 CHECK(first_total=6),
 first_reserved integer NOT NULL DEFAULT 0 CHECK(first_reserved>=0),
 first_consumed integer NOT NULL DEFAULT 0 CHECK(first_consumed>=0),
 first_phase_ended_at timestamptz,
 first_phase_ended_cairo_date date,
 daily_cairo_date date,
 daily_limit integer NOT NULL DEFAULT 3 CHECK(daily_limit IN (3,10)),
 daily_reserved integer NOT NULL DEFAULT 0 CHECK(daily_reserved>=0),
 daily_consumed integer NOT NULL DEFAULT 0 CHECK(daily_consumed>=0),
 version bigint NOT NULL DEFAULT 1,
 CHECK(first_reserved+first_consumed<=first_total),
 CHECK(daily_reserved+daily_consumed<=daily_limit)
);
ALTER TABLE public.ai_allowance_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_allowance_accounts FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.jobix_latch_ai_phase() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.slot_number=1 AND NEW.completeness_percent>=50 THEN
  INSERT INTO public.ai_allowance_accounts(user_id,first_profile_id,first_phase_ended_at,first_phase_ended_cairo_date)
  VALUES(NEW.user_id,NEW.id,now(),(now() AT TIME ZONE 'Africa/Cairo')::date)
  ON CONFLICT(user_id) DO UPDATE SET first_phase_ended_at=coalesce(public.ai_allowance_accounts.first_phase_ended_at,EXCLUDED.first_phase_ended_at),
  first_phase_ended_cairo_date=coalesce(public.ai_allowance_accounts.first_phase_ended_cairo_date,EXCLUDED.first_phase_ended_cairo_date);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.jobix_latch_ai_phase() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER latch_first_ai_phase AFTER UPDATE OF completeness_percent ON public.career_profiles
 FOR EACH ROW EXECUTE FUNCTION public.jobix_latch_ai_phase();
CREATE FUNCTION public.ai_allowance() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.career_profiles; a public.ai_allowance_accounts;
 today date:=(now() AT TIME ZONE 'Africa/Cairo')::date; ended boolean;
BEGIN
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 SELECT * INTO p FROM public.career_profiles WHERE user_id=auth.uid() AND slot_number=1 AND status='ACTIVE';
 IF NOT FOUND THEN RAISE EXCEPTION 'PROFILE_NOT_FOUND'; END IF;
 INSERT INTO public.ai_allowance_accounts(user_id,first_profile_id,first_phase_ended_at,first_phase_ended_cairo_date)
 VALUES(auth.uid(),p.id,CASE WHEN p.completeness_percent>=50 THEN now() END,
 CASE WHEN p.completeness_percent>=50 THEN today END) ON CONFLICT DO NOTHING;
 SELECT * INTO a FROM public.ai_allowance_accounts WHERE user_id=auth.uid() FOR UPDATE;
 ended:=a.first_phase_ended_at IS NOT NULL;
 -- There is no Premium billing/entitlement writer in this milestone. All
 -- actually provisioned accounts are Free; a client cannot select Premium.
 RETURN jsonb_build_object('bucket',CASE WHEN ended THEN 'DAILY' ELSE 'FIRST_PROFILE' END,
 'limit',CASE WHEN ended THEN a.daily_limit ELSE a.first_total END,
 'used',CASE WHEN ended THEN CASE WHEN a.daily_cairo_date=today THEN a.daily_consumed ELSE 0 END ELSE a.first_consumed END,
 'reserved',CASE WHEN ended THEN CASE WHEN a.daily_cairo_date=today THEN a.daily_reserved ELSE 0 END ELSE a.first_reserved END,
 'available_from',CASE WHEN ended AND a.first_phase_ended_cairo_date>=today THEN a.first_phase_ended_cairo_date+1 ELSE today END,
 'generation_enabled',false);
END $$;
REVOKE ALL ON FUNCTION public.ai_allowance() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ai_allowance() TO authenticated;
COMMIT;
