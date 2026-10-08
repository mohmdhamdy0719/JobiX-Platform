-- Private job-aware lifecycle. Deletion/purge policy remains unimplemented.
BEGIN;
ALTER FUNCTION public.finish_resume_credits(uuid,uuid,boolean) RENAME TO finish_resume_credits_pre_export;
REVOKE ALL ON FUNCTION public.finish_resume_credits_pre_export(uuid,uuid,boolean) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.finish_resume_credits(operation uuid,fence uuid,successful boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.credit_reservations;
BEGIN
 IF EXISTS(SELECT FROM public.export_jobs WHERE id=operation) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 SELECT * INTO r FROM public.credit_reservations WHERE operation_id=operation;
 IF fence IS DISTINCT FROM r.fencing_token THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
 IF r.state IN ('CONSUMED','RELEASED','EXPIRED') THEN RETURN r.state; END IF;
 RETURN public.finish_resume_credits_pre_export(operation,fence,successful);
END $$;
REVOKE ALL ON FUNCTION public.finish_resume_credits(uuid,uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finish_resume_credits(uuid,uuid,boolean) TO service_role;
CREATE OR REPLACE FUNCTION public.expire_resume_credits() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.credit_reservations; total integer:=0;
BEGIN
 FOR r IN SELECT * FROM public.credit_reservations WHERE state='PENDING' AND expires_at<=now()
 AND NOT EXISTS(SELECT FROM public.export_jobs WHERE id=operation_id) ORDER BY user_id,id LOOP
  PERFORM public.finish_resume_credits(r.operation_id,r.fencing_token,false);total:=total+1;
 END LOOP;
 RETURN total;
END $$;

CREATE FUNCTION public.jobix_export_claim(capacity integer DEFAULT 2) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM public.export_settings WHERE enabled AND deletion_policy_approved) THEN RETURN '[]'; END IF;
 WITH claimed AS (
 UPDATE public.export_jobs j SET state='CLAIMED',lease_token=gen_random_uuid(),
 lease_expires_at=least(deadline,now()+interval '5 minutes'),attempt_count=attempt_count+1,updated_at=now()
 WHERE j.id IN (SELECT q.id FROM public.export_jobs q JOIN public.users u ON u.id=q.user_id
 WHERE u.status='ACTIVE' AND q.state IN ('QUEUED','RETRYABLE_FAILURE') AND q.next_attempt_at<=now()
 AND q.deadline>now() AND q.attempt_count<3 ORDER BY q.created_at,q.id
 FOR UPDATE OF q SKIP LOCKED LIMIT greatest(0,least(capacity,2))) RETURNING j.*)
 SELECT coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('snapshot',to_jsonb(s))),'[]')
 INTO result FROM claimed c JOIN public.export_snapshots s ON s.id=c.snapshot_id;
 RETURN result;
END $$;
CREATE FUNCTION public.jobix_export_heartbeat(operation uuid,fence uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.export_jobs SET lease_expires_at=least(deadline,now()+interval '5 minutes'),updated_at=now()
 WHERE id=operation AND lease_token=fence AND lease_expires_at>now() AND deadline>now()
 AND state IN ('CLAIMED','GENERATING','UPLOADING')
 AND EXISTS(SELECT FROM public.users WHERE id=user_id AND status='ACTIVE');
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
END $$;
CREATE FUNCTION public.jobix_export_stage(operation uuid,fence uuid,stage text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.export_jobs SET state=stage,updated_at=now()
 WHERE id=operation AND lease_token=fence AND lease_expires_at>now() AND deadline>now()
 AND ((state='CLAIMED' AND stage='GENERATING') OR (state='GENERATING' AND stage='UPLOADING'))
 AND EXISTS(SELECT FROM public.users WHERE id=user_id AND status='ACTIVE');
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
END $$;

CREATE FUNCTION public.jobix_export_finish(operation uuid,fence uuid,proof jsonb DEFAULT NULL,
 terminal boolean DEFAULT false) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.export_jobs; r public.credit_reservations; owner uuid; snapshot public.export_snapshots; path text; final_state text;
BEGIN
 SELECT user_id INTO owner FROM public.export_jobs WHERE id=operation;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 PERFORM 1 FROM public.users WHERE id=owner FOR UPDATE;
 IF proof IS NOT NULL AND NOT EXISTS(SELECT FROM public.users WHERE id=owner AND status='ACTIVE') THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 PERFORM 1 FROM public.credit_accounts WHERE user_id=owner FOR UPDATE;
 SELECT * INTO j FROM public.export_jobs WHERE id=operation FOR UPDATE;
 IF j.state IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED') THEN RETURN j.state; END IF;
 IF j.lease_token IS DISTINCT FROM fence OR j.lease_expires_at<=now() OR j.deadline<=now() THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
 SELECT * INTO r FROM public.credit_reservations WHERE id=j.reservation_id FOR UPDATE;
 IF r.state<>'PENDING' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
 IF proof IS NOT NULL THEN
  SELECT * INTO snapshot FROM public.export_snapshots WHERE id=j.snapshot_id;
  path:='exports/'||j.user_id||'/'||j.id||'/'||snapshot.source_sha256||'.pdf';
  IF j.state<>'UPLOADING' OR proof->>'path' IS DISTINCT FROM path
   OR proof->>'generation' !~ '^[1-9][0-9]*$' OR proof->>'generation' IS NULL
   OR proof->>'pdf_sha256' !~ '^[0-9a-f]{64}$' OR proof->>'pdf_sha256' IS NULL
   OR proof->>'document_sha256' IS DISTINCT FROM snapshot.document_sha256
   OR (proof->>'pages')::integer NOT BETWEEN 1 AND 20 OR proof->>'pages' IS NULL
   OR (proof->>'size')::bigint<=0 OR proof->>'size' IS NULL
   OR proof->>'content_type' IS DISTINCT FROM 'application/pdf'
   OR (proof->>'created_at')::timestamptz>now()+interval '1 minute'
   OR (proof->>'created_at')::timestamptz<j.created_at-interval '1 minute'
   OR proof->>'created_at' IS NULL THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
  PERFORM public.finish_resume_credits_pre_export(operation,r.fencing_token,true);
  UPDATE public.export_jobs SET state='COMPLETED',object_path=path,object_generation=proof->>'generation',
   pdf_sha256=proof->>'pdf_sha256',page_count=(proof->>'pages')::integer,object_size=(proof->>'size')::bigint,
   completed_at=now(),expires_at=(proof->>'created_at')::timestamptz+interval '7 days',
   lease_token=NULL,lease_expires_at=NULL,error_code=NULL,updated_at=now() WHERE id=operation;
  RETURN 'COMPLETED';
 END IF;
 IF terminal OR j.attempt_count>=3 THEN
  PERFORM public.finish_resume_credits_pre_export(operation,r.fencing_token,false);
  final_state:='FAILED';
 ELSE final_state:='RETRYABLE_FAILURE'; END IF;
 UPDATE public.export_jobs SET state=final_state,lease_token=NULL,lease_expires_at=NULL,
 next_attempt_at=now()+interval '30 seconds',error_code='EXPORT_GENERATION_FAILED',updated_at=now() WHERE id=operation;
 RETURN final_state;
END $$;

CREATE FUNCTION public.jobix_export_recover() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE candidate record; j public.export_jobs; r public.credit_reservations; total integer:=0;
BEGIN
 FOR candidate IN SELECT id,user_id FROM public.export_jobs WHERE
 state IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE')
 AND (deadline<=now() OR lease_expires_at<=now() OR
 NOT EXISTS(SELECT FROM public.users WHERE id=user_id AND status='ACTIVE'))
 ORDER BY user_id,id LIMIT 100 LOOP
  PERFORM 1 FROM public.users WHERE id=candidate.user_id FOR UPDATE;
  PERFORM 1 FROM public.credit_accounts WHERE user_id=candidate.user_id FOR UPDATE;
  SELECT * INTO j FROM public.export_jobs WHERE id=candidate.id FOR UPDATE;
  IF j.state NOT IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE') THEN CONTINUE; END IF;
  IF j.deadline<=now() OR j.attempt_count>=3 OR NOT EXISTS(SELECT FROM public.users WHERE id=j.user_id AND status='ACTIVE') THEN
   SELECT * INTO r FROM public.credit_reservations WHERE id=j.reservation_id FOR UPDATE;
   IF r.state='PENDING' THEN PERFORM public.finish_resume_credits_pre_export(j.id,r.fencing_token,false); END IF;
   UPDATE public.export_jobs SET state='FAILED',error_code='RESERVATION_EXPIRED',lease_token=NULL,lease_expires_at=NULL,updated_at=now() WHERE id=j.id;
  ELSIF j.lease_expires_at<=now() THEN
   UPDATE public.export_jobs SET state='RETRYABLE_FAILURE',lease_token=NULL,lease_expires_at=NULL,next_attempt_at=now(),updated_at=now() WHERE id=j.id;
  ELSE CONTINUE; END IF;
  total:=total+1;
 END LOOP;
 UPDATE public.export_jobs SET state='EXPIRED',updated_at=now() WHERE state='COMPLETED' AND expires_at<=now();
 RETURN total;
END $$;
CREATE FUNCTION public.jobix_export_missing(actor uuid,operation uuid,generation text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.jobix_export_status(actor,operation);
 UPDATE public.export_jobs SET state=CASE WHEN expires_at<=now() THEN 'EXPIRED' ELSE 'MISSING_OBJECT' END,updated_at=now()
 WHERE id=operation AND user_id=actor AND state='COMPLETED' AND object_generation=generation;
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_claim(integer),public.jobix_export_heartbeat(uuid,uuid),
 public.jobix_export_stage(uuid,uuid,text),public.jobix_export_finish(uuid,uuid,jsonb,boolean),
 public.jobix_export_recover(),public.jobix_export_missing(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.jobix_export_claim(integer),public.jobix_export_heartbeat(uuid,uuid),
 public.jobix_export_stage(uuid,uuid,text),public.jobix_export_finish(uuid,uuid,jsonb,boolean),
 public.jobix_export_recover() TO jobix_export_worker;
GRANT EXECUTE ON FUNCTION public.jobix_export_missing(uuid,uuid,text) TO jobix_export_gateway;
COMMIT;
