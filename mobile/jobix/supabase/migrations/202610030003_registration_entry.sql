-- Minimal account-routing metadata, not Resume configuration or a product default.
-- Existing accounts remain returning accounts; no profile backfill.
BEGIN;
ALTER TABLE public.users ADD COLUMN first_profile_entry_pending boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.jobix_new_account()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE profile uuid;
BEGIN
 INSERT INTO public.users(id, first_profile_entry_pending) VALUES (NEW.id, true);
 INSERT INTO public.profile_slots(user_id, slot_number, unlocked, unlocked_at)
 VALUES (NEW.id, 1, true, now());
 INSERT INTO public.career_profiles(user_id, slot_number)
 VALUES (NEW.id, 1) RETURNING id INTO profile;
 INSERT INTO public.profile_personal_data(profile_id) VALUES(profile);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.jobix_new_account() FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.claim_registration_entry()
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE pending boolean;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 SELECT first_profile_entry_pending INTO pending FROM public.users
 WHERE id=auth.uid() AND status='ACTIVE' AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 IF pending THEN
  UPDATE public.users SET first_profile_entry_pending=false, updated_at=now() WHERE id=auth.uid();
 END IF;
 RETURN pending;
END $$;
REVOKE ALL ON FUNCTION public.claim_registration_entry() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_registration_entry() TO authenticated;
COMMIT;