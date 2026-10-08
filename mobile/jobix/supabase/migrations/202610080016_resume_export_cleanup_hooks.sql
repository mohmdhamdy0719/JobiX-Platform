-- Local private hooks only. No new deletion flow or snapshot purge policy.
BEGIN;
ALTER TABLE public.export_jobs ADD COLUMN object_cleanup_verified_at timestamptz;
CREATE FUNCTION public.jobix_export_freeze(actor uuid,profile uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.export_jobs; r public.credit_reservations;
BEGIN
 PERFORM 1 FROM public.users WHERE id=actor FOR UPDATE;
 IF NOT EXISTS(SELECT FROM public.users WHERE id=actor AND status='DELETING')
 AND NOT (profile IS NOT NULL AND EXISTS(SELECT FROM public.career_profiles
 WHERE id=profile AND user_id=actor AND status='DELETING')) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 PERFORM 1 FROM public.credit_accounts WHERE user_id=actor FOR UPDATE;
 FOR j IN SELECT * FROM public.export_jobs WHERE user_id=actor
 AND (profile IS NULL OR profile_id=profile) ORDER BY id FOR UPDATE LOOP
  SELECT * INTO r FROM public.credit_reservations WHERE id=j.reservation_id FOR UPDATE;
  IF r.state='PENDING' THEN PERFORM public.finish_resume_credits_pre_export(j.id,r.fencing_token,false); END IF;
  UPDATE public.export_jobs SET state='DELETION_PENDING',lease_token=NULL,lease_expires_at=NULL,
   updated_at=now() WHERE id=j.id AND state<>'DELETED';
 END LOOP;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',job.id,'path',
 'exports/'||job.user_id||'/'||job.id||'/'||s.source_sha256||'.pdf') ORDER BY job.id)
 FROM public.export_jobs job JOIN public.export_snapshots s ON s.id=job.snapshot_id
 WHERE job.user_id=actor AND (profile IS NULL OR job.profile_id=profile)),'[]');
END $$;
CREATE FUNCTION public.jobix_export_retention() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.export_jobs SET state='EXPIRED',updated_at=now()
 WHERE state='COMPLETED' AND expires_at<=now();
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'path',object_path,
 'generation',object_generation)) FROM public.export_jobs
 WHERE state='EXPIRED' AND expires_at<=now() AND object_path IS NOT NULL
 AND object_cleanup_verified_at IS NULL),'[]');
END $$;
CREATE FUNCTION public.jobix_export_cleaned(operation uuid,generation text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.export_jobs SET object_cleanup_verified_at=now()
 WHERE id=operation AND state='EXPIRED' AND object_generation=generation
 AND expires_at<=now();
 IF NOT FOUND THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_freeze(uuid,uuid),public.jobix_export_retention()
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_freeze(uuid,uuid),public.jobix_export_retention() TO jobix_export_worker;
REVOKE ALL ON FUNCTION public.jobix_export_cleaned(uuid,text) FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_cleaned(uuid,text) TO jobix_export_worker;
COMMIT;
