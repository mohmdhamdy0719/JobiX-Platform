-- Fixtures and helper functions from resume_export_recovery.sql, same connection.
DO $$
<<resume_export_deletion>>
DECLARE actor uuid:=pg_temp.fixture_actor(); other_actor uuid:=pg_temp.fixture_actor();
 profile uuid; ack jsonb; operation uuid; claim jsonb; fence uuid; result jsonb;
 measured_actor uuid; measured_operation uuid; ambiguous_actor uuid;
 ambiguous_operation uuid; extra_operation uuid:='93000000-0000-0000-0000-000000000004';
 used_before numeric; used_after numeric; rejected boolean;
BEGIN
 UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true;
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=actor;
 ack:=pg_temp.fixture_create(actor);operation:=(ack->>'operation_id')::uuid;
 claim:=public.jobix_export_claim(1)->0;fence:=(claim->>'lease_token')::uuid;
 PERFORM public.jobix_export_stage(operation,fence,'GENERATING');
 PERFORM public.jobix_export_stage(operation,fence,'UPLOADING');
 PERFORM public.jobix_export_upload_begin(operation,fence);
 UPDATE public.export_jobs SET deadline=now()-interval '1 second' WHERE id=operation;
 UPDATE public.export_settings SET enabled=false,deletion_policy_approved=false;
 ASSERT public.jobix_export_recover()=1;
 ASSERT (SELECT state FROM public.export_jobs WHERE id=operation)='FAILED';
 ASSERT (SELECT state FROM public.credit_reservations WHERE id=(ack#>>'{data,reservation_id}')::uuid)='RELEASED';
 ASSERT NOT EXISTS(SELECT FROM public.credit_transactions WHERE user_id=actor AND delta=-2);
 ASSERT (SELECT state FROM public.export_upload_flights f WHERE f.operation=resume_export_deletion.operation)='SENT';
 ASSERT public.jobix_export_finish(operation,fence,NULL,false)='FAILED';
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_stage(%L,%L,%L)',operation,fence,'UPLOADING'),'STALE_LEASE');
 PERFORM pg_temp.must_fail(format('DELETE FROM public.career_profiles WHERE id=%L',profile),'DELETION_PENDING');
 UPDATE public.career_profiles SET status='DELETING' WHERE id=profile;
 ASSERT (SELECT lease_token IS NULL AND state='DELETION_PENDING' FROM public.export_jobs WHERE id=operation);
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=0;
 ASSERT NOT public.jobix_export_quiescent(actor,profile);
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_upload_begin(%L,%L)',operation,fence),'STALE_LEASE');
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_purge(%L,%L,true)',actor,profile),'CLEANUP_UNVERIFIED');
 -- Acknowledgement after invalidation settles the physical request, not Credits.
 PERFORM public.jobix_export_upload_settle(operation,fence,'7');
 PERFORM public.jobix_export_upload_settle(operation,fence,'7');
 ASSERT public.jobix_export_quiescent(actor,profile);
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_purge(%L,%L,false)',actor,profile),'CLEANUP_UNVERIFIED');
 result:=public.jobix_export_purge(actor,profile,true);
 ASSERT result->>'state'='EXPORT_DATA_REMOVED';
 ASSERT NOT EXISTS(SELECT FROM public.export_jobs WHERE user_id=actor);
 ASSERT NOT EXISTS(SELECT FROM public.export_snapshots WHERE user_id=actor);
 ASSERT NOT EXISTS(SELECT FROM public.export_upload_flights f WHERE f.operation=resume_export_deletion.operation);
 ASSERT NOT EXISTS(SELECT FROM public.credit_reservations WHERE user_id=actor);
 ASSERT NOT EXISTS(SELECT FROM public.idempotency_records WHERE operation_id=operation);
 ASSERT (SELECT state='SETTLED' AND settled_microusd=reserved_microusd
  AND resolution_kind='conservative_upper_bound'
  FROM public.export_cost_reservations r WHERE r.operation=resume_export_deletion.operation);
 ASSERT (SELECT finalized_balance FROM public.credit_accounts WHERE user_id=actor)=5;
 ASSERT EXISTS(SELECT FROM public.users WHERE id=actor);
 ASSERT EXISTS(SELECT FROM public.career_profiles WHERE user_id=other_actor);
 DELETE FROM public.career_profiles WHERE id=profile;

 -- A queued operation with no attempt or upload evidence is definitive no-work.
 UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true;
 actor:=pg_temp.fixture_actor();
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=actor;
 ack:=pg_temp.fixture_create(actor);operation:=(ack->>'operation_id')::uuid;
 UPDATE public.career_profiles SET status='DELETING' WHERE id=profile;
 ASSERT public.jobix_export_purge(actor,profile,true)->>'state'='EXPORT_DATA_REMOVED';
 ASSERT (SELECT state='RELEASED' AND settled_microusd=0
  AND resolution_kind='definitive_no_work'
  FROM public.export_cost_reservations r WHERE r.operation=resume_export_deletion.operation);

 -- Completed metering is settled before its job and upload metadata are purged.
 measured_actor:=pg_temp.fixture_actor();
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=measured_actor;
 ack:=pg_temp.fixture_create(measured_actor);
 measured_operation:=(ack->>'operation_id')::uuid;
 INSERT INTO public.export_cost_attempts(operation,fence,finished_at,runtime_ms,pdf_bytes,storage_operations)
 VALUES(measured_operation,gen_random_uuid(),clock_timestamp(),1000,200,1);
 UPDATE public.career_profiles SET status='DELETING' WHERE id=profile;
 ASSERT public.jobix_export_purge(measured_actor,profile,true)->>'state'='EXPORT_DATA_REMOVED';
 ASSERT (SELECT state='SETTLED' AND settled_microusd=1
  AND resolution_kind='measured_usage'
  FROM public.export_cost_reservations r WHERE r.operation=resume_export_deletion.measured_operation);
 ASSERT NOT EXISTS(SELECT FROM public.export_jobs WHERE id=measured_operation);

 -- Interrupted metering stays held after purge and can be reconciled without the job.
 ambiguous_actor:=pg_temp.fixture_actor();
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=ambiguous_actor;
 ack:=pg_temp.fixture_create(ambiguous_actor);
 ambiguous_operation:=(ack->>'operation_id')::uuid;
 INSERT INTO public.export_cost_attempts(operation,fence)
 VALUES(ambiguous_operation,gen_random_uuid());
 UPDATE public.career_profiles SET status='DELETING' WHERE id=profile;
 ASSERT public.jobix_export_purge(ambiguous_actor,profile,true)->>'state'='EXPORT_DATA_REMOVED';
 ASSERT NOT EXISTS(SELECT FROM public.export_jobs WHERE id=ambiguous_operation);
 ASSERT (SELECT state='HELD' AND job_purged_at IS NOT NULL
  FROM public.export_cost_reservations r WHERE r.operation=resume_export_deletion.ambiguous_operation);
 PERFORM public.jobix_export_cost_reconcile();
 ASSERT (SELECT state='HELD' FROM public.export_cost_reservations
  WHERE public.export_cost_reservations.operation=resume_export_deletion.ambiguous_operation);

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
  PERFORM public.jobix_export_cost_reserve(resume_export_deletion.extra_operation);
 EXCEPTION WHEN raise_exception THEN rejected:=SQLERRM='SERVICE_UNAVAILABLE'; END;
 ASSERT rejected;

 ASSERT public.jobix_export_cost_resolve(ambiguous_operation,1,'provider_reconciled',
  'local-fixture-provider-check')='SETTLED';
 SELECT p.shared_cost_reserve_microusd+coalesce(sum(CASE
   WHEN r.state='HELD' THEN r.reserved_microusd
   WHEN r.state='SETTLED' AND r.admitted_at>clock_timestamp()-p.rolling_window
    THEN r.settled_microusd ELSE 0 END),0)
 INTO used_after
 FROM public.export_cost_budget_policy p
 LEFT JOIN public.export_cost_reservations r ON r.state<>'RELEASED'
 WHERE p.singleton GROUP BY p.shared_cost_reserve_microusd,p.rolling_window;
 ASSERT used_after=used_before;
 UPDATE public.export_cost_budget_policy SET budget_microusd=used_after+1 WHERE singleton;
 ASSERT public.jobix_export_cost_reserve(extra_operation)=1;
 DELETE FROM public.export_cost_reservations
  WHERE public.export_cost_reservations.operation=resume_export_deletion.extra_operation;
 UPDATE public.export_cost_budget_policy SET budget_microusd=10000000 WHERE singleton;
 ASSERT NOT has_function_privilege('authenticated','public.jobix_export_purge(uuid,uuid,boolean)','EXECUTE');
 ASSERT NOT has_function_privilege('jobix_export_gateway','public.jobix_export_upload_settle(uuid,uuid,text)','EXECUTE');
 UPDATE public.export_settings SET enabled=false,deletion_policy_approved=false;
END $$;
DROP FUNCTION pg_temp.fixture_create(uuid,uuid);
DROP FUNCTION pg_temp.fixture_actor();
DROP FUNCTION pg_temp.must_fail(text,text);
