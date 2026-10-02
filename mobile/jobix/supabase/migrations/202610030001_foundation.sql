-- Foundation only. Supabase Auth is supplied by Supabase, not recreated here.
BEGIN;

CREATE TABLE public.users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'ACTIVE'
      CHECK (status IN ('ACTIVE', 'DELETING', 'DELETED')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.users FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.users TO anon, authenticated;
CREATE POLICY users_select_owner ON public.users FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()) AND status <> 'DELETED');
-- Lifecycle commands are server-only. No client insert/update/delete policy.

CREATE TABLE public.app_policies (
    policy_key text PRIMARY KEY,
    minimum_supported_version text NOT NULL
      CHECK (minimum_supported_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'),
    recommended_version text,
    policy_version text NOT NULL,
    configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.app_policies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_policies FROM PUBLIC, anon, authenticated;
-- No approved minimum supported app version yet: never seed one silently.

CREATE FUNCTION public.read_app_policy(requested_key text)
RETURNS TABLE (
    policy_key text,
    minimum_supported_version text,
    recommended_version text,
    policy_version text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT p.policy_key, p.minimum_supported_version,
           p.recommended_version, p.policy_version
    FROM public.app_policies p
    WHERE p.policy_key = requested_key
      AND (SELECT auth.uid()) IS NOT NULL
$$;
REVOKE ALL ON FUNCTION public.read_app_policy(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.read_app_policy(text) TO authenticated;

COMMIT;