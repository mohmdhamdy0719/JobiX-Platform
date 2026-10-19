\set ON_ERROR_STOP on

DO $test$
DECLARE
  institution_count integer;
  field_count integer;
  institution_types integer;
BEGIN
  IF to_regclass('public.education_institution_catalog') IS NULL
     OR to_regclass('public.study_field_catalog') IS NULL THEN
    RAISE EXCEPTION 'education catalog tables are missing';
  END IF;

  SELECT count(*), count(DISTINCT institution_type)
    INTO institution_count, institution_types
    FROM public.education_institution_catalog;
  SELECT count(*) INTO field_count FROM public.study_field_catalog;

  IF institution_count < 100 OR institution_types < 7 OR field_count < 50 THEN
    RAISE EXCEPTION 'curated seed incomplete: institutions %, types %, fields %',
      institution_count, institution_types, field_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.education_institution_catalog
    WHERE catalog_version <> 1
      OR source_name = '' OR source_url = '' OR source_note = ''
      OR source_checked_on IS NULL
  ) OR EXISTS (
    SELECT 1 FROM public.study_field_catalog
    WHERE catalog_version <> 1
      OR source_name = '' OR source_url = '' OR source_note = ''
      OR source_checked_on IS NULL
  ) THEN
    RAISE EXCEPTION 'catalog row is missing version or provenance';
  END IF;

  IF EXISTS (
    SELECT lower(alias) AS normalized_alias
    FROM (
      SELECT institution_key, unnest(aliases_en) AS alias
      FROM public.education_institution_catalog
    ) aliases
    GROUP BY normalized_alias
    HAVING count(DISTINCT institution_key) > 1
  ) THEN
    RAISE EXCEPTION 'English institution aliases ambiguously identify multiple institutions';
  END IF;

  IF NOT (SELECT relrowsecurity FROM pg_class
          WHERE oid = 'public.education_institution_catalog'::regclass)
     OR NOT (SELECT relrowsecurity FROM pg_class
             WHERE oid = 'public.study_field_catalog'::regclass) THEN
    RAISE EXCEPTION 'catalog RLS is not enabled';
  END IF;

  IF NOT has_table_privilege(
       'authenticated', 'public.education_institution_catalog', 'SELECT')
     OR NOT has_table_privilege(
       'authenticated', 'public.study_field_catalog', 'SELECT')
     OR has_table_privilege(
       'authenticated', 'public.education_institution_catalog', 'INSERT')
     OR has_table_privilege(
       'authenticated', 'public.education_institution_catalog', 'UPDATE')
     OR has_table_privilege(
       'authenticated', 'public.education_institution_catalog', 'DELETE')
     OR has_table_privilege(
       'authenticated', 'public.study_field_catalog', 'INSERT')
     OR has_table_privilege(
       'authenticated', 'public.study_field_catalog', 'UPDATE')
     OR has_table_privilege(
       'authenticated', 'public.study_field_catalog', 'DELETE')
     OR has_table_privilege(
       'anon', 'public.education_institution_catalog', 'SELECT')
     OR has_table_privilege(
       'anon', 'public.study_field_catalog', 'SELECT')
     OR has_table_privilege(
       'service_role', 'public.education_institution_catalog', 'INSERT')
     OR has_table_privilege(
       'service_role', 'public.education_institution_catalog', 'UPDATE')
     OR has_table_privilege(
       'service_role', 'public.education_institution_catalog', 'DELETE')
     OR has_table_privilege(
       'service_role', 'public.study_field_catalog', 'INSERT')
     OR has_table_privilege(
       'service_role', 'public.study_field_catalog', 'UPDATE')
     OR has_table_privilege(
       'service_role', 'public.study_field_catalog', 'DELETE') THEN
    RAISE EXCEPTION 'catalog grants do not enforce authenticated read-only access';
  END IF;
END
$test$;

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000001',
  true
);
DO $authenticated_read$
DECLARE
  institution_count integer;
  field_count integer;
BEGIN
  SELECT count(*) INTO institution_count
    FROM public.education_institution_catalog;
  SELECT count(*) INTO field_count FROM public.study_field_catalog;
  IF institution_count < 100 OR field_count < 50 THEN
    RAISE EXCEPTION 'authenticated SELECT did not return the curated catalogs';
  END IF;
END
$authenticated_read$;
ROLLBACK;

SELECT 'institution_catalog_rows=' || count(*)
  FROM public.education_institution_catalog;
SELECT 'study_field_catalog_rows=' || count(*) FROM public.study_field_catalog;
\echo PASS: versioned catalog seed, bilingual source metadata, authenticated SELECT-only RLS
