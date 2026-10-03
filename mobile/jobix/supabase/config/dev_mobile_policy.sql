-- OWNER-APPROVED DEVELOPMENT CONFIGURATION ONLY.
-- Not an application schema migration; never apply to staging/production.
-- Versions must be reviewed before production launch.
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('jobix_dev_mobile_policy'));
DO $$
BEGIN
  IF to_regclass('public.app_policies') IS NULL THEN
    RAISE EXCEPTION 'Existing Foundation policy schema is required';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.app_policies
    WHERE policy_key = 'mobile'
      AND (minimum_supported_version <> '1.0.0'
        OR recommended_version IS DISTINCT FROM '1.0.0'
        OR policy_version <> '1')
  ) THEN
    RAISE EXCEPTION 'Existing operational policy differs; refusing to overwrite';
  END IF;
END $$;
INSERT INTO public.app_policies
  (policy_key, minimum_supported_version, recommended_version, policy_version)
VALUES ('mobile', '1.0.0', '1.0.0', '1')
ON CONFLICT (policy_key) DO NOTHING;
COMMIT;