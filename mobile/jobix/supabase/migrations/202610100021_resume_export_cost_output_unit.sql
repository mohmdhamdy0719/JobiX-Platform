-- The output rate is already priced for the full seven-day retention window.
-- Keep the migration additive so applied migration checksums remain immutable.
BEGIN;

DO $unit_guard$
DECLARE p public.export_cost_budget_policy; gates public.export_settings;
 policy_found boolean; gates_found boolean;
BEGIN
 SELECT * INTO p FROM public.export_cost_budget_policy WHERE singleton FOR UPDATE;
 policy_found:=FOUND;
 SELECT * INTO gates FROM public.export_settings WHERE singleton FOR UPDATE;
 gates_found:=FOUND;
 IF NOT policy_found OR NOT gates_found OR p.accounting_ready OR p.model_version<>1
 OR p.shared_cost_reserve_microusd IS NOT NULL
 OR p.runtime_cost_microusd_per_second IS NOT NULL
 OR p.output_cost_microusd_per_gib_7d IS NOT NULL
 OR p.storage_operation_cost_microusd IS NOT NULL
 OR p.per_export_overhead_microusd IS NOT NULL
 OR gates.enabled
 OR EXISTS(SELECT FROM public.export_jobs WHERE state IN
      ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE','DELETION_PENDING'))
 OR EXISTS(SELECT FROM public.export_upload_flights WHERE state<>'SETTLED')
 OR EXISTS(SELECT FROM public.export_cost_reservations WHERE state='HELD') THEN
  RAISE EXCEPTION 'COST_OUTPUT_UNIT_PRECONDITION_FAILED';
 END IF;
END
$unit_guard$;

CREATE OR REPLACE FUNCTION public.jobix_export_cost_estimate(
 runtime_ms bigint,pdf_bytes bigint,storage_operations integer)
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
  +ceil(pdf_bytes::numeric*p.output_cost_microusd_per_gib_7d/1073741824)
  +storage_operations::numeric*p.storage_operation_cost_microusd;
 IF estimate<0 OR estimate>9223372036854775807::numeric THEN RETURN NULL; END IF;
 RETURN ceil(estimate)::bigint;
END $$;

REVOKE ALL ON FUNCTION public.jobix_export_cost_estimate(bigint,bigint,integer)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;

COMMENT ON COLUMN public.export_cost_budget_policy.shared_cost_reserve_microusd IS
 'Fixed micro-USD held back from admission capacity for shared or unattributed costs; not a per-export settlement charge.';
COMMENT ON COLUMN public.export_cost_budget_policy.runtime_cost_microusd_per_second IS
 'Micro-USD per measured Worker runtime second; estimate contribution is ceil(runtime_ms * rate / 1000).';
COMMENT ON COLUMN public.export_cost_budget_policy.output_cost_microusd_per_gib_7d IS
 'Micro-USD per GiB of PDF at-rest output for the full seven-day retention window; estimate applies the rate once to output bytes and excludes download egress.';
COMMENT ON COLUMN public.export_cost_budget_policy.storage_operation_cost_microusd IS
 'Micro-USD per metered storage operation; estimate contribution is operation count multiplied by this rate.';
COMMENT ON COLUMN public.export_cost_budget_policy.per_export_overhead_microusd IS
 'Fixed micro-USD per export for costs not represented by runtime, retained output bytes, or storage-operation counts.';

COMMIT;
