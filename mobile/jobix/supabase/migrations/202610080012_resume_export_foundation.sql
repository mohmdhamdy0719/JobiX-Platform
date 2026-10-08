-- LOCAL IMPLEMENTATION ONLY. Not applied to development or production.
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='jobix_export_gateway') THEN
  CREATE ROLE jobix_export_gateway NOLOGIN NOSUPERUSER NOBYPASSRLS;
 END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='jobix_export_worker') THEN
  CREATE ROLE jobix_export_worker NOLOGIN NOSUPERUSER NOBYPASSRLS;
 END IF;
END $$;
GRANT USAGE ON SCHEMA public TO jobix_export_gateway,jobix_export_worker;
ALTER TABLE public.resume_configurations
 ADD COLUMN section_visibility jsonb NOT NULL DEFAULT '{}',
 ADD COLUMN section_order jsonb NOT NULL DEFAULT
 '["summary","experience","volunteer","education","certification","achievement","project","skill","language"]',
 ADD COLUMN render_config_version text NOT NULL DEFAULT 'export-v1',
 ADD COLUMN template_version integer NOT NULL DEFAULT 2;

CREATE TABLE public.export_settings (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 enabled boolean NOT NULL DEFAULT false,
 deletion_policy_approved boolean NOT NULL DEFAULT false
);
INSERT INTO public.export_settings DEFAULT VALUES;
CREATE TABLE public.export_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
 profile_id uuid REFERENCES public.career_profiles(id) ON DELETE SET NULL,
 source jsonb NOT NULL,
 source_sha256 text NOT NULL CHECK(source_sha256 ~ '^[0-9a-f]{64}$'),
 canonical_html text NOT NULL CHECK(octet_length(canonical_html) BETWEEN 1 AND 8000000),
 document_sha256 text NOT NULL CHECK(document_sha256 ~ '^[0-9a-f]{64}$'),
 bundle text NOT NULL CHECK(bundle='jobix-resume-export-1'),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.export_jobs (
 id uuid PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
 profile_id uuid REFERENCES public.career_profiles(id) ON DELETE SET NULL,
 snapshot_id uuid NOT NULL REFERENCES public.export_snapshots(id),
 reservation_id uuid NOT NULL UNIQUE REFERENCES public.credit_reservations(id),
 idempotency_key uuid NOT NULL,
 request_sha256 text NOT NULL,
 acknowledgement jsonb NOT NULL,
 state text NOT NULL DEFAULT 'QUEUED' CHECK(state IN
 ('QUEUED','CLAIMED','GENERATING','UPLOADING','COMPLETED','RETRYABLE_FAILURE',
 'FAILED','EXPIRED','MISSING_OBJECT','DELETION_PENDING','DELETED')),
 attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 3),
 lease_token uuid,lease_expires_at timestamptz,
 next_attempt_at timestamptz NOT NULL DEFAULT now(),
 deadline timestamptz NOT NULL,
 object_path text,object_generation text,pdf_sha256 text,
 page_count integer CHECK(page_count BETWEEN 1 AND 20),
 object_size bigint CHECK(object_size>0),
 completed_at timestamptz,expires_at timestamptz,
 error_code text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,idempotency_key)
);
CREATE INDEX export_jobs_due ON public.export_jobs(state,next_attempt_at,lease_expires_at);
CREATE INDEX export_jobs_owner ON public.export_jobs(user_id,created_at DESC,id DESC);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['export_settings','export_snapshots','export_jobs'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated,service_role,jobix_export_gateway,jobix_export_worker',t);
 END LOOP;
END $$;
CREATE FUNCTION public.jobix_export_immutable() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'INVALID_STATE'; END $$;
CREATE TRIGGER export_snapshot_immutable BEFORE UPDATE ON public.export_snapshots
 FOR EACH ROW EXECUTE FUNCTION public.jobix_export_immutable();

CREATE FUNCTION public.jobix_export_source(actor uuid,profile uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.career_profiles; c jsonb; source jsonb;
BEGIN
 PERFORM 1 FROM public.users WHERE id=actor AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO p FROM public.career_profiles WHERE id=profile
 AND user_id=actor AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 SELECT to_jsonb(r)-'updated_at' INTO c FROM public.resume_configurations r WHERE r.profile_id=profile;
 c:=coalesce(c,jsonb_build_object('language',coalesce(p.cv_language,'en'),
 'template_id','resume_ats_'||coalesce(p.cv_language,'en')||'_v1','version',0,
 'section_visibility','{}'::jsonb,'render_config_version','export-v1','template_version',2));
 source:=jsonb_build_object('profile',public.jobix_profile_text_snapshot(profile),
 'configuration',c,'links',coalesce((SELECT links FROM public.profile_extras WHERE profile_id=profile),'[]'));
 RETURN jsonb_build_object('source',source,'source_sha256',
 encode(sha256(convert_to(source::text,'UTF8')),'hex'));
END $$;

-- Defense in depth: shared source facts, not scored completeness or quality.
CREATE FUNCTION public.jobix_export_valid(source jsonb) RETURNS boolean
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE p jsonb:=source->'profile'; personal jsonb:=p->'personal';
 visibility jsonb:=source#>'{configuration,section_visibility}'; k text; a text;
 item jsonb; required_fields text[]; f text; evidence boolean:=false; s date; e date;
BEGIN
 IF nullif(btrim(personal->>'full_name'),'') IS NULL
 OR char_length(personal->>'full_name')>120
 OR coalesce(personal->>'email','') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 OR char_length(personal->>'email')>254
 OR coalesce(personal->>'phone','') !~ '^\+?[0-9 ()-]+$'
 OR length(regexp_replace(personal->>'phone','[^0-9]','','g')) NOT BETWEEN 7 AND 15
 OR char_length(personal->>'phone')>32 THEN RETURN false; END IF;
 IF coalesce(visibility->>'summary','true')<>'false' AND char_length(p->>'summary')>1000 THEN RETURN false; END IF;
 FOREACH k IN ARRAY ARRAY['experience','volunteer','education','certification','achievement','project','skill','language'] LOOP
  IF visibility->>k='false' THEN CONTINUE; END IF;
  a:=CASE k WHEN 'experience' THEN 'experiences' WHEN 'volunteer' THEN 'volunteer_experiences'
   WHEN 'education' THEN 'education' WHEN 'certification' THEN 'certifications'
   WHEN 'achievement' THEN 'achievements' WHEN 'project' THEN 'projects'
   WHEN 'skill' THEN 'skills' ELSE 'languages' END;
  required_fields:=CASE k WHEN 'experience' THEN ARRAY['job_title','company','start_month']
   WHEN 'volunteer' THEN ARRAY['organization','role','start_month']
   WHEN 'education' THEN ARRAY['degree','institution','field_of_study','start_month']
   WHEN 'certification' THEN ARRAY['name','issuer','issue_month']
   WHEN 'achievement' THEN ARRAY['title','issuer','achieved_month']
   WHEN 'project' THEN ARRAY['name','role','project_month']
   WHEN 'language' THEN ARRAY['name','proficiency'] ELSE ARRAY['name'] END;
  FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->a,'[]')) LOOP
   FOREACH f IN ARRAY required_fields LOOP
    IF nullif(btrim(item->>f),'') IS NULL THEN RETURN false; END IF;
   END LOOP;
   IF char_length(item->>'description')>1500 THEN RETURN false; END IF;
   FOR f IN SELECT jsonb_object_keys(item) LOOP
    IF f IN ('start_month','end_month','issue_month','expiry_month','achieved_month','project_month')
     AND nullif(item->>f,'') IS NOT NULL THEN
     IF item->>f !~ '^(?!0000)[0-9]{4}-(0[1-9]|1[0-2])$' THEN RETURN false; END IF;
    ELSIF f='url' THEN PERFORM public.jobix_url_field(item,f);
    END IF;
   END LOOP;
   IF k IN ('experience','volunteer','education') THEN
    s:=public.jobix_month_field(item,'start_month');
    IF NOT coalesce((item->>'is_current')::boolean,false) THEN
     e:=public.jobix_month_field(item,'end_month');
     IF e IS NULL OR e<s THEN RETURN false; END IF;
    END IF;
   END IF;
   IF k='certification' AND item->>'expiry_month'<item->>'issue_month' THEN RETURN false; END IF;
   IF k='language' AND item->>'proficiency' NOT IN ('BASIC','CONVERSATIONAL','PROFESSIONAL','FLUENT','NATIVE') THEN RETURN false; END IF;
   IF k<>'language' THEN evidence:=true; END IF;
  END LOOP;
 END LOOP;
 RETURN evidence;
EXCEPTION WHEN OTHERS THEN RETURN false;
END $$;

CREATE FUNCTION public.jobix_export_replay(actor uuid,command uuid,request_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.export_jobs;
BEGIN
 PERFORM 1 FROM public.users WHERE id=actor AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO j FROM public.export_jobs WHERE user_id=actor AND idempotency_key=command;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF j.request_sha256 IS DISTINCT FROM request_hash THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE'; END IF;
 RETURN j.acknowledgement;
END $$;

CREATE FUNCTION public.jobix_export_create(actor uuid,command uuid,request_id uuid,
 profile uuid,profile_version bigint,config_version bigint,source_hash text,
 document_hash text,request_hash text,html text,bundle text,again uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE replay jsonb; input jsonb; source jsonb; operation uuid:=gen_random_uuid();
 snapshot uuid; r jsonb; balance jsonb; ack jsonb;
BEGIN
 replay:=public.jobix_export_replay(actor,command,request_hash);
 IF replay IS NOT NULL THEN RETURN replay; END IF;
 IF NOT EXISTS(SELECT FROM public.export_settings WHERE enabled AND deletion_policy_approved) THEN
  RAISE EXCEPTION 'EXPORT_NOT_READY';
 END IF;
 IF command IS NULL OR request_id IS NULL OR request_hash !~ '^[0-9a-f]{64}$'
 OR request_hash IS NULL OR bundle IS DISTINCT FROM 'jobix-resume-export-1'
 OR document_hash IS DISTINCT FROM encode(sha256(convert_to(html,'UTF8')),'hex') THEN
  RAISE EXCEPTION 'VALIDATION_FAILED';
 END IF;
 IF again IS NOT NULL AND NOT EXISTS(SELECT FROM public.export_jobs WHERE id=again
 AND user_id=actor AND profile_id=profile) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
 input:=public.jobix_export_source(actor,profile); source:=input->'source';
 IF source_hash IS DISTINCT FROM input->>'source_sha256'
 OR profile_version IS DISTINCT FROM (source#>>'{profile,profile_version}')::bigint
 OR config_version IS DISTINCT FROM (source#>>'{configuration,version}')::bigint THEN
  RAISE EXCEPTION 'VERSION_CONFLICT';
 END IF;
 IF NOT public.jobix_export_valid(source) THEN RAISE EXCEPTION 'VALIDATION_FAILED'; END IF;
 IF (SELECT count(*) FROM public.export_jobs WHERE user_id=actor AND created_at>now()-interval '10 minutes')>=5 THEN
  RAISE EXCEPTION 'RATE_LIMITED';
 END IF;
 BEGIN r:=public.reserve_resume_credits(actor,operation);
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='INSUFFICIENT_CREDITS' THEN RAISE EXCEPTION 'CREDIT_INSUFFICIENT'; END IF;
  RAISE;
 END;
 INSERT INTO public.export_snapshots(user_id,profile_id,source,source_sha256,canonical_html,document_sha256,bundle)
 VALUES(actor,profile,source,source_hash,html,document_hash,bundle) RETURNING id INTO snapshot;
 SELECT jsonb_build_object('finalized',finalized_balance,'reserved',reserved_balance,
 'available',finalized_balance-reserved_balance,'version',version) INTO balance
 FROM public.credit_accounts WHERE user_id=actor;
 ack:=jsonb_build_object('request_id',request_id,'operation_id',operation,'state','QUEUED',
 'authoritative_version',profile_version,'error',NULL,'data',jsonb_build_object(
 'export_id',operation,'snapshot_id',snapshot,'document_sha256',document_hash,
 'source_version',profile_version,'configuration_version',config_version,
 'reservation_id',r->'id','reserved_credits',2,'balance',balance));
 INSERT INTO public.export_jobs(id,user_id,profile_id,snapshot_id,reservation_id,idempotency_key,
 request_sha256,acknowledgement,deadline)
 VALUES(operation,actor,profile,snapshot,(r->>'id')::uuid,command,request_hash,ack,(r->>'expires_at')::timestamptz);
 INSERT INTO public.idempotency_records(user_id,operation_type,idempotency_key,payload_hash,operation_id,response_state)
 VALUES(actor,'export.create',command,request_hash,operation,ack);
 RETURN ack;
END $$;

CREATE FUNCTION public.jobix_export_status(actor uuid,operation uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.export_jobs;
BEGIN
 IF NOT EXISTS(SELECT FROM public.users WHERE id=actor AND status='ACTIVE') THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 SELECT * INTO j FROM public.export_jobs WHERE id=operation AND user_id=actor;
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 RETURN to_jsonb(j)-'acknowledgement'-'request_sha256'-'lease_token'-'reservation_id';
END $$;
CREATE FUNCTION public.jobix_export_history(actor uuid,before_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT FROM public.users WHERE id=actor AND status='ACTIVE') THEN RAISE EXCEPTION 'ACCOUNT_DELETING'; END IF;
 IF before_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.export_jobs WHERE id=before_id AND user_id=actor) THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
 RETURN coalesce((SELECT jsonb_agg(public.jobix_export_status(actor,id) ORDER BY created_at DESC,id DESC)
 FROM (SELECT id,created_at FROM public.export_jobs WHERE user_id=actor AND
 (before_id IS NULL OR (created_at,id)<(SELECT created_at,id FROM public.export_jobs WHERE id=before_id AND user_id=actor))
 ORDER BY created_at DESC,id DESC LIMIT 25) q),'[]');
END $$;
REVOKE ALL ON FUNCTION public.jobix_export_immutable(),public.jobix_export_valid(jsonb),
 public.jobix_export_source(uuid,uuid),public.jobix_export_replay(uuid,uuid,text),
 public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid),
 public.jobix_export_status(uuid,uuid),public.jobix_export_history(uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.jobix_export_source(uuid,uuid),public.jobix_export_replay(uuid,uuid,text),
 public.jobix_export_create(uuid,uuid,uuid,uuid,bigint,bigint,text,text,text,text,text,uuid),
 public.jobix_export_status(uuid,uuid),public.jobix_export_history(uuid,uuid) TO jobix_export_gateway;
COMMIT;
