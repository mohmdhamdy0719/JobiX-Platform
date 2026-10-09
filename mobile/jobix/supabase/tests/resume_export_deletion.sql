-- Fixtures and helper functions from resume_export_recovery.sql, same connection.
DO $$
<<resume_export_deletion>>
DECLARE actor uuid:=pg_temp.fixture_actor(); other_actor uuid:=pg_temp.fixture_actor();
 profile uuid; ack jsonb; operation uuid; claim jsonb; fence uuid; result jsonb;
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
 ASSERT (SELECT finalized_balance FROM public.credit_accounts WHERE user_id=actor)=5;
 ASSERT EXISTS(SELECT FROM public.users WHERE id=actor);
 ASSERT EXISTS(SELECT FROM public.career_profiles WHERE user_id=other_actor);
 DELETE FROM public.career_profiles WHERE id=profile;
 ASSERT NOT has_function_privilege('authenticated','public.jobix_export_purge(uuid,uuid,boolean)','EXECUTE');
 ASSERT NOT has_function_privilege('jobix_export_gateway','public.jobix_export_upload_settle(uuid,uuid,text)','EXECUTE');
 UPDATE public.export_settings SET enabled=false,deletion_policy_approved=false;
END $$;
DROP FUNCTION pg_temp.fixture_create(uuid,uuid);
DROP FUNCTION pg_temp.fixture_actor();
DROP FUNCTION pg_temp.must_fail(text,text);
