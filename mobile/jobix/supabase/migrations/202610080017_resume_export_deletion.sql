-- Approved PDF-scoped freeze/remove/verify integration. No new retention period.
BEGIN;
CREATE TABLE public.export_upload_flights (
 operation uuid NOT NULL REFERENCES public.export_jobs(id) ON DELETE CASCADE,
 fence uuid NOT NULL,
 state text NOT NULL DEFAULT 'SENT' CHECK(state IN ('SENT','SETTLED')),
 generation text,
 PRIMARY KEY(operation,fence)
);
ALTER TABLE public.export_upload_flights ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_upload_flights FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.jobix_export_upload_begin(operation uuid,fence uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid;
BEGIN
 SELECT user_id INTO actor FROM public.export_jobs WHERE id=operation;
 PERFORM 1 FROM public.users WHERE id=actor AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
 PERFORM 1 FROM public.export_jobs j JOIN public.career_profiles p ON p.id=j.profile_id
 WHERE j.id=operation AND j.lease_token=fence AND fence IS NOT NULL
 AND j.lease_expires_at>now() AND j.deadline>now() AND j.state='UPLOADING'
 AND p.user_id=actor AND p.status='ACTIVE' FOR UPDATE OF j;
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
 IF EXISTS(SELECT FROM public.export_upload_flights f WHERE f.operation=jobix_export_upload_begin.operation AND f.state='SENT')
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 -- One physical create request per fence, including after process restarts.
 INSERT INTO public.export_upload_flights(operation,fence) VALUES(operation,fence);
END $$;
CREATE FUNCTION public.jobix_export_upload_settle(operation uuid,fence uuid,generation text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 -- A provider response may arrive after lease loss. It records only the
 -- original physical request's settlement; it cannot finalize/debit a job.
 IF generation IS NOT NULL AND generation !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 UPDATE public.export_upload_flights f SET state='SETTLED',generation=coalesce(f.generation,jobix_export_upload_settle.generation)
 WHERE f.operation=jobix_export_upload_settle.operation AND f.fence=jobix_export_upload_settle.fence;
 IF NOT FOUND THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
END $$;
CREATE FUNCTION public.jobix_export_quiescent(actor uuid,profile uuid DEFAULT NULL) RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT (EXISTS(SELECT FROM public.users WHERE id=actor AND status='DELETING')
 OR (profile IS NOT NULL AND EXISTS(SELECT FROM public.career_profiles WHERE id=profile AND user_id=actor AND status='DELETING')))
 AND NOT EXISTS(SELECT FROM public.export_jobs j WHERE j.user_id=actor
 AND (profile IS NULL OR j.profile_id=profile) AND
 (j.state<>'DELETION_PENDING' OR j.lease_token IS NOT NULL))
 AND NOT EXISTS(SELECT FROM public.export_upload_flights f JOIN public.export_jobs j ON j.id=f.operation
 WHERE j.user_id=actor AND (profile IS NULL OR j.profile_id=profile) AND f.state<>'SETTLED');
$$;
ALTER FUNCTION public.jobix_export_freeze(uuid,uuid) RENAME TO jobix_export_freeze_pre_tracking;
REVOKE ALL ON FUNCTION public.jobix_export_freeze_pre_tracking(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role,jobix_export_worker,jobix_export_gateway;
CREATE FUNCTION public.jobix_export_freeze(actor uuid,profile uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE paths jsonb;
BEGIN
 paths:=public.jobix_export_freeze_pre_tracking(actor,profile);
 RETURN coalesce((SELECT jsonb_agg(path||jsonb_build_object('document_sha256',s.document_sha256,'source_sha256',s.source_sha256))
 FROM jsonb_array_elements(paths) path JOIN public.export_jobs j ON j.id=(path->>'id')::uuid
 JOIN public.export_snapshots s ON s.id=j.snapshot_id),'[]');
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_freeze(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_freeze(uuid,uuid) TO jobix_export_worker;
CREATE FUNCTION public.jobix_export_purge(actor uuid,profile uuid DEFAULT NULL,objects_verified boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE operations uuid[]; reservations uuid[];
BEGIN
 PERFORM 1 FROM public.users WHERE id=actor FOR UPDATE;
 PERFORM 1 FROM public.credit_accounts WHERE user_id=actor FOR UPDATE;
 PERFORM 1 FROM public.export_jobs WHERE user_id=actor AND (profile IS NULL OR profile_id=profile) ORDER BY id FOR UPDATE;
 IF objects_verified IS DISTINCT FROM true OR NOT public.jobix_export_quiescent(actor,profile)
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 SELECT array_agg(id),array_agg(reservation_id) INTO operations,reservations
 FROM public.export_jobs WHERE user_id=actor AND (profile IS NULL OR profile_id=profile);
 IF EXISTS(SELECT FROM public.credit_reservations WHERE id=ANY(reservations) AND state='PENDING')
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 DELETE FROM public.idempotency_records WHERE user_id=actor AND operation_id=ANY(operations)
 AND operation_type IN ('export.create','export.again');
 DELETE FROM public.export_jobs WHERE id=ANY(operations);
 DELETE FROM public.export_snapshots WHERE user_id=actor AND (profile IS NULL OR profile_id=profile);
 DELETE FROM public.credit_reservations WHERE id=ANY(reservations);
 IF EXISTS(SELECT FROM public.export_jobs WHERE user_id=actor AND (profile IS NULL OR profile_id=profile))
 OR EXISTS(SELECT FROM public.export_snapshots WHERE user_id=actor AND (profile IS NULL OR profile_id=profile))
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 -- No account/Auth/slot/immutable-ledger deletion or completion assertion.
 RETURN jsonb_build_object('state','EXPORT_DATA_REMOVED','objects_verified',true,'snapshots_verified',true);
END $$;
CREATE FUNCTION public.jobix_export_deletions() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(scope),'[]') FROM (
 SELECT jsonb_build_object('actor',u.id,'profile',NULL) scope FROM public.users u
 WHERE u.status='DELETING' AND (EXISTS(SELECT FROM public.export_jobs WHERE user_id=u.id)
 OR EXISTS(SELECT FROM public.export_snapshots WHERE user_id=u.id))
 UNION ALL
 SELECT jsonb_build_object('actor',p.user_id,'profile',p.id) FROM public.career_profiles p JOIN public.users u ON u.id=p.user_id
 WHERE p.status='DELETING' AND u.status<>'DELETING' AND (EXISTS(SELECT FROM public.export_jobs WHERE profile_id=p.id)
 OR EXISTS(SELECT FROM public.export_snapshots WHERE profile_id=p.id))
 ) s;
$$;
CREATE FUNCTION public.jobix_export_deletion_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF (TG_TABLE_NAME='users' AND (EXISTS(SELECT FROM public.export_jobs WHERE user_id=OLD.id)
   OR EXISTS(SELECT FROM public.export_snapshots WHERE user_id=OLD.id)))
  OR (TG_TABLE_NAME='career_profiles' AND (EXISTS(SELECT FROM public.export_jobs WHERE profile_id=OLD.id)
   OR EXISTS(SELECT FROM public.export_snapshots WHERE profile_id=OLD.id)))
  THEN RAISE EXCEPTION 'DELETION_PENDING'; END IF;
  RETURN OLD;
 END IF;
 IF NEW.status='DELETING' AND OLD.status IS DISTINCT FROM NEW.status THEN
  IF TG_TABLE_NAME='users' THEN PERFORM public.jobix_export_freeze(NEW.id,NULL);
  ELSE PERFORM public.jobix_export_freeze(NEW.user_id,NEW.id); END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER export_account_freeze AFTER UPDATE OF status ON public.users FOR EACH ROW EXECUTE FUNCTION public.jobix_export_deletion_guard();
CREATE TRIGGER export_profile_freeze AFTER UPDATE OF status ON public.career_profiles FOR EACH ROW EXECUTE FUNCTION public.jobix_export_deletion_guard();
CREATE TRIGGER export_account_delete_guard BEFORE DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.jobix_export_deletion_guard();
CREATE TRIGGER export_profile_delete_guard BEFORE DELETE ON public.career_profiles FOR EACH ROW EXECUTE FUNCTION public.jobix_export_deletion_guard();
REVOKE ALL ON FUNCTION public.jobix_export_upload_begin(uuid,uuid),public.jobix_export_upload_settle(uuid,uuid,text),
 public.jobix_export_quiescent(uuid,uuid),public.jobix_export_purge(uuid,uuid,boolean),
 public.jobix_export_deletions(),public.jobix_export_deletion_guard()
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_upload_begin(uuid,uuid),public.jobix_export_upload_settle(uuid,uuid,text),
 public.jobix_export_quiescent(uuid,uuid),public.jobix_export_purge(uuid,uuid,boolean),public.jobix_export_deletions()
 TO jobix_export_worker;
COMMIT;
