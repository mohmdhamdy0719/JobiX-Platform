-- Preserve a safe cost-resolution path across verified export purges.
BEGIN;

ALTER TABLE public.export_cost_reservations
 ADD COLUMN job_purged_at timestamptz,
 ADD COLUMN orphan_discovered_at timestamptz;
COMMENT ON COLUMN public.export_cost_reservations.job_purged_at IS
 'Set only by verified jobix_export_purge after quiescence and object cleanup succeed.';
COMMENT ON COLUMN public.export_cost_reservations.orphan_discovered_at IS
 'Migration-time discovery of a held reservation without its job; not proof of verified purge or no work.';
CREATE INDEX export_cost_reservations_orphans
 ON public.export_cost_reservations(admitted_at)
 WHERE state='HELD' AND (job_purged_at IS NOT NULL OR orphan_discovered_at IS NOT NULL);

-- Preserve discoverability of holds stranded by the earlier purge behavior.
-- This records only when absence was observed; no historical purge evidence is invented.
UPDATE public.export_cost_reservations r
 SET orphan_discovered_at=clock_timestamp()
 WHERE r.state='HELD' AND r.job_purged_at IS NULL
 AND NOT EXISTS(SELECT FROM public.export_jobs j WHERE j.id=r.operation);

CREATE OR REPLACE FUNCTION public.jobix_export_cost_settle(operation uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.export_cost_budget_policy; r public.export_cost_reservations;
 j public.export_jobs; actual bigint; total_runtime bigint; output_bytes bigint;
 storage_ops bigint; attempts integer; unfinished integer; sent_upload boolean;
 upload_evidence boolean; job_exists boolean;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 SELECT * INTO r FROM public.export_cost_reservations
  WHERE public.export_cost_reservations.operation=jobix_export_cost_settle.operation FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 IF r.state<>'HELD' THEN RETURN r.state; END IF;
 SELECT * INTO j FROM public.export_jobs
  WHERE public.export_jobs.id=jobix_export_cost_settle.operation FOR UPDATE;
 job_exists:=FOUND;
 IF NOT job_exists THEN
  IF r.job_purged_at IS NULL AND r.orphan_discovered_at IS NULL THEN RETURN 'PENDING'; END IF;
 ELSIF j.state NOT IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED','DELETION_PENDING')
  OR (j.state='DELETION_PENDING' AND j.lease_token IS NOT NULL) THEN
  RETURN 'PENDING';
 END IF;
 SELECT EXISTS(SELECT FROM public.export_upload_flights f
  WHERE f.operation=r.operation AND f.state='SENT') INTO sent_upload;
 IF sent_upload THEN RETURN 'AMBIGUOUS'; END IF;
 SELECT EXISTS(SELECT FROM public.export_upload_flights f
  WHERE f.operation=r.operation) INTO upload_evidence;
 SELECT count(*),count(*) FILTER(WHERE finished_at IS NULL),
  coalesce(sum(runtime_ms),0),coalesce(max(pdf_bytes),0),coalesce(sum(storage_operations),0)
 INTO attempts,unfinished,total_runtime,output_bytes,storage_ops
 FROM public.export_cost_attempts a WHERE a.operation=r.operation;
 -- Migration cannot reconstruct pre-cost attempts. Keep their full conservative hold.
 IF r.unknown_prior_attempts>0 OR r.model_version<>p.model_version THEN
  UPDATE public.export_cost_reservations SET state='SETTLED',
   settled_microusd=CASE WHEN r.model_version<>p.model_version
     THEN greatest(r.reserved_microusd,p.budget_microusd) ELSE r.reserved_microusd END,
   settled_at=clock_timestamp(),resolution_kind='conservative_upper_bound'
  WHERE public.export_cost_reservations.operation=r.operation;
  IF r.model_version<>p.model_version THEN
   UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp()
   WHERE singleton;
  END IF;
  RETURN 'SETTLED';
 END IF;
 -- Interrupted work remains held. Deletion is not evidence that rendering did not run.
 IF unfinished>0 THEN RETURN 'AMBIGUOUS'; END IF;
 IF attempts=0 AND upload_evidence THEN
  -- A settled provider upload proves billable work even if its worker meter is absent.
  UPDATE public.export_cost_reservations SET state='SETTLED',
   settled_microusd=reserved_microusd,settled_at=clock_timestamp(),
   resolution_kind='conservative_upper_bound'
  WHERE public.export_cost_reservations.operation=r.operation;
  RETURN 'SETTLED';
 END IF;
 IF attempts=0 AND r.orphan_discovered_at IS NOT NULL AND r.job_purged_at IS NULL THEN
  -- A legacy missing row is not enough evidence to claim a definitive zero-cost outcome.
  RETURN 'AMBIGUOUS';
 END IF;
 IF attempts=0 THEN actual:=0;
 ELSE actual:=public.jobix_export_cost_estimate(total_runtime,output_bytes,
   least(storage_ops,2147483647)::integer);
 END IF;
 IF actual IS NULL THEN
  UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp()
   WHERE singleton;
  UPDATE public.export_cost_reservations SET state='SETTLED',
   settled_microusd=greatest(reserved_microusd,p.budget_microusd),
   settled_at=clock_timestamp(),resolution_kind='conservative_upper_bound'
  WHERE public.export_cost_reservations.operation=r.operation;
  RETURN 'SETTLED';
 END IF;
 UPDATE public.export_cost_reservations
  SET state=CASE WHEN actual=0 THEN 'RELEASED' ELSE 'SETTLED' END,
   settled_microusd=actual,settled_at=clock_timestamp(),
   resolution_kind=CASE WHEN actual=0 THEN 'definitive_no_work' ELSE 'measured_usage' END
 WHERE public.export_cost_reservations.operation=r.operation;
 IF actual>r.reserved_microusd THEN
  UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp()
  WHERE singleton;
 END IF;
 RETURN CASE WHEN actual=0 THEN 'RELEASED' ELSE 'SETTLED' END;
END $$;

CREATE OR REPLACE FUNCTION public.jobix_export_cost_resolve(operation uuid,settled_microusd bigint,
 resolution_kind text,resolution_ref text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.export_cost_budget_policy; r public.export_cost_reservations;
 j public.export_jobs; job_exists boolean; sent_upload boolean;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 SELECT * INTO r FROM public.export_cost_reservations
  WHERE public.export_cost_reservations.operation=jobix_export_cost_resolve.operation FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 IF r.state<>'HELD' THEN RETURN r.state; END IF;
 SELECT * INTO j FROM public.export_jobs
  WHERE public.export_jobs.id=jobix_export_cost_resolve.operation FOR UPDATE;
 job_exists:=FOUND;
 IF job_exists THEN
  IF j.state NOT IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED') THEN
   RAISE EXCEPTION 'INVALID_STATE';
  END IF;
 ELSIF r.job_purged_at IS NULL AND r.orphan_discovered_at IS NULL THEN
  RAISE EXCEPTION 'INVALID_STATE';
 END IF;
 SELECT EXISTS(SELECT FROM public.export_upload_flights f
  WHERE f.operation=r.operation AND f.state='SENT') INTO sent_upload;
 IF sent_upload THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 IF settled_microusd IS NULL OR settled_microusd<0 OR resolution_ref IS NULL
 OR length(resolution_ref) NOT BETWEEN 1 AND 200
 OR resolution_kind NOT IN ('provider_reconciled','conservative_upper_bound','definitive_no_work')
 OR (resolution_kind='conservative_upper_bound' AND settled_microusd<r.reserved_microusd)
 OR (resolution_kind='definitive_no_work' AND
   (settled_microusd<>0 OR r.unknown_prior_attempts>0
    OR (NOT job_exists AND r.job_purged_at IS NULL)
    OR EXISTS(SELECT FROM public.export_cost_attempts a WHERE a.operation=r.operation)
    OR EXISTS(SELECT FROM public.export_upload_flights f WHERE f.operation=r.operation)))
 THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 UPDATE public.export_cost_reservations SET
  state=CASE WHEN jobix_export_cost_resolve.settled_microusd=0 THEN 'RELEASED' ELSE 'SETTLED' END,
  settled_microusd=jobix_export_cost_resolve.settled_microusd,
  settled_at=clock_timestamp(),resolution_kind=jobix_export_cost_resolve.resolution_kind,
  resolution_ref=jobix_export_cost_resolve.resolution_ref
 WHERE public.export_cost_reservations.operation=r.operation;
 IF settled_microusd>r.reserved_microusd THEN
  UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp()
  WHERE singleton;
 END IF;
 RETURN CASE WHEN settled_microusd=0 THEN 'RELEASED' ELSE 'SETTLED' END;
END $$;

CREATE OR REPLACE FUNCTION public.jobix_export_cost_reconcile() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item record; changed integer:=0; result text;
BEGIN
 FOR item IN
  SELECT r.operation FROM public.export_cost_reservations r
  WHERE r.state='HELD' AND (
   r.job_purged_at IS NOT NULL OR r.orphan_discovered_at IS NOT NULL OR EXISTS(
    SELECT FROM public.export_jobs j WHERE j.id=r.operation
    AND j.state IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED'))
  )
  ORDER BY r.admitted_at LIMIT 100
 LOOP
  result:=public.jobix_export_cost_settle(item.operation);
  IF result IN ('SETTLED','RELEASED') THEN changed:=changed+1; END IF;
 END LOOP;
 RETURN changed;
END $$;

CREATE OR REPLACE FUNCTION public.jobix_export_purge(actor uuid,profile uuid DEFAULT NULL,
 objects_verified boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE operations uuid[]; reservations uuid[]; item record; result text;
BEGIN
 -- Match create/settle lock order to avoid cross-accounting deadlocks.
 PERFORM 1 FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 PERFORM 1 FROM public.users WHERE id=actor FOR UPDATE;
 PERFORM 1 FROM public.credit_accounts WHERE user_id=actor FOR UPDATE;
 PERFORM 1 FROM public.export_jobs WHERE user_id=actor
  AND (profile IS NULL OR profile_id=profile) ORDER BY id FOR UPDATE;
 IF objects_verified IS DISTINCT FROM true OR NOT public.jobix_export_quiescent(actor,profile)
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 SELECT array_agg(id),array_agg(reservation_id) INTO operations,reservations
 FROM public.export_jobs WHERE user_id=actor AND (profile IS NULL OR profile_id=profile);
 IF EXISTS(SELECT FROM public.credit_reservations WHERE id=ANY(reservations) AND state='PENDING')
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 -- Settle known usage while the verified, quiescent job still exists. Any
 -- unresolved hold receives a durable marker in this same purge transaction.
 FOR item IN
  SELECT r.operation FROM public.export_cost_reservations r
  WHERE r.operation=ANY(operations) AND r.state='HELD'
  ORDER BY r.operation
 LOOP
  result:=public.jobix_export_cost_settle(item.operation);
  IF result NOT IN ('SETTLED','RELEASED','AMBIGUOUS') THEN
   RAISE EXCEPTION 'CLEANUP_UNVERIFIED';
  END IF;
 END LOOP;
 UPDATE public.export_cost_reservations SET job_purged_at=clock_timestamp()
 WHERE operation=ANY(operations) AND state='HELD';
 DELETE FROM public.idempotency_records WHERE user_id=actor AND operation_id=ANY(operations)
  AND operation_type IN ('export.create','export.again');
 DELETE FROM public.export_jobs WHERE id=ANY(operations);
 DELETE FROM public.export_snapshots WHERE user_id=actor
  AND (profile IS NULL OR profile_id=profile);
 DELETE FROM public.credit_reservations WHERE id=ANY(reservations);
 IF EXISTS(SELECT FROM public.export_jobs WHERE user_id=actor AND (profile IS NULL OR profile_id=profile))
 OR EXISTS(SELECT FROM public.export_snapshots WHERE user_id=actor AND (profile IS NULL OR profile_id=profile))
 THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 RETURN jsonb_build_object('state','EXPORT_DATA_REMOVED','objects_verified',true,
  'snapshots_verified',true);
END $$;

REVOKE ALL ON FUNCTION public.jobix_export_purge(uuid,uuid,boolean)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_purge(uuid,uuid,boolean) TO jobix_export_worker;

COMMIT;
