-- Run on an empty throwaway migrated database. Transaction always rolls back.
BEGIN;
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000003');
INSERT INTO public.users(id, status) VALUES
 ('00000000-0000-4000-8000-000000000001', 'ACTIVE'),
 ('00000000-0000-4000-8000-000000000002', 'ACTIVE'),
 ('00000000-0000-4000-8000-000000000003', 'DELETED');
INSERT INTO public.app_policies VALUES ('mobile', '1.0.0', NULL, 'test-only', '{}', now());

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.users) <> 0 THEN
   RAISE EXCEPTION 'anonymous user read protected data';
 END IF;
 BEGIN
   PERFORM * FROM public.read_app_policy('mobile');
   RAISE EXCEPTION 'anonymous user read policy';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-000000000001', true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.users) <> 1 THEN
   RAISE EXCEPTION 'owner read failed or other user exposed';
 END IF;
 IF EXISTS (SELECT 1 FROM public.users
            WHERE id = '00000000-0000-4000-8000-000000000002') THEN
   RAISE EXCEPTION 'user A read user B';
 END IF;
 IF (SELECT count(*) FROM public.read_app_policy('mobile')) <> 1 THEN
   RAISE EXCEPTION 'authenticated policy access failed';
 END IF;
 BEGIN
   PERFORM * FROM public.app_policies;
   RAISE EXCEPTION 'raw policy table exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   UPDATE public.users SET status = 'DELETED';
   RAISE EXCEPTION 'client lifecycle mutation permitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   INSERT INTO public.app_policies(policy_key, minimum_supported_version, policy_version)
   VALUES ('unsafe', '1.0.0', 'test');
   RAISE EXCEPTION 'client policy mutation permitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
SELECT set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-000000000002', true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.users) <> 1 OR
    EXISTS (SELECT 1 FROM public.users
            WHERE id = '00000000-0000-4000-8000-000000000001') THEN
   RAISE EXCEPTION 'user B isolation failed';
 END IF;
END $$;
SELECT set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-000000000003', true);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.users) THEN
   RAISE EXCEPTION 'deleted account visible';
 END IF;
END $$;
RESET ROLE;
ROLLBACK;