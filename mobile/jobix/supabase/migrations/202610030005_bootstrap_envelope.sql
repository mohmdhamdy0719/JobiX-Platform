-- Complete the Architecture V2 read-only bootstrap response metadata.
BEGIN;
CREATE OR REPLACE FUNCTION public.app_bootstrap(app_version text, app_locale text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  policy public.app_policies;
  balance jsonb;
  profiles jsonb;
  slots jsonb;
  account jsonb;
BEGIN
  balance := public.credit_balance();
  IF app_version IS NULL OR app_version !~ '^[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}$'
    OR app_locale IS NULL OR app_locale NOT IN ('en','ar') THEN
    RAISE EXCEPTION 'VALIDATION_FAILED';
  END IF;
  SELECT * INTO policy FROM public.app_policies WHERE policy_key='mobile';
  IF NOT FOUND OR policy.minimum_supported_version IS NULL THEN
    RAISE EXCEPTION 'POLICY_UNAVAILABLE';
  END IF;
  IF string_to_array(app_version,'.')::integer[] <
      string_to_array(policy.minimum_supported_version,'.')::integer[] THEN
    RAISE EXCEPTION 'APP_UPDATE_REQUIRED';
  END IF;
  SELECT jsonb_build_object('id',u.id,'status',u.status,
    'created_at',u.created_at,'updated_at',u.updated_at) INTO account
    FROM public.users u WHERE u.id=auth.uid() AND u.status='ACTIVE';
  SELECT coalesce(jsonb_agg(to_jsonb(p)-'user_id' ORDER BY p.slot_number),'[]')
    INTO profiles FROM public.career_profiles p WHERE p.user_id=auth.uid() AND p.status='ACTIVE';
  SELECT coalesce(jsonb_agg(to_jsonb(s)-'user_id' ORDER BY s.slot_number),'[]')
    INTO slots FROM public.profile_slots s WHERE s.user_id=auth.uid();
  RETURN jsonb_build_object('request_id',gen_random_uuid(),'operation_id',NULL,'state','SUCCEEDED',
    'data',jsonb_build_object('user',account,
      'policy',jsonb_build_object('policy_key',policy.policy_key,
        'minimum_supported_version',policy.minimum_supported_version,
        'recommended_version',policy.recommended_version,'policy_version',policy.policy_version),
      'profiles',profiles,'slots',slots,'balance',balance),
    'authoritative_version',NULL,'error',NULL);
END $$;
REVOKE ALL ON FUNCTION public.app_bootstrap(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_bootstrap(text,text) TO authenticated;
COMMIT;