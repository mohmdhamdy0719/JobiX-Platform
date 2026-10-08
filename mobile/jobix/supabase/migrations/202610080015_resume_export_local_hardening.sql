-- LOCAL ONLY: no live migration approval. No Auth/deletion-policy changes.
BEGIN;
ALTER TABLE public.export_snapshots ADD COLUMN asset_manifest jsonb NOT NULL DEFAULT '{}';
CREATE FUNCTION public.jobix_export_fonts(html text) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(encode(sha256(decode(m[1],'base64')),'hex')),'[]'::jsonb)
 FROM regexp_matches(html,'data:font/ttf;base64,([A-Za-z0-9+/=]+)','g') m;
$$;
ALTER FUNCTION public.jobix_export_valid(jsonb) RENAME TO jobix_export_valid_pre_hardening;
CREATE FUNCTION public.jobix_export_valid(source jsonb) RETURNS boolean
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE p jsonb:=source->'profile'; item jsonb; kind text; field text; value text;
 max_length integer;
BEGIN
 IF NOT public.jobix_export_valid_pre_hardening(source) THEN RETURN false; END IF;
 FOREACH field IN ARRAY ARRAY['linkedin_url','github_url','portfolio_url'] LOOP
  PERFORM public.jobix_url_field(p->'personal',field);
 END LOOP;
 FOR kind IN SELECT unnest(ARRAY['experiences','volunteer_experiences','education',
 'certifications','achievements','projects','skills','languages']) LOOP
  IF source#>>ARRAY['configuration','section_visibility',
    CASE kind WHEN 'experiences' THEN 'experience' WHEN 'volunteer_experiences' THEN 'volunteer'
     WHEN 'certifications' THEN 'certification' WHEN 'achievements' THEN 'achievement'
     WHEN 'projects' THEN 'project' WHEN 'skills' THEN 'skill' WHEN 'languages' THEN 'language' ELSE kind END]='false' THEN CONTINUE; END IF;
  FOR item IN SELECT x FROM jsonb_array_elements(coalesce(p->kind,'[]')) x LOOP
   FOR field,value IN SELECT key,val FROM jsonb_each_text(item) e(key,val) LOOP
    IF field IN ('job_title','company','location','organization','role','degree',
     'institution','field_of_study','name','issuer','credential_id','title','proficiency') THEN
     max_length:=CASE WHEN kind IN ('skills','languages') AND field='name' THEN 100 ELSE 200 END;
     IF char_length(value)>max_length THEN RETURN false; END IF;
    END IF;
   END LOOP;
   IF kind='projects' AND item->'technologies' IS NOT NULL THEN
    IF jsonb_typeof(item->'technologies')<>'array' THEN RETURN false; END IF;
    IF EXISTS(SELECT FROM jsonb_array_elements(item->'technologies') v
      WHERE jsonb_typeof(v)<>'string' OR char_length(v#>>'{}')>100) THEN RETURN false; END IF;
   END IF;
  END LOOP;
 END LOOP;
 RETURN true;
EXCEPTION WHEN OTHERS THEN RETURN false;
END $$;

ALTER FUNCTION public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid)
 RENAME TO jobix_export_create_pre_manifest;
REVOKE ALL ON FUNCTION public.jobix_export_create_pre_manifest(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;
CREATE FUNCTION public.jobix_export_create(actor uuid,command uuid,request_id uuid,
 profile uuid,profile_version bigint,config_version bigint,source_hash text,
 document_hash text,request_hash text,html text,bundle text,again uuid DEFAULT NULL,
 asset_manifest jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE replay jsonb; input jsonb; source jsonb; operation uuid:=gen_random_uuid();
 snapshot uuid; r jsonb; balance jsonb; ack jsonb; fonts jsonb;
BEGIN
 replay:=public.jobix_export_replay(actor,command,request_hash);
 IF replay IS NOT NULL THEN RETURN replay; END IF;
 IF NOT EXISTS(SELECT FROM public.export_settings WHERE enabled AND deletion_policy_approved) THEN RAISE EXCEPTION 'EXPORT_NOT_READY'; END IF;
 IF command IS NULL OR request_id IS NULL OR request_hash !~ '^[0-9a-f]{64}$'
 OR request_hash IS NULL OR bundle IS DISTINCT FROM 'jobix-resume-export-1'
 OR document_hash IS DISTINCT FROM encode(sha256(convert_to(html,'UTF8')),'hex') THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 IF again IS NOT NULL AND NOT EXISTS(SELECT FROM public.export_jobs WHERE id=again AND user_id=actor AND profile_id=profile) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 input:=public.jobix_export_source(actor,profile);source:=input->'source';
 IF source_hash IS DISTINCT FROM input->>'source_sha256'
 OR profile_version IS DISTINCT FROM (source#>>'{profile,profile_version}')::bigint
 OR config_version IS DISTINCT FROM (source#>>'{configuration,version}')::bigint THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
 IF NOT public.jobix_export_valid(source) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 fonts:=public.jobix_export_fonts(html);
 IF jsonb_typeof(asset_manifest) IS DISTINCT FROM 'object'
 OR octet_length(asset_manifest::text)>32000
 OR (asset_manifest ? 'font_checksums' AND asset_manifest->'font_checksums' IS DISTINCT FROM fonts)
 OR (asset_manifest ? 'bundle' AND asset_manifest->>'bundle' IS DISTINCT FROM bundle) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 asset_manifest:=asset_manifest||jsonb_build_object('font_checksums',fonts,'bundle',bundle,
  'model_version',2,'template_version',2,'render_config_version','export-v1');
 IF (SELECT count(*) FROM public.export_jobs WHERE user_id=actor AND created_at>now()-interval '10 minutes')>=5 THEN RAISE EXCEPTION 'RATE_LIMITED'; END IF;
 BEGIN r:=public.reserve_resume_credits(actor,operation);
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='INSUFFICIENT_CREDITS' THEN RAISE EXCEPTION 'CREDIT_INSUFFICIENT'; END IF;RAISE;
 END;
 INSERT INTO public.export_snapshots(user_id,profile_id,source,source_sha256,canonical_html,document_sha256,bundle,asset_manifest)
 VALUES(actor,profile,source,source_hash,html,document_hash,bundle,asset_manifest) RETURNING id INTO snapshot;
 SELECT jsonb_build_object('finalized',finalized_balance,'reserved',reserved_balance,
 'available',finalized_balance-reserved_balance,'version',version) INTO balance FROM public.credit_accounts WHERE user_id=actor;
 ack:=jsonb_build_object('request_id',request_id,'operation_id',operation,'state','QUEUED',
 'authoritative_version',profile_version,'error',NULL,'data',jsonb_build_object(
 'export_id',operation,'snapshot_id',snapshot,'document_sha256',document_hash,
 'source_version',profile_version,'configuration_version',config_version,
 'reservation_id',r->'id','reserved_credits',2,'balance',balance));
 INSERT INTO public.export_jobs(id,user_id,profile_id,snapshot_id,reservation_id,idempotency_key,request_sha256,acknowledgement,deadline)
 VALUES(operation,actor,profile,snapshot,(r->>'id')::uuid,command,request_hash,ack,(r->>'expires_at')::timestamptz);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,operation_id,response_state)
 VALUES(actor,'export.create',command,request_hash,operation,ack);
 RETURN ack;
END $$;

ALTER FUNCTION public.jobix_export_finish(uuid,uuid,jsonb,boolean) RENAME TO jobix_export_finish_pre_hardening;
REVOKE ALL ON FUNCTION public.jobix_export_finish_pre_hardening(uuid,uuid,jsonb,boolean)
 FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;
CREATE FUNCTION public.jobix_export_finish(operation uuid,fence uuid,proof jsonb DEFAULT NULL,terminal boolean DEFAULT false)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.export_jobs; owner uuid;
BEGIN
 SELECT user_id INTO owner FROM public.export_jobs WHERE id=operation;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 PERFORM 1 FROM public.users WHERE id=owner FOR UPDATE;
 PERFORM 1 FROM public.credit_accounts WHERE user_id=owner FOR UPDATE;
 SELECT * INTO j FROM public.export_jobs WHERE id=operation FOR UPDATE;
 IF j.state IN ('COMPLETED','FAILED','EXPIRED','MISSING_OBJECT','DELETED') THEN RETURN j.state; END IF;
 IF fence IS NULL OR j.lease_token IS NULL OR j.lease_expires_at IS NULL
 OR j.state NOT IN ('CLAIMED','GENERATING','UPLOADING') OR j.lease_token IS DISTINCT FROM fence
 OR j.lease_expires_at<=now() OR j.deadline<=now() THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
 IF proof IS NOT NULL AND NOT EXISTS(SELECT FROM public.career_profiles
 WHERE id=j.profile_id AND user_id=owner AND status='ACTIVE') THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 RETURN public.jobix_export_finish_pre_hardening(operation,fence,proof,terminal);
END $$;

CREATE OR REPLACE FUNCTION public.jobix_export_claim(capacity integer DEFAULT 2) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM public.export_settings WHERE enabled AND deletion_policy_approved) THEN RETURN '[]'; END IF;
 -- Due retries re-enter QUEUED with the original job/reservation, then claim.
 UPDATE public.export_jobs SET state='QUEUED',updated_at=now()
 WHERE id IN (SELECT q.id FROM public.export_jobs q
 JOIN public.users u ON u.id=q.user_id
 JOIN public.career_profiles p ON p.id=q.profile_id AND p.user_id=q.user_id
 WHERE q.state='RETRYABLE_FAILURE' AND q.next_attempt_at<=now() AND q.deadline>now()
 AND q.attempt_count<3 AND u.status='ACTIVE' AND p.status='ACTIVE'
 ORDER BY q.created_at,q.id FOR UPDATE OF q SKIP LOCKED
 LIMIT greatest(0,least(capacity,2)));
 WITH claimed AS (
 UPDATE public.export_jobs j SET state='CLAIMED',lease_token=gen_random_uuid(),
 lease_expires_at=least(deadline,now()+interval '5 minutes'),attempt_count=attempt_count+1,updated_at=now()
 WHERE j.id IN (SELECT q.id FROM public.export_jobs q JOIN public.users u ON u.id=q.user_id
 JOIN public.career_profiles p ON p.id=q.profile_id AND p.user_id=q.user_id
 WHERE u.status='ACTIVE' AND p.status='ACTIVE' AND q.state='QUEUED'
 AND q.next_attempt_at<=now() AND q.deadline>now() AND q.attempt_count<3 ORDER BY q.created_at,q.id
 FOR UPDATE OF q SKIP LOCKED LIMIT greatest(0,least(capacity,2))) RETURNING j.*)
 SELECT coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('snapshot',to_jsonb(s))),'[]')
 INTO result FROM claimed c JOIN public.export_snapshots s ON s.id=c.snapshot_id;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.jobix_export_heartbeat(operation uuid,fence uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.export_jobs j SET lease_expires_at=least(deadline,now()+interval '5 minutes'),updated_at=now()
 WHERE id=operation AND lease_token=fence AND lease_expires_at>now() AND deadline>now()
 AND state IN ('CLAIMED','GENERATING','UPLOADING')
 AND EXISTS(SELECT FROM public.users u WHERE u.id=j.user_id AND u.status='ACTIVE')
 AND EXISTS(SELECT FROM public.career_profiles p WHERE p.id=j.profile_id AND p.status='ACTIVE');
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.jobix_export_stage(operation uuid,fence uuid,stage text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.export_jobs j SET state=stage,updated_at=now()
 WHERE id=operation AND lease_token=fence AND lease_expires_at>now() AND deadline>now()
 AND ((state='CLAIMED' AND stage='GENERATING') OR (state='GENERATING' AND stage='UPLOADING'))
 AND EXISTS(SELECT FROM public.users u WHERE u.id=j.user_id AND u.status='ACTIVE')
 AND EXISTS(SELECT FROM public.career_profiles p WHERE p.id=j.profile_id AND p.status='ACTIVE');
 IF NOT FOUND THEN RAISE EXCEPTION 'STALE_LEASE'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.jobix_export_recover() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE candidate record; j public.export_jobs; r public.credit_reservations; total integer:=0;
BEGIN
 FOR candidate IN SELECT id,user_id FROM public.export_jobs WHERE
 state IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE')
 AND (deadline<=now() OR lease_expires_at<=now() OR
 NOT EXISTS(SELECT FROM public.users WHERE id=user_id AND status='ACTIVE') OR
 NOT EXISTS(SELECT FROM public.career_profiles p WHERE p.id=profile_id AND p.status='ACTIVE'))
 ORDER BY user_id,id LIMIT 100 LOOP
  PERFORM 1 FROM public.users WHERE id=candidate.user_id FOR UPDATE;
  PERFORM 1 FROM public.credit_accounts WHERE user_id=candidate.user_id FOR UPDATE;
  SELECT * INTO j FROM public.export_jobs WHERE id=candidate.id FOR UPDATE;
  IF j.state NOT IN ('QUEUED','CLAIMED','GENERATING','UPLOADING','RETRYABLE_FAILURE') THEN CONTINUE; END IF;
  -- Recheck eligibility after lock waits; never reap a newly renewed valid lease.
  IF j.deadline>now() AND (j.lease_expires_at IS NULL OR j.lease_expires_at>now())
  AND EXISTS(SELECT FROM public.users WHERE id=j.user_id AND status='ACTIVE')
  AND EXISTS(SELECT FROM public.career_profiles WHERE id=j.profile_id AND status='ACTIVE') THEN CONTINUE; END IF;
  IF j.deadline<=now() OR j.attempt_count>=3 OR
   NOT EXISTS(SELECT FROM public.users WHERE id=j.user_id AND status='ACTIVE') OR
   NOT EXISTS(SELECT FROM public.career_profiles WHERE id=j.profile_id AND status='ACTIVE') THEN
   SELECT * INTO r FROM public.credit_reservations WHERE id=j.reservation_id FOR UPDATE;
   IF r.state='PENDING' THEN PERFORM public.finish_resume_credits_pre_export(j.id,r.fencing_token,false); END IF;
   UPDATE public.export_jobs SET state='FAILED',error_code='RESERVATION_EXPIRED',lease_token=NULL,lease_expires_at=NULL,updated_at=now() WHERE id=j.id;
  ELSE
   UPDATE public.export_jobs SET state='RETRYABLE_FAILURE',lease_token=NULL,lease_expires_at=NULL,next_attempt_at=now(),updated_at=now() WHERE id=j.id;
  END IF;
  total:=total+1;
 END LOOP;
 UPDATE public.export_jobs SET state='EXPIRED',updated_at=now() WHERE state='COMPLETED' AND expires_at<=now();
 RETURN total;
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_fonts(text),public.jobix_export_valid(jsonb),
 public.jobix_export_valid_pre_hardening(jsonb),
 public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid,jsonb),
 public.jobix_export_finish(uuid,uuid,jsonb,boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid,jsonb) TO jobix_export_gateway;
GRANT EXECUTE ON FUNCTION public.jobix_export_finish(uuid,uuid,jsonb,boolean) TO jobix_export_worker;
ALTER FUNCTION public.jobix_export_status(uuid,uuid) RENAME TO jobix_export_status_pre_hardening;
REVOKE ALL ON FUNCTION public.jobix_export_status_pre_hardening(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker;
CREATE FUNCTION public.jobix_export_status(actor uuid,operation uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE body jsonb; eligible boolean;
BEGIN
 body:=public.jobix_export_status_pre_hardening(actor,operation);
 SELECT j.state='COMPLETED' AND j.expires_at>now()
 AND EXISTS(SELECT FROM public.career_profiles p WHERE p.id=j.profile_id AND p.user_id=actor AND p.status='ACTIVE')
 INTO eligible FROM public.export_jobs j WHERE j.id=operation AND j.user_id=actor;
 RETURN body||jsonb_build_object('download_eligible',coalesce(eligible,false));
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_status(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.jobix_export_status(uuid,uuid) TO jobix_export_gateway;
COMMIT;
