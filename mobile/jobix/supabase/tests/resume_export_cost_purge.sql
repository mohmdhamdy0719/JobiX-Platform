-- Synthetic disposable PostgreSQL only; never run on Supabase.
BEGIN;
DO $test$
DECLARE rejected boolean:=false; used_before numeric; used_after numeric;
 used_once numeric; used_twice numeric; settled_once bigint; settled_twice bigint;
 settled_at_once timestamptz; settled_at_twice timestamptz; result text;
BEGIN
  IF EXISTS(SELECT FROM public.export_admission_legacy_holds)
  THEN RAISE EXCEPTION 'migration fabricated legacy purge evidence'; END IF;

 IF NOT EXISTS(SELECT FROM public.export_cost_reservations r
  WHERE r.operation='93000000-0000-0000-0000-000000000001'
  AND r.state='HELD' AND r.job_purged_at IS NULL AND r.orphan_discovered_at IS NOT NULL)
 THEN RAISE EXCEPTION 'legacy missing-job hold was not discovered without invented purge evidence'; END IF;

 -- Recovery sees the missing-job hold, but cannot release it without evidence.
 PERFORM public.jobix_export_cost_reconcile();
 IF NOT EXISTS(SELECT FROM public.export_cost_reservations r
  WHERE r.operation='93000000-0000-0000-0000-000000000001' AND r.state='HELD')
 THEN RAISE EXCEPTION 'legacy ambiguous hold was silently released'; END IF;
 BEGIN
  PERFORM public.jobix_export_cost_resolve('93000000-0000-0000-0000-000000000001',
   0,'definitive_no_work','local-fixture-no-work');
 EXCEPTION WHEN raise_exception THEN rejected:=SQLERRM='VALIDATION_FAILED'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'legacy orphan was incorrectly accepted as definitive no-work'; END IF;

 SELECT p.shared_cost_reserve_microusd+coalesce(sum(CASE
   WHEN r.state='HELD' THEN r.reserved_microusd
   WHEN r.state='SETTLED' AND r.admitted_at>clock_timestamp()-p.rolling_window
    THEN r.settled_microusd ELSE 0 END),0)
 INTO used_before
 FROM public.export_cost_budget_policy p
 LEFT JOIN public.export_cost_reservations r ON r.state<>'RELEASED'
 WHERE p.singleton GROUP BY p.shared_cost_reserve_microusd,p.rolling_window;
 UPDATE public.export_cost_budget_policy SET budget_microusd=used_before WHERE singleton;

 rejected:=false;
 BEGIN
  PERFORM public.jobix_export_cost_reserve('93000000-0000-0000-0000-000000000002');
 EXCEPTION WHEN raise_exception THEN rejected:=SQLERRM='SERVICE_UNAVAILABLE'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'orphan hold did not count against the admission budget'; END IF;

 IF public.jobix_export_cost_resolve('93000000-0000-0000-0000-000000000001',
  100,'provider_reconciled','local-fixture-provider-check')<>'SETTLED'
 THEN RAISE EXCEPTION 'legacy orphan could not be resolved without its job'; END IF;
 SELECT p.shared_cost_reserve_microusd+coalesce(sum(CASE
   WHEN r.state='HELD' THEN r.reserved_microusd
   WHEN r.state='SETTLED' AND r.admitted_at>clock_timestamp()-p.rolling_window
    THEN r.settled_microusd ELSE 0 END),0)
 INTO used_after
 FROM public.export_cost_budget_policy p
 LEFT JOIN public.export_cost_reservations r ON r.state<>'RELEASED'
 WHERE p.singleton GROUP BY p.shared_cost_reserve_microusd,p.rolling_window;
 IF used_after<>used_before THEN RAISE EXCEPTION 'settlement double-counted or discarded the orphan hold'; END IF;

  -- A verified-purge marker lets recovery settle a finished attempt after its job row is gone.
  INSERT INTO public.export_cost_reservations(operation,admitted_at,reserved_microusd,
   model_version,max_pdf_bytes,job_purged_at)
  VALUES('93000000-0000-0000-0000-000000000005',clock_timestamp(),100,1,10485760,clock_timestamp());
  INSERT INTO public.export_cost_attempts(operation,fence,finished_at,runtime_ms,pdf_bytes,storage_operations)
  VALUES('93000000-0000-0000-0000-000000000005',gen_random_uuid(),
   clock_timestamp(),0,0,0);
  result:=public.jobix_export_cost_settle('93000000-0000-0000-0000-000000000005');
  IF result<>'SETTLED' THEN RAISE EXCEPTION 'known post-purge usage was not settled'; END IF;
  SELECT r.settled_microusd,r.settled_at INTO settled_once,settled_at_once
  FROM public.export_cost_reservations r
  WHERE r.operation='93000000-0000-0000-0000-000000000005' AND r.state='SETTLED';
  IF settled_once<>1 OR settled_at_once IS NULL THEN
   RAISE EXCEPTION 'known post-purge usage has an unexpected settled amount';
  END IF;
  SELECT p.shared_cost_reserve_microusd+coalesce(sum(CASE
    WHEN r.state='HELD' THEN r.reserved_microusd
    WHEN r.state='SETTLED' AND r.admitted_at>clock_timestamp()-p.rolling_window
     THEN r.settled_microusd ELSE 0 END),0)
  INTO used_once
  FROM public.export_cost_budget_policy p
  LEFT JOIN public.export_cost_reservations r ON r.state<>'RELEASED'
  WHERE p.singleton GROUP BY p.shared_cost_reserve_microusd,p.rolling_window;

  result:=public.jobix_export_cost_settle('93000000-0000-0000-0000-000000000005');
  SELECT r.settled_microusd,r.settled_at INTO settled_twice,settled_at_twice
  FROM public.export_cost_reservations r
  WHERE r.operation='93000000-0000-0000-0000-000000000005' AND r.state='SETTLED';
  SELECT p.shared_cost_reserve_microusd+coalesce(sum(CASE
    WHEN r.state='HELD' THEN r.reserved_microusd
    WHEN r.state='SETTLED' AND r.admitted_at>clock_timestamp()-p.rolling_window
     THEN r.settled_microusd ELSE 0 END),0)
  INTO used_twice
  FROM public.export_cost_budget_policy p
  LEFT JOIN public.export_cost_reservations r ON r.state<>'RELEASED'
  WHERE p.singleton GROUP BY p.shared_cost_reserve_microusd,p.rolling_window;
  IF result<>'SETTLED' OR settled_twice<>settled_once
   OR settled_at_twice<>settled_at_once OR used_twice<>used_once
  THEN RAISE EXCEPTION 'repeated settlement changed the settled reservation or double-counted cost'; END IF;
  IF used_once<>used_after+1 THEN RAISE EXCEPTION 'settled reservation was not counted exactly once'; END IF;

  UPDATE public.export_cost_budget_policy SET budget_microusd=used_twice+1 WHERE singleton;
 IF public.jobix_export_cost_reserve('93000000-0000-0000-0000-000000000003')<>1
 THEN RAISE EXCEPTION 'resolved reservation was counted more than once'; END IF;
  DELETE FROM public.export_cost_attempts
   WHERE operation='93000000-0000-0000-0000-000000000005';
  DELETE FROM public.export_cost_reservations
   WHERE operation='93000000-0000-0000-0000-000000000005';
 DELETE FROM public.export_cost_reservations
  WHERE operation='93000000-0000-0000-0000-000000000003';
 DELETE FROM public.export_cost_reservations
  WHERE operation='93000000-0000-0000-0000-000000000001';
 UPDATE public.export_cost_budget_policy SET budget_microusd=10000000 WHERE singleton;
END $test$;
COMMIT;
