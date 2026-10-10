-- Disposable SQL fixture only; this transaction rolls every synthetic setting back.
BEGIN;
UPDATE public.export_cost_budget_policy
SET accounting_ready=true,shared_cost_reserve_microusd=0,
 runtime_cost_microusd_per_second=2,
 output_cost_microusd_per_gib_7d=1024,
 storage_operation_cost_microusd=5,
 per_export_overhead_microusd=7
WHERE singleton;

DO $unit_test$
BEGIN
 IF public.jobix_export_cost_estimate(1001,1048576,2)<>21 THEN
  RAISE EXCEPTION 'seven-day output rate or cost input units are incorrect';
 END IF;
END
$unit_test$;
ROLLBACK;
