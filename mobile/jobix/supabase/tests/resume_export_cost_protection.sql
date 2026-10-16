BEGIN;

DELETE FROM public.export_cost_attempts;
DELETE FROM public.export_cost_reservations;
DELETE FROM public.export_cost_provider_observations;
UPDATE public.export_cost_budget_policy SET budget_microusd=10000000,
 shared_cost_reserve_microusd=NULL,runtime_cost_microusd_per_second=NULL,
 output_cost_microusd_per_gib_7d=NULL,storage_operation_cost_microusd=NULL,
 per_export_overhead_microusd=NULL,accounting_ready=false,updated_at=clock_timestamp()
WHERE singleton;

DO $$
DECLARE rejected boolean:=false;
BEGIN
 BEGIN
  PERFORM public.jobix_export_cost_reserve('91000000-0000-0000-0000-000000000001');
 EXCEPTION WHEN raise_exception THEN rejected:=SQLERRM='SERVICE_UNAVAILABLE'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'unconfigured cost accounting admitted work'; END IF;
END $$;

-- Synthetic rates are test fixtures only; no live rates or billing data are read.
UPDATE public.export_cost_budget_policy SET accounting_ready=true,
 shared_cost_reserve_microusd=2000000,runtime_cost_microusd_per_second=0,
 output_cost_microusd_per_gib_7d=0,storage_operation_cost_microusd=0,
 per_export_overhead_microusd=4000000,updated_at=clock_timestamp()
WHERE singleton;

DO $$
DECLARE rejected boolean:=false; used numeric;
BEGIN
 IF public.jobix_export_cost_estimate(1800000,10485760,24)<>4000000 THEN
  RAISE EXCEPTION 'maximum reservation estimate is not bounded by configured model';
 END IF;
 PERFORM public.jobix_export_cost_reserve('91000000-0000-0000-0000-000000000011');
 PERFORM public.jobix_export_cost_reserve('91000000-0000-0000-0000-000000000012');
 SELECT shared_cost_reserve_microusd+sum(reserved_microusd) INTO used
 FROM public.export_cost_budget_policy p CROSS JOIN public.export_cost_reservations r
 WHERE p.singleton AND r.state='HELD' GROUP BY p.shared_cost_reserve_microusd;
 IF used<>10000000 THEN RAISE EXCEPTION 'reservation ledger did not account for full budget'; END IF;
 BEGIN
  PERFORM public.jobix_export_cost_reserve('91000000-0000-0000-0000-000000000013');
 EXCEPTION WHEN raise_exception THEN rejected:=SQLERRM='SERVICE_UNAVAILABLE'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'reservation exceeded remaining budget'; END IF;
END $$;

-- Provider totals are stored for comparison, not summed a second time into admission.
SELECT public.jobix_export_cost_observe('gcp','cloud_run',
 clock_timestamp()-interval '7 days',clock_timestamp(),15000000,'local-disposable-fixture');
DO $$
DECLARE rejected boolean:=false; observed_model bigint;
BEGIN
 SELECT modeled_export_microusd INTO observed_model
 FROM public.export_cost_provider_observations
 WHERE provider='gcp' AND service='cloud_run';
 IF observed_model<>8000000 THEN RAISE EXCEPTION 'provider observation missed modelled export usage'; END IF;
 BEGIN
  PERFORM public.jobix_export_cost_reserve('91000000-0000-0000-0000-000000000014');
 EXCEPTION WHEN raise_exception THEN rejected:=SQLERRM='SERVICE_UNAVAILABLE'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'provider total was double-counted or bypassed the budget'; END IF;
END $$;

DO $$
BEGIN
 IF has_table_privilege('authenticated','public.export_cost_reservations','SELECT')
 OR has_table_privilege('authenticated','public.export_cost_budget_policy','SELECT')
 OR has_table_privilege('jobix_export_gateway','public.export_cost_reservations','SELECT')
 OR has_table_privilege('jobix_export_worker','public.export_cost_reservations','SELECT') THEN
  RAISE EXCEPTION 'cost ledger is readable by application roles';
 END IF;
END $$;

-- Leave a tiny synthetic per-export cost for later disposable regressions.
-- This hold is intentionally seeded before migration 020 so its real discovery
-- update can observe it; the purge test checks that migration invented no
-- separate legacy admission evidence.
DELETE FROM public.export_cost_attempts;
DELETE FROM public.export_cost_reservations;
DELETE FROM public.export_cost_provider_observations;
UPDATE public.export_cost_budget_policy SET accounting_ready=true,
 shared_cost_reserve_microusd=0,runtime_cost_microusd_per_second=0,
 output_cost_microusd_per_gib_7d=0,storage_operation_cost_microusd=0,
 per_export_overhead_microusd=1,updated_at=clock_timestamp()
WHERE singleton;
-- Simulate a held reservation left without its job by the pre-020 purge path.
INSERT INTO public.export_cost_reservations(operation,admitted_at,reserved_microusd,
 model_version,max_pdf_bytes)
VALUES('93000000-0000-0000-0000-000000000001',clock_timestamp(),100,1,10485760);
COMMIT;
