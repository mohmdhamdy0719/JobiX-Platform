-- Synthetic disposable PostgreSQL only; never run on Supabase.
DO $test$
DECLARE
 actor uuid:=gen_random_uuid(); profile uuid; input jsonb;
 html text:='<html><body>admission fixture</body></html>';
 doc_hash text; ack jsonb; job uuid; v bigint;
 error_code text; error_detail text; jobs_before integer; reservations_before integer;
 at_time timestamptz:=clock_timestamp(); duration interval; maximum integer; i integer;
 retry integer; purge_result jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(actor,'admission-'||actor||'@example.invalid');
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 SELECT id,profile_version INTO profile,v FROM public.career_profiles WHERE user_id=actor;
 UPDATE public.profile_personal_data SET full_name='Admission',email='admission@example.invalid',
  phone='+20 100 000 0000' WHERE profile_id=profile;
 INSERT INTO public.profile_volunteer_experiences(id,profile_id,organization,role,start_month,is_current)
 VALUES(gen_random_uuid(),profile,'Community','Helper','2025-01-01',true);
 input:=public.jobix_export_source(actor,profile);
 doc_hash:=encode(sha256(convert_to(html,'UTF8')),'hex');
 UPDATE public.export_settings SET enabled=true,deletion_policy_approved=true;

 -- A genuinely accepted intent is logged once; same-key replay does not add
 -- history or reserve again, and a distinct active request is rejected.
 ack:=public.jobix_export_create(actor,gen_random_uuid(),gen_random_uuid(),profile,v,0,
  input->>'source_sha256',doc_hash,repeat('a',64),html,'jobix-resume-export-1');
 job:=(ack->>'operation_id')::uuid;
 ASSERT (SELECT count(*) FROM public.export_admission_events WHERE user_id=actor)=1;
 ASSERT public.jobix_export_replay(actor,(SELECT idempotency_key FROM public.export_jobs WHERE id=job),
  repeat('a',64))=ack;
 BEGIN
  PERFORM public.jobix_export_create(actor,gen_random_uuid(),gen_random_uuid(),profile,v,0,
   input->>'source_sha256',doc_hash,repeat('b',64),html,'jobix-resume-export-1');
  RAISE EXCEPTION 'second active intent accepted';
 EXCEPTION WHEN raise_exception THEN
  GET STACKED DIAGNOSTICS error_code=MESSAGE_TEXT;
  ASSERT error_code='EXPORT_IN_PROGRESS';
 END;
 ASSERT (SELECT count(*) FROM public.export_admission_events WHERE user_id=actor)=1;
 ASSERT (SELECT count(*) FROM public.export_jobs WHERE user_id=actor)=1;
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=2;

 -- Terminal accepted failures keep their quota event but release the reserve.
 UPDATE public.export_jobs SET deadline=now()-interval '1 second' WHERE id=job;
 PERFORM public.jobix_export_recover();
 ASSERT public.jobix_export_status(actor,job)->>'state'='FAILED';
 ASSERT (SELECT reserved_balance FROM public.credit_accounts WHERE user_id=actor)=0;
 ASSERT (SELECT count(*) FROM public.export_admission_events WHERE user_id=actor)=1;

 -- At every limit, a new intent is rejected before a job, reservation, or
 -- additional event is created. The exact seconds come from the limiting row.
 FOR i IN 1..4 LOOP
  DELETE FROM public.export_admission_events WHERE user_id=actor;
  duration:=CASE i WHEN 1 THEN interval '5 minutes' WHEN 2 THEN interval '1 hour'
   WHEN 3 THEN interval '24 hours' ELSE interval '7 days' END;
  maximum:=CASE i WHEN 1 THEN 1 WHEN 2 THEN 3 WHEN 3 THEN 5 ELSE 10 END;
  INSERT INTO public.export_admission_events(user_id,accepted_at)
  SELECT actor,at_time-interval '2 seconds' FROM generate_series(1,maximum);
  retry:=public.jobix_export_admission_retry_seconds(actor,at_time);
  ASSERT retry=greatest(1,ceil(extract(epoch FROM duration-interval '2 seconds'))::integer);
  SELECT count(*) INTO jobs_before FROM public.export_jobs WHERE user_id=actor;
  SELECT count(*) INTO reservations_before FROM public.credit_reservations WHERE user_id=actor;
  BEGIN
   PERFORM public.jobix_export_create(actor,gen_random_uuid(),gen_random_uuid(),profile,v,0,
    input->>'source_sha256',doc_hash,repeat('c',64),html,'jobix-resume-export-1');
   RAISE EXCEPTION 'quota accepted at boundary';
  EXCEPTION WHEN raise_exception THEN
   GET STACKED DIAGNOSTICS error_code=MESSAGE_TEXT,error_detail=PG_EXCEPTION_DETAIL;
   ASSERT error_code='RATE_LIMITED';
   ASSERT error_detail ~ '^[1-9][0-9]*$';
  END;
  ASSERT (SELECT count(*) FROM public.export_jobs WHERE user_id=actor)=jobs_before;
  ASSERT (SELECT count(*) FROM public.credit_reservations WHERE user_id=actor)=reservations_before;
  ASSERT (SELECT count(*) FROM public.export_admission_events WHERE user_id=actor)=maximum;
 END LOOP;

 -- Rolling-window equality is no longer counted; one millisecond before it
 -- expires still blocks and returns a positive Retry-After.
 DELETE FROM public.export_admission_events WHERE user_id=actor;
 INSERT INTO public.export_admission_events(user_id,accepted_at)
 VALUES(actor,at_time-interval '5 minutes'+interval '500 milliseconds');
 ASSERT public.jobix_export_admission_retry_seconds(actor,at_time)=1;
 UPDATE public.export_admission_events SET accepted_at=at_time-interval '5 minutes'
 WHERE user_id=actor;
 ASSERT public.jobix_export_admission_retry_seconds(actor,at_time)=0;

 -- Profile purge removes jobs/snapshots but does not erase the minimally
 -- retained, profile-free seven-day admission event.
 UPDATE public.career_profiles SET status='DELETING' WHERE id=profile;
 purge_result:=public.jobix_export_purge(actor,profile,true);
 ASSERT purge_result->>'state'='EXPORT_DATA_REMOVED';
 ASSERT (SELECT count(*) FROM public.export_admission_events WHERE user_id=actor)=1;
 UPDATE public.export_admission_events SET accepted_at=clock_timestamp()-interval '7 days 1 second'
 WHERE user_id=actor;
 PERFORM public.jobix_export_retention();
 ASSERT NOT EXISTS(SELECT FROM public.export_admission_events WHERE user_id=actor);
 UPDATE public.export_settings SET enabled=false,deletion_policy_approved=false;
END $test$;
