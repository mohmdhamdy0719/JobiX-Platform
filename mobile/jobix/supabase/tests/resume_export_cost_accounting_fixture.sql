-- Disposable PostgreSQL only. Synthetic rates enable the following SQL
-- admission/recovery/deletion tests; this is not a Development configuration.
BEGIN;
UPDATE public.export_cost_budget_policy
SET budget_microusd=10000000,
 shared_cost_reserve_microusd=0,
 runtime_cost_microusd_per_second=0,
 output_cost_microusd_per_gib_7d=0,
 storage_operation_cost_microusd=0,
 per_export_overhead_microusd=1,
 accounting_ready=true,
 updated_at=clock_timestamp()
WHERE singleton;
COMMIT;
