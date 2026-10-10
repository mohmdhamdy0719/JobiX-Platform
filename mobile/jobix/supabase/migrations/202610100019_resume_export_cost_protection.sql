-- Local implementation only. The policy starts not-ready until an owner
-- configures verified rates and a conservative shared-cost reserve.
BEGIN;

CREATE TABLE public.export_cost_budget_policy (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 budget_microusd bigint NOT NULL DEFAULT 10000000 CHECK(budget_microusd>0),
 rolling_window interval NOT NULL DEFAULT interval '7 days'
  CHECK(rolling_window=interval '7 days'),
 shared_cost_reserve_microusd bigint,
 runtime_cost_microusd_per_second bigint,
 output_cost_microusd_per_gib_7d bigint,
 storage_operation_cost_microusd bigint,
 per_export_overhead_microusd bigint,
 max_runtime_ms bigint NOT NULL DEFAULT 1800000 CHECK(max_runtime_ms BETWEEN 1 AND 1800000),
 max_pdf_bytes bigint NOT NULL DEFAULT 10485760 CHECK(max_pdf_bytes BETWEEN 1 AND 10485760),
 max_storage_operations integer NOT NULL DEFAULT 24 CHECK(max_storage_operations BETWEEN 1 AND 256),
 warning_70_percent integer NOT NULL DEFAULT 70 CHECK(warning_70_percent=70),
 warning_85_percent integer NOT NULL DEFAULT 85 CHECK(warning_85_percent=85),
 warning_95_percent integer NOT NULL DEFAULT 95 CHECK(warning_95_percent=95),
 accounting_ready boolean NOT NULL DEFAULT false,
 model_version integer NOT NULL DEFAULT 1 CHECK(model_version>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(shared_cost_reserve_microusd IS NULL OR shared_cost_reserve_microusd>=0),
 CHECK(runtime_cost_microusd_per_second IS NULL OR runtime_cost_microusd_per_second>=0),
 CHECK(output_cost_microusd_per_gib_7d IS NULL OR output_cost_microusd_per_gib_7d>=0),
 CHECK(storage_operation_cost_microusd IS NULL OR storage_operation_cost_microusd>=0),
 CHECK(per_export_overhead_microusd IS NULL OR per_export_overhead_microusd>=0)
);
INSERT INTO public.export_cost_budget_policy(singleton) VALUES(true);
ALTER TABLE public.export_cost_budget_policy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_cost_budget_policy FROM PUBLIC,anon,authenticated,service_role,
 jobix_export_gateway,jobix_export_worker;
COMMENT ON COLUMN public.export_cost_budget_policy.model_version IS
 'Increment when rates or per-export caps change; outstanding holds then settle conservatively.';
COMMENT ON COLUMN public.export_cost_budget_policy.budget_microusd IS
 'Admission-control budget, not a guarantee that the provider invoice cannot exceed this amount.';

-- Reservations intentionally have no FK to export_jobs: profile/job cleanup
-- must not erase an unresolved cost hold.
CREATE TABLE public.export_cost_reservations (
 operation uuid PRIMARY KEY,
 admitted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reserved_microusd bigint NOT NULL CHECK(reserved_microusd>=0),
 model_version integer NOT NULL CHECK(model_version>0),
 max_pdf_bytes bigint NOT NULL CHECK(max_pdf_bytes>0),
 settled_microusd bigint,
 resolution_kind text CHECK(resolution_kind IN
  ('measured_usage','provider_reconciled','conservative_upper_bound','definitive_no_work')),
 resolution_ref text CHECK(resolution_ref IS NULL OR length(resolution_ref)<=200),
 state text NOT NULL DEFAULT 'HELD' CHECK(state IN ('HELD','SETTLED','RELEASED')),
 unknown_prior_attempts integer NOT NULL DEFAULT 0 CHECK(unknown_prior_attempts>=0),
 settled_at timestamptz,
 CHECK(settled_microusd IS NULL OR settled_microusd>=0),
 CHECK((state='HELD' AND settled_microusd IS NULL AND settled_at IS NULL)
    OR (state='SETTLED' AND settled_microusd IS NOT NULL AND settled_at IS NOT NULL)
    OR (state='RELEASED' AND settled_microusd=0 AND settled_at IS NOT NULL))
);
ALTER TABLE public.export_cost_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_cost_reservations FROM PUBLIC,anon,authenticated,service_role,
 jobix_export_gateway,jobix_export_worker;
CREATE INDEX export_cost_reservations_window
 ON public.export_cost_reservations(admitted_at DESC) WHERE state<>'RELEASED';

CREATE TABLE public.export_cost_attempts (
 operation uuid NOT NULL,
 fence uuid NOT NULL,
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 finished_at timestamptz,
 runtime_ms bigint,
 pdf_bytes bigint,
 storage_operations integer,
 PRIMARY KEY(operation,fence),
 CHECK(runtime_ms IS NULL OR runtime_ms>=0),
 CHECK(pdf_bytes IS NULL OR pdf_bytes>=0),
 CHECK(storage_operations IS NULL OR storage_operations>=0),
 CHECK((finished_at IS NULL AND runtime_ms IS NULL AND pdf_bytes IS NULL AND storage_operations IS NULL)
    OR (finished_at IS NOT NULL AND runtime_ms IS NOT NULL AND pdf_bytes IS NOT NULL AND storage_operations IS NOT NULL))
);
ALTER TABLE public.export_cost_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_cost_attempts FROM PUBLIC,anon,authenticated,service_role,
 jobix_export_gateway,jobix_export_worker;

-- Provider totals are reconciliation evidence only. They are never added to
-- the admission sum; shared residuals are configured separately to prevent
-- double-counting provider totals against per-export reservations.
CREATE TABLE public.export_cost_provider_observations (
 provider text NOT NULL,
 service text NOT NULL,
 window_start timestamptz NOT NULL,
 window_end timestamptz NOT NULL,
 observed_microusd bigint NOT NULL CHECK(observed_microusd>=0),
 modeled_export_microusd bigint NOT NULL CHECK(modeled_export_microusd>=0),
 source_ref text NOT NULL CHECK(length(source_ref) BETWEEN 1 AND 200),
 observed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(provider,service,window_start,window_end),
 CHECK(window_end>window_start)
);
ALTER TABLE public.export_cost_provider_observations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_cost_provider_observations FROM PUBLIC,anon,authenticated,service_role,
 jobix_export_gateway,jobix_export_worker;

-- No durable purge marker was available when this migration was prepared.
-- Populate only from verified retained purge evidence; never synthesize for all users.
CREATE TABLE public.export_admission_legacy_holds (
 user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
 hold_until timestamptz NOT NULL,
 evidence_kind text NOT NULL CHECK(evidence_kind='verified_profile_purge'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.export_admission_legacy_holds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_admission_legacy_holds FROM PUBLIC,anon,authenticated,service_role,
 jobix_export_gateway,jobix_export_worker;

CREATE FUNCTION public.jobix_export_cost_estimate(runtime_ms bigint,pdf_bytes bigint,storage_operations integer)
RETURNS bigint LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.export_cost_budget_policy; estimate numeric;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton;
 IF NOT FOUND OR NOT p.accounting_ready OR p.shared_cost_reserve_microusd IS NULL
 OR p.runtime_cost_microusd_per_second IS NULL
 OR p.output_cost_microusd_per_gib_7d IS NULL
 OR p.storage_operation_cost_microusd IS NULL
 OR p.per_export_overhead_microusd IS NULL
 OR runtime_ms IS NULL OR pdf_bytes IS NULL OR storage_operations IS NULL
 OR runtime_ms<0 OR pdf_bytes<0 OR storage_operations<0
 OR runtime_ms>p.max_runtime_ms OR pdf_bytes>p.max_pdf_bytes
 OR storage_operations>p.max_storage_operations THEN RETURN NULL; END IF;
 estimate:=p.per_export_overhead_microusd
  +ceil(runtime_ms::numeric*p.runtime_cost_microusd_per_second/1000)
  +ceil(pdf_bytes::numeric*p.output_cost_microusd_per_gib_7d*7/1073741824)
  +storage_operations::numeric*p.storage_operation_cost_microusd;
 IF estimate<0 OR estimate>9223372036854775807::numeric THEN RETURN NULL; END IF;
 RETURN ceil(estimate)::bigint;
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_cost_estimate(bigint,bigint,integer)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;

CREATE FUNCTION public.jobix_export_cost_reserve(operation uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.export_cost_budget_policy; maximum bigint; used numeric;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 IF NOT FOUND OR NOT p.accounting_ready THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 maximum:=public.jobix_export_cost_estimate(p.max_runtime_ms,p.max_pdf_bytes,p.max_storage_operations);
 IF maximum IS NULL OR maximum<=0 OR p.shared_cost_reserve_microusd IS NULL THEN
  RAISE EXCEPTION 'SERVICE_UNAVAILABLE';
 END IF;
 SELECT p.shared_cost_reserve_microusd+coalesce(sum(CASE
   WHEN r.state='HELD' THEN r.reserved_microusd
   WHEN r.state='SETTLED' AND r.admitted_at>clock_timestamp()-p.rolling_window
     THEN r.settled_microusd
   ELSE 0 END),0)
 INTO used FROM public.export_cost_reservations r;
 IF used+maximum>p.budget_microusd THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 INSERT INTO public.export_cost_reservations(operation,reserved_microusd,model_version,max_pdf_bytes)
 VALUES(jobix_export_cost_reserve.operation,maximum,p.model_version,p.max_pdf_bytes);
 RETURN maximum;
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_cost_reserve(uuid)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;

CREATE FUNCTION public.jobix_export_cost_attempt_start(operation uuid,fence uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT FROM public.export_cost_reservations r
  JOIN public.export_jobs j ON j.id=r.operation
  WHERE r.operation=jobix_export_cost_attempt_start.operation AND r.state='HELD'
  AND j.lease_token=fence AND j.lease_expires_at>clock_timestamp()
  AND j.deadline>clock_timestamp() AND j.state IN ('CLAIMED','GENERATING','UPLOADING')) THEN
  RAISE EXCEPTION 'STALE_LEASE';
 END IF;
 INSERT INTO public.export_cost_attempts(operation,fence)
 VALUES(jobix_export_cost_attempt_start.operation,jobix_export_cost_attempt_start.fence)
 ON CONFLICT ON CONSTRAINT export_cost_attempts_pkey DO NOTHING;
END $$;

CREATE FUNCTION public.jobix_export_cost_attempt_finish(operation uuid,fence uuid,
 runtime_ms bigint,pdf_bytes bigint,storage_operations integer) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF runtime_ms IS NULL OR runtime_ms<0 OR pdf_bytes IS NULL OR pdf_bytes<0
 OR storage_operations IS NULL OR storage_operations<0 THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 UPDATE public.export_cost_attempts a SET finished_at=clock_timestamp(),runtime_ms=
  greatest(coalesce(a.runtime_ms,0),jobix_export_cost_attempt_finish.runtime_ms),
  pdf_bytes=greatest(coalesce(a.pdf_bytes,0),jobix_export_cost_attempt_finish.pdf_bytes),
  storage_operations=greatest(coalesce(a.storage_operations,0),
   jobix_export_cost_attempt_finish.storage_operations)
 WHERE a.operation=jobix_export_cost_attempt_finish.operation
  AND a.fence=jobix_export_cost_attempt_finish.fence AND a.finished_at IS NULL
  AND EXISTS(SELECT FROM public.export_jobs j WHERE j.id=a.operation AND j.lease_token=a.fence
   AND j.lease_expires_at>clock_timestamp());
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
END $$;

CREATE FUNCTION public.jobix_export_cost_settle(operation uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.export_cost_budget_policy; r public.export_cost_reservations;
 j public.export_jobs; actual bigint; total_runtime bigint; output_bytes bigint;
 storage_ops bigint; attempts integer; unfinished integer; sent_upload boolean;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 SELECT * INTO r FROM public.export_cost_reservations
  WHERE public.export_cost_reservations.operation=jobix_export_cost_settle.operation FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 IF r.state<>'HELD' THEN RETURN r.state; END IF;
 SELECT * INTO j FROM public.export_jobs WHERE id=r.operation FOR UPDATE;
 IF NOT FOUND OR j.state NOT IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED') THEN
  RETURN 'PENDING';
 END IF;
 SELECT EXISTS(SELECT FROM public.export_upload_flights f
  WHERE f.operation=r.operation AND f.state='SENT') INTO sent_upload;
 IF sent_upload THEN RETURN 'AMBIGUOUS'; END IF;
 SELECT count(*),count(*) FILTER(WHERE finished_at IS NULL),
  coalesce(sum(runtime_ms),0),coalesce(max(pdf_bytes),0),coalesce(sum(storage_operations),0)
 INTO attempts,unfinished,total_runtime,output_bytes,storage_ops
 FROM public.export_cost_attempts a WHERE a.operation=r.operation;
 -- Migration cannot reconstruct pre-cost attempts. Keep their full conservative hold.
 IF r.unknown_prior_attempts>0 OR r.model_version<>p.model_version THEN
  UPDATE public.export_cost_reservations SET state='SETTLED',
   settled_microusd=CASE WHEN r.model_version<>p.model_version
     THEN greatest(r.reserved_microusd,p.budget_microusd) ELSE r.reserved_microusd END,
   settled_at=clock_timestamp(),
   resolution_kind='conservative_upper_bound'
  WHERE public.export_cost_reservations.operation=r.operation;
  IF r.model_version<>p.model_version THEN
   UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp()
   WHERE singleton;
  END IF;
  RETURN 'SETTLED';
 END IF;
 -- An interrupted attempt is ambiguous; do not release its reservation by timeout.
 IF unfinished>0 THEN RETURN 'AMBIGUOUS'; END IF;
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
 UPDATE public.export_cost_reservations SET state=CASE WHEN actual=0 THEN 'RELEASED' ELSE 'SETTLED' END,
  settled_microusd=actual,settled_at=clock_timestamp(),
  resolution_kind=CASE WHEN actual=0 THEN 'definitive_no_work' ELSE 'measured_usage' END
 WHERE public.export_cost_reservations.operation=r.operation;
 IF actual>r.reserved_microusd THEN
  UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp()
   WHERE singleton;
 END IF;
 RETURN CASE WHEN actual=0 THEN 'RELEASED' ELSE 'SETTLED' END;
END $$;

-- Owner-only path for a terminal ambiguous job after independent evidence has
-- established a per-export cost or justified charging its full reservation.
CREATE FUNCTION public.jobix_export_cost_resolve(operation uuid,settled_microusd bigint,
 resolution_kind text,resolution_ref text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.export_cost_budget_policy; r public.export_cost_reservations;
 j public.export_jobs; sent_upload boolean;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_UNAVAILABLE'; END IF;
 SELECT * INTO r FROM public.export_cost_reservations
  WHERE public.export_cost_reservations.operation=jobix_export_cost_resolve.operation FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 IF r.state<>'HELD' THEN RETURN r.state; END IF;
 SELECT * INTO j FROM public.export_jobs WHERE id=r.operation FOR UPDATE;
 IF NOT FOUND OR j.state NOT IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED')
 THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
 SELECT EXISTS(SELECT FROM public.export_upload_flights f
  WHERE f.operation=r.operation AND f.state='SENT') INTO sent_upload;
 IF sent_upload THEN RAISE EXCEPTION 'CLEANUP_UNVERIFIED'; END IF;
 IF settled_microusd IS NULL OR settled_microusd<0 OR resolution_ref IS NULL
 OR length(resolution_ref) NOT BETWEEN 1 AND 200
 OR resolution_kind NOT IN ('provider_reconciled','conservative_upper_bound','definitive_no_work')
 OR (resolution_kind='conservative_upper_bound' AND settled_microusd<r.reserved_microusd)
 OR (resolution_kind='definitive_no_work' AND
   (settled_microusd<>0 OR EXISTS(SELECT FROM public.export_cost_attempts a
    WHERE a.operation=r.operation))) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
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

CREATE FUNCTION public.jobix_export_cost_reconcile() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item record; changed integer:=0; result text;
BEGIN
 FOR item IN SELECT r.operation FROM public.export_cost_reservations r
  JOIN public.export_jobs j ON j.id=r.operation
  WHERE r.state='HELD' AND j.state IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED')
  ORDER BY r.admitted_at LIMIT 100
 LOOP
  result:=public.jobix_export_cost_settle(item.operation);
  IF result IN ('SETTLED','RELEASED') THEN changed:=changed+1; END IF;
 END LOOP;
 RETURN changed;
END $$;

CREATE FUNCTION public.jobix_export_cost_observe(provider text,service text,
 window_start timestamptz,window_end timestamptz,observed_microusd bigint,source_ref text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE modeled bigint;
BEGIN
 IF provider IS NULL OR provider !~ '^[a-z0-9_-]{1,40}$'
 OR service IS NULL OR service !~ '^[a-z0-9_-]{1,60}$'
 OR window_start IS NULL OR window_end IS NULL OR window_end<=window_start
 OR observed_microusd IS NULL OR observed_microusd<0
 OR source_ref IS NULL OR length(source_ref) NOT BETWEEN 1 AND 200 THEN
  RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 SELECT coalesce(sum(CASE WHEN r.state='HELD' THEN r.reserved_microusd
   ELSE r.settled_microusd END),0) INTO modeled
 FROM public.export_cost_reservations r
 WHERE r.admitted_at>=window_start AND r.admitted_at<window_end
 AND r.state IN ('HELD','SETTLED');
 INSERT INTO public.export_cost_provider_observations(provider,service,window_start,window_end,
  observed_microusd,modeled_export_microusd,source_ref)
 VALUES(jobix_export_cost_observe.provider,jobix_export_cost_observe.service,
  jobix_export_cost_observe.window_start,jobix_export_cost_observe.window_end,
  jobix_export_cost_observe.observed_microusd,modeled,jobix_export_cost_observe.source_ref)
 ON CONFLICT ON CONSTRAINT export_cost_provider_observations_pkey DO UPDATE SET
  observed_microusd=excluded.observed_microusd,
  modeled_export_microusd=excluded.modeled_export_microusd,
  source_ref=excluded.source_ref,observed_at=clock_timestamp();
 -- Observation rows are audit-only and never participate in admission sums.
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_cost_attempt_start(uuid,uuid),
 public.jobix_export_cost_attempt_finish(uuid,uuid,bigint,bigint,integer),
 public.jobix_export_cost_settle(uuid),public.jobix_export_cost_reconcile(),
 public.jobix_export_cost_resolve(uuid,bigint,text,text),
 public.jobix_export_cost_observe(text,text,timestamptz,timestamptz,bigint,text)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;
GRANT EXECUTE ON FUNCTION public.jobix_export_cost_attempt_start(uuid,uuid),
 public.jobix_export_cost_attempt_finish(uuid,uuid,bigint,bigint,integer),
 public.jobix_export_cost_settle(uuid),public.jobix_export_cost_reconcile()
 TO jobix_export_worker;

-- A migration-time active job has unknown prior runtime. Reserve the full
-- configured budget for it; new admission remains closed until the cost model
-- and pre-migration window are validated.
INSERT INTO public.export_cost_reservations(operation,admitted_at,reserved_microusd,
 model_version,max_pdf_bytes,unknown_prior_attempts)
SELECT j.id,j.created_at,p.budget_microusd,p.model_version,p.max_pdf_bytes,j.attempt_count
FROM public.export_jobs j CROSS JOIN public.export_cost_budget_policy p
WHERE j.state IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE')
AND p.singleton
ON CONFLICT(operation) DO NOTHING;

CREATE OR REPLACE FUNCTION public.jobix_export_create(actor uuid,command uuid,request_id uuid,
 profile uuid,profile_version bigint,config_version bigint,source_hash text,
 document_hash text,request_hash text,html text,bundle text,again uuid DEFAULT NULL,
 asset_manifest jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE replay jsonb; input jsonb; source jsonb; operation uuid:=gen_random_uuid();
 snapshot uuid; r jsonb; balance jsonb; ack jsonb; fonts jsonb;
 quota_at timestamptz; retry_seconds integer; legacy_until timestamptz; legacy_seconds integer;
 cost_hold bigint;
BEGIN
 replay:=public.jobix_export_replay(actor,command,request_hash);
 IF replay IS NOT NULL THEN RETURN replay; END IF;
 IF NOT EXISTS(SELECT FROM public.export_settings WHERE enabled AND deletion_policy_approved) THEN
  RAISE EXCEPTION 'EXPORT_NOT_READY';
 END IF;
 IF command IS NULL OR request_id IS NULL OR request_hash !~ '^[0-9a-f]{64}$'
 OR request_hash IS NULL OR bundle IS DISTINCT FROM 'jobix-resume-export-1'
 OR document_hash IS DISTINCT FROM encode(sha256(convert_to(html,'UTF8')),'hex') THEN
  RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 IF again IS NOT NULL AND NOT EXISTS(SELECT FROM public.export_jobs WHERE id=again
 AND user_id=actor AND profile_id=profile) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 input:=public.jobix_export_source(actor,profile); source:=input->'source';
 IF source_hash IS DISTINCT FROM input->>'source_sha256'
 OR profile_version IS DISTINCT FROM (source#>>'{profile,profile_version}')::bigint
 OR config_version IS DISTINCT FROM (source#>>'{configuration,version}')::bigint THEN
  RAISE EXCEPTION 'VERSION_CONFLICT';
 END IF;
 IF NOT public.jobix_export_valid(source) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 fonts:=public.jobix_export_fonts(html);
 IF jsonb_typeof(asset_manifest) IS DISTINCT FROM 'object'
 OR octet_length(asset_manifest::text)>32000
 OR (asset_manifest ? 'font_checksums' AND asset_manifest->'font_checksums' IS DISTINCT FROM fonts)
 OR (asset_manifest ? 'bundle' AND asset_manifest->>'bundle' IS DISTINCT FROM bundle) THEN
  RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 asset_manifest:=asset_manifest||jsonb_build_object('font_checksums',fonts,'bundle',bundle,
  'model_version',2,'template_version',2,'render_config_version','export-v1');
 IF EXISTS(SELECT FROM public.export_jobs WHERE user_id=actor AND profile_id=profile
  AND state IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE')) THEN
  RAISE EXCEPTION 'EXPORT_IN_PROGRESS';
 END IF;
 SELECT max(hold_until) INTO legacy_until FROM public.export_admission_legacy_holds
  WHERE user_id=actor AND hold_until>clock_timestamp();
 IF legacy_until IS NOT NULL THEN
  legacy_seconds:=greatest(1,ceil(extract(epoch FROM legacy_until-clock_timestamp()))::integer);
  RAISE EXCEPTION USING MESSAGE='RATE_LIMITED',DETAIL=legacy_seconds::text;
 END IF;
 quota_at:=clock_timestamp();
 retry_seconds:=public.jobix_export_admission_retry_seconds(actor,quota_at);
 IF retry_seconds>0 THEN
  RAISE EXCEPTION USING MESSAGE='RATE_LIMITED',DETAIL=retry_seconds::text;
 END IF;
 -- Locks the global policy row and commits the hold with the job/credits below.
 cost_hold:=public.jobix_export_cost_reserve(operation);
 BEGIN r:=public.reserve_resume_credits(actor,operation);
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='INSUFFICIENT_CREDITS' THEN RAISE EXCEPTION 'CREDIT_INSUFFICIENT'; END IF;
  RAISE;
 END;
 INSERT INTO public.export_snapshots(user_id,profile_id,source,source_sha256,canonical_html,
  document_sha256,bundle,asset_manifest)
 VALUES(actor,profile,source,source_hash,html,document_hash,bundle,asset_manifest)
 RETURNING id INTO snapshot;
 SELECT jsonb_build_object('finalized',finalized_balance,'reserved',reserved_balance,
  'available',finalized_balance-reserved_balance,'version',version) INTO balance
 FROM public.credit_accounts WHERE user_id=actor;
 ack:=jsonb_build_object('request_id',request_id,'operation_id',operation,'state','QUEUED',
  'authoritative_version',profile_version,'error',NULL,'data',jsonb_build_object(
  'export_id',operation,'snapshot_id',snapshot,'document_sha256',document_hash,
  'source_version',profile_version,'configuration_version',config_version,
  'reservation_id',r->'id','reserved_credits',2,'balance',balance));
 INSERT INTO public.export_jobs(id,user_id,profile_id,snapshot_id,reservation_id,idempotency_key,
  request_sha256,acknowledgement,deadline)
 VALUES(operation,actor,profile,snapshot,(r->>'id')::uuid,command,request_hash,ack,(r->>'expires_at')::timestamptz);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,operation_id,response_state)
 VALUES(actor,'export.create',command,request_hash,operation,ack);
 INSERT INTO public.export_admission_events(user_id,accepted_at) VALUES(actor,clock_timestamp());
 RETURN ack;
END $$;

CREATE OR REPLACE FUNCTION public.jobix_export_claim(capacity integer DEFAULT 2) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM public.export_settings WHERE enabled AND deletion_policy_approved) THEN RETURN '[]'; END IF;
 UPDATE public.export_jobs SET state='QUEUED',updated_at=now()
 WHERE id IN (SELECT q.id FROM public.export_jobs q
 JOIN public.users u ON u.id=q.user_id
 JOIN public.career_profiles p ON p.id=q.profile_id AND p.user_id=q.user_id
 WHERE q.state='RETRYABLE_FAILURE' AND q.next_attempt_at<=now() AND q.deadline>now()
 AND q.attempt_count<3 AND u.status='ACTIVE' AND p.status='ACTIVE'
 ORDER BY q.created_at,q.id FOR UPDATE OF q SKIP LOCKED
 LIMIT greatest(0,least(capacity,2)));
 WITH claimed AS (
 UPDATE public.export_jobs j SET state='CLAIMED',lease_token=gen_random_uuid(),
 lease_expires_at=least(deadline,now()+interval '5 minutes'),attempt_count=attempt_count+1,updated_at=now()
 WHERE j.id IN (SELECT q.id FROM public.export_jobs q
 JOIN public.users u ON u.id=q.user_id
 JOIN public.career_profiles p ON p.id=q.profile_id AND p.user_id=q.user_id
 WHERE u.status='ACTIVE' AND p.status='ACTIVE' AND q.state='QUEUED'
 AND q.next_attempt_at<=now() AND q.deadline>now() AND q.attempt_count<3
 ORDER BY q.created_at,q.id FOR UPDATE OF q SKIP LOCKED LIMIT greatest(0,least(capacity,2)))
 RETURNING j.*)
 SELECT coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('snapshot',to_jsonb(s),
  'max_pdf_bytes',(SELECT cr.max_pdf_bytes FROM public.export_cost_reservations cr
    WHERE cr.operation=c.id))),'[]')
 INTO result FROM claimed c JOIN public.export_snapshots s ON s.id=c.snapshot_id;
 RETURN result;
END $$;

REVOKE ALL ON FUNCTION public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid,jsonb),
 public.jobix_export_claim(integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid,jsonb)
 TO jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_claim(integer) TO jobix_export_worker;

COMMIT;
