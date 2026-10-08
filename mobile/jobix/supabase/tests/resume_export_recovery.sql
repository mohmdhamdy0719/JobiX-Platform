-- All identities and records are synthetic in the disposable runner.
CREATE FUNCTION pg_temp.fixture_actor() RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE actor uuid:=gen_random_uuid(); profile uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(actor,'fixture-'||actor||'@example.invalid');
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=actor;
 UPDATE public.profile_personal_data SET full_name='Fixture',email='fixture@example.invalid',
 phone='+20 100 000 0000' WHERE profile_id=profile;
 INSERT INTO public.profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current)
 VALUES(gen_random_uuid(),profile,'Community','Helper','2025-01-01',true);
 RETURN actor;
END $$;
CREATE FUNCTION pg_temp.fixture_create(actor uuid,command uuid DEFAULT gen_random_uuid()) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE input jsonb; profile uuid; html text:='<body>synthetic</body>';
BEGIN
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=actor;
 input:=public.jobix_export_source(actor,profile);
 RETURN public.jobix_export_create(actor,command,gen_random_uuid(),profile,
 (input#>>'{source,profile,profile_version}')::bigint,(input#>>'{source,configuration,version}')::bigint,
 input->>'source_sha256',encode(sha256(convert_to(html,'UTF8')),'hex'),repeat('a',64),
 html,'jobix-resume-export-1');
END $$;
CREATE FUNCTION pg_temp.must_fail(statement text,code text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE statement;
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM=code THEN RETURN; END IF;RAISE;
 END;
 RAISE EXCEPTION 'Expected error %',code;
END $$;

DO $$
DECLARE actor uuid; ack jsonb; operation uuid; claimed jsonb; first_fence uuid; fence uuid;
 reservation uuid; attempts integer; paths jsonb; profile uuid; before_count integer;
BEGIN
 ASSERT NOT (SELECT enabled FROM public.export_settings);
 UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true;
 actor:=pg_temp.fixture_actor();ack:=pg_temp.fixture_create(actor);
 operation:=(ack->>'operation_id')::uuid;
 reservation:=(ack#>>'{data,reservation_id}')::uuid;
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_finish(%L,NULL,NULL,true)',operation),'STALE_LEASE');
 ASSERT (SELECT state FROM public.credit_reservations WHERE id=reservation)='PENDING';
 claimed:=public.jobix_export_claim(2);first_fence:=(claimed#>>'{0,lease_token}')::uuid;
 PERFORM pg_temp.must_fail(format('SELECT public.finish_resume_credits(%L,%L,true)',operation,first_fence),'FORBIDDEN');
 PERFORM public.jobix_export_stage(operation,first_fence,'GENERATING');
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_stage(%L,%L,%L)',operation,first_fence,'CLAIMED'),'STALE_LEASE');
 ASSERT public.jobix_export_finish(operation,first_fence,NULL,false)='RETRYABLE_FAILURE';
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=2;
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_finish(%L,%L,NULL,true)',operation,first_fence),'STALE_LEASE');
 ASSERT public.jobix_export_claim(2)='[]';
 UPDATE public.export_jobs SET next_attempt_at=now() WHERE id=operation;
 claimed:=public.jobix_export_claim(2);fence:=(claimed#>>'{0,lease_token}')::uuid;
 ASSERT fence<>first_fence;
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_heartbeat(%L,%L)',operation,first_fence),'STALE_LEASE');
 UPDATE public.export_jobs SET lease_expires_at=now()-interval '1 second' WHERE id=operation;
 ASSERT public.jobix_export_recover()=1;
 claimed:=public.jobix_export_claim(2);fence:=(claimed#>>'{0,lease_token}')::uuid;
 ASSERT (SELECT attempt_count FROM public.export_jobs WHERE id=operation)=3;
 ASSERT public.jobix_export_recover()=0; -- Live third attempt cannot be reaped.
 ASSERT public.jobix_export_finish(operation,fence,NULL,false)='FAILED';
 ASSERT public.jobix_export_finish(operation,fence,NULL,false)='FAILED';
 ASSERT (SELECT finalized_balance FROM public.credit_accounts WHERE user_id=actor)=5;
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=0;
 ASSERT NOT EXISTS(SELECT FROM public.credit_transactions WHERE user_id=actor AND delta=-2);
 ASSERT public.jobix_export_replay(actor,(SELECT idempotency_key FROM public.export_jobs WHERE id=operation),repeat('a',64))=ack;

 -- Freeze only consumes the existing already-DELETING contract.
 ack:=pg_temp.fixture_create(actor);operation:=(ack->>'operation_id')::uuid;
 claimed:=public.jobix_export_claim(2);fence:=(claimed#>>'{0,lease_token}')::uuid;
 SELECT id INTO profile FROM public.career_profiles WHERE user_id=actor;
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_freeze(%L,%L)',actor,profile),'FORBIDDEN');
 UPDATE public.career_profiles SET status='DELETING' WHERE id=profile;
 paths:=public.jobix_export_freeze(actor,profile);
 ASSERT jsonb_array_length(paths)=2;
 ASSERT (SELECT state FROM public.export_jobs WHERE id=operation)='DELETION_PENDING';
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=0;
 ASSERT public.jobix_export_freeze(actor,profile)=paths;
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_finish(%L,%L,NULL,true)',operation,fence),'STALE_LEASE');
 ASSERT public.jobix_export_claim(2)='[]';
 ASSERT (SELECT count(*) FROM public.export_snapshots WHERE user_id=actor)=2;
 ASSERT (SELECT count(*) FROM public.export_jobs WHERE user_id=actor)=2; -- Dedupe/history not pruned.
 ASSERT NOT has_function_privilege('authenticated','public.jobix_export_freeze(uuid,uuid)','EXECUTE');
 ASSERT NOT has_function_privilege('service_role','public.jobix_export_finish_pre_hardening(uuid,uuid,jsonb,boolean)','EXECUTE');

 -- Deadline covers the entire job, even with attempts remaining.
 actor:=pg_temp.fixture_actor();ack:=pg_temp.fixture_create(actor);
 operation:=(ack->>'operation_id')::uuid;
 claimed:=public.jobix_export_claim(2);fence:=(claimed#>>'{0,lease_token}')::uuid;
 UPDATE public.export_jobs SET deadline=now()-interval '1 second' WHERE id=operation;
 PERFORM pg_temp.must_fail(format('SELECT public.jobix_export_finish(%L,%L,NULL,true)',operation,fence),'STALE_LEASE');
 ASSERT public.jobix_export_recover()=1;
 ASSERT public.jobix_export_recover()=0;
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=0;
 ASSERT (SELECT finalized_balance FROM public.credit_accounts WHERE user_id=actor)=5;
 ASSERT NOT EXISTS(SELECT FROM public.credit_transactions WHERE user_id=actor AND delta=-2);
 UPDATE public.export_settings SET enabled=false,deletion_policy_approved=false;
END $$;
-- Helpers are removed after the approved deletion-contract checks in the same session.
