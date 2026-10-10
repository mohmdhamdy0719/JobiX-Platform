-- Local implementation only. No live database has been changed.
BEGIN;

-- Preserve accepted-export history across profile purges without retaining a
-- profile ID, resume content, request, or export-job reference. Account
-- deletion still removes these rows through the user foreign key.
CREATE TABLE public.export_admission_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
 accepted_at timestamptz NOT NULL
);
ALTER TABLE public.export_admission_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.export_admission_events FROM PUBLIC,anon,authenticated,service_role,
 jobix_export_gateway,jobix_export_worker;

INSERT INTO public.export_admission_events(user_id,accepted_at)
SELECT user_id,created_at FROM public.export_jobs
WHERE created_at>clock_timestamp()-interval '7 days';

CREATE INDEX export_admission_events_owner_time
 ON public.export_admission_events(user_id,accepted_at DESC);

-- Used only by the SECURITY DEFINER create function. Detail returned to the
-- caller is an integer seconds count, not stored data or database diagnostics.
CREATE FUNCTION public.jobix_export_admission_retry_seconds(actor uuid,at_time timestamptz)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH windows(duration,maximum) AS (
  VALUES(interval '5 minutes',1),(interval '1 hour',3),
        (interval '24 hours',5),(interval '7 days',10)
 ), ranked AS (
  SELECT w.duration,w.maximum,e.accepted_at,
   row_number() OVER(PARTITION BY w.duration ORDER BY e.accepted_at) AS position,
   count(*) OVER(PARTITION BY w.duration) AS total
  FROM windows w JOIN public.export_admission_events e
   ON e.user_id=actor AND e.accepted_at>at_time-w.duration
 ), release AS (
  SELECT max(accepted_at+duration) AS at_time
  FROM ranked WHERE total>=maximum AND position=total-maximum+1
 )
 SELECT CASE WHEN at_time IS NULL THEN 0
  ELSE greatest(1,ceil(extract(epoch FROM at_time-jobix_export_admission_retry_seconds.at_time))::integer)
  END FROM release
$$;
REVOKE ALL ON FUNCTION public.jobix_export_admission_retry_seconds(uuid,timestamptz)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;

CREATE OR REPLACE FUNCTION public.jobix_export_create(actor uuid,command uuid,request_id uuid,
 profile uuid,profile_version bigint,config_version bigint,source_hash text,
 document_hash text,request_hash text,html text,bundle text,again uuid DEFAULT NULL,
 asset_manifest jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE replay jsonb; input jsonb; source jsonb; operation uuid:=gen_random_uuid();
 snapshot uuid; r jsonb; balance jsonb; ack jsonb; fonts jsonb;
 quota_at timestamptz; retry_seconds integer;
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

 quota_at:=clock_timestamp();
 retry_seconds:=public.jobix_export_admission_retry_seconds(actor,quota_at);
 IF retry_seconds>0 THEN
  RAISE EXCEPTION USING MESSAGE='RATE_LIMITED',DETAIL=retry_seconds::text;
 END IF;

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
 INSERT INTO public.export_admission_events(user_id,accepted_at)
 VALUES(actor,clock_timestamp());
 RETURN ack;
END $$;

-- Existing jobs remain the authoritative historical/retention records.
-- Prune only quota rows whose entire seven-day window has elapsed.
CREATE OR REPLACE FUNCTION public.jobix_export_retention() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 DELETE FROM public.export_admission_events
 WHERE accepted_at<=clock_timestamp()-interval '7 days';
 UPDATE public.export_jobs SET state='EXPIRED',updated_at=now()
 WHERE state='COMPLETED' AND expires_at<=now();
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'path',object_path,
 'generation',object_generation)) FROM public.export_jobs
 WHERE state='EXPIRED' AND expires_at<=now() AND object_path IS NOT NULL
 AND object_cleanup_verified_at IS NULL),'[]');
END $$;
COMMIT;
