"""Approved dev-only Volunteer rollout. No credentials or user rows in output."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.parse

APP = Path(__file__).resolve().parents[1]
PROJECT = "lmouxhbjhtqdtiqijcee"
MIGRATION = APP / "supabase/migrations/202610080011_volunteer_experience.sql"


class ProtectedFailure(Exception):
    """Static diagnostic only; never relay connection strings or server rows."""


def body(path, name):
    text = path.read_text()
    match = re.search(
        rf"CREATE(?: OR REPLACE)? FUNCTION public\.{name}\(.*?AS \$\$(.*?)\$\$;",
        text, re.S,
    )
    if not match:
        raise ProtectedFailure("LOCAL_CONTRACT_MISSING")
    return re.sub(r"\s+", "", match.group(1))


def run(apply):
    uri = urllib.parse.urlparse(os.environ["JOBIX_DEV_DATABASE_URL"])
    user = urllib.parse.unquote(uri.username or "")
    if not (
        uri.scheme in ("postgres", "postgresql")
        and (uri.hostname or "").endswith(".pooler.supabase.com")
        and user == f"postgres.{PROJECT}"
        and uri.port == 5432
        and uri.path == "/postgres"
        and uri.password
    ):
        raise ProtectedFailure("DEV_CONNECTION_GUARD_FAILED")
    certificates = list((APP.parent.parent / "attached_assets").glob("*prod-ca*.crt"))
    if len(certificates) != 1:
        raise ProtectedFailure("PUBLIC_CA_MISSING_OR_AMBIGUOUS")
    env = os.environ.copy()
    env.update(
        PGHOST=uri.hostname, PGPORT="5432", PGDATABASE="postgres", PGUSER=user,
        PGPASSWORD=urllib.parse.unquote(uri.password),
        PGSSLMODE="verify-full", PGSSLROOTCERT=str(certificates[0].resolve()),
        PGCONNECT_TIMEOUT="15",
        PGOPTIONS="-c statement_timeout=20000 -c lock_timeout=5000",
    )

    def sql(text):
        result = subprocess.run(
            ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1",
             "-v", "VERBOSITY=sqlstate"],
            input=text, env=env, text=True, capture_output=True, timeout=100,
        )
        if result.returncode:
            code = re.search(r"ERROR:\s+([0-9A-Z]{5})\b", result.stderr)
            if code:
                raise ProtectedFailure(f"SQLSTATE_{code.group(1)}")
            diagnostic = result.stderr.lower()
            if "certificate" in diagnostic:
                raise ProtectedFailure("TLS_CERTIFICATE_VERIFICATION_FAILED")
            if "password authentication failed" in diagnostic:
                raise ProtectedFailure("DATABASE_AUTHENTICATION_FAILED")
            raise ProtectedFailure("PROTECTED_DATABASE_CONNECTION_OR_QUERY_FAILED")
        return result.stdout.strip()

    # Read only: canonical body equality guards against changing an unexpected
    # installation. Existing schema/algorithm are never repaired by this tool.
    installed = json.loads(sql("""
SELECT jsonb_build_object(
 'volunteer',to_regclass('public.profile_volunteer_experiences') IS NOT NULL,
 'foundations',to_regclass('public.profile_extras') IS NOT NULL
   AND to_regclass('public.resume_configurations') IS NOT NULL
   AND to_regclass('public.ai_allowance_accounts') IS NOT NULL,
 'score',(SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.jobix_recompute_text_profile(uuid)')),
 'snapshot',(SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.jobix_profile_text_snapshot(uuid)')),
 'mutate',(SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.profile_mutate(uuid,uuid,bigint,jsonb)')),
 'snapshot_previous',(SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.jobix_profile_text_snapshot_pre_volunteer(uuid)')),
 'mutate_previous',(SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.jobix_profile_mutate_pre_volunteer(uuid,uuid,bigint,jsonb)'))
);"""))
    if not installed["foundations"]:
        raise ProtectedFailure("EXISTING_FOUNDATION_PREREQUISITE_MISSING")
    sections = APP / "supabase/migrations/202610050007_profile_sections.sql"
    polish = APP / "supabase/migrations/202610050008_profile_polish.sql"
    expected = {
        "score": body(sections, "jobix_recompute_text_profile"),
        "snapshot": body(sections, "jobix_profile_text_snapshot"),
        "mutate": body(polish, "profile_mutate"),
    }
    if installed["volunteer"]:
        expected.update(
            snapshot_previous=expected["snapshot"],
            mutate_previous=expected["mutate"],
            snapshot=body(MIGRATION, "jobix_profile_text_snapshot"),
            mutate=body(MIGRATION, "profile_mutate"),
        )
    elif installed["snapshot_previous"] or installed["mutate_previous"]:
        raise ProtectedFailure("PARTIAL_OR_UNEXPECTED_INSTALLATION")
    for name, value in expected.items():
        if re.sub(r"\s+", "", installed[name] or "") != value:
            raise ProtectedFailure(f"EXISTING_{name.upper()}_CONTRACT_MISMATCH")
    print("PASS: authorized development target, verify-full TLS and existing contracts.")
    if not apply:
        print("READ ONLY: no schema or data changes.")
        return

    migration = MIGRATION.read_text().strip()
    if not migration.startswith("BEGIN;") or not migration.endswith("COMMIT;"):
        raise ProtectedFailure("MIGRATION_TRANSACTION_GUARD_FAILED")
    statements = "" if installed["volunteer"] else migration[6:-7]
    # Keep the preservation assertion in the same transaction as DDL, and avoid
    # confusing concurrent legitimate app updates with migration side effects.
    preservation = """
LOCK TABLE public.career_profiles,public.ai_allowance_accounts,
 public.credit_accounts,public.idempotency_records IN SHARE MODE;
CREATE TEMP TABLE volunteer_preservation AS
 SELECT
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY id),'[]') FROM public.career_profiles p) AS profiles,
  (SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY user_id),'[]') FROM public.ai_allowance_accounts a) AS ai,
  (SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY user_id),'[]') FROM public.credit_accounts c) AS wallet,
  (SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY user_id,operation_type,idempotency_key),'[]') FROM public.idempotency_records i) AS acknowledgements;
"""
    assertion = """
DO $guard$ BEGIN
 ASSERT (SELECT profiles FROM volunteer_preservation)=
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY id),'[]') FROM public.career_profiles p);
 ASSERT (SELECT ai FROM volunteer_preservation)=
  (SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY user_id),'[]') FROM public.ai_allowance_accounts a);
 ASSERT (SELECT wallet FROM volunteer_preservation)=
  (SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY user_id),'[]') FROM public.credit_accounts c);
 ASSERT (SELECT acknowledgements FROM volunteer_preservation)=
  (SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY user_id,operation_type,idempotency_key),'[]') FROM public.idempotency_records i);
END $guard$;
DROP TABLE volunteer_preservation;
"""
    sql("BEGIN;\n" + preservation + statements + assertion + "\nCOMMIT;")
    print("PASS: Volunteer installed; existing profiles, AI, wallets and acknowledgements preserved.")
    # Real Supabase roles/auth schema, NOT local_auth_fixture.sql. All synthetic
    # Auth/app/credit/test rows remain in one transaction and are rolled back.
    before = (APP / "supabase/tests/volunteer_before_migration.sql").read_text()
    before = before.replace(
        "ASSERT NOT (response->'data' ? 'volunteer_experiences');",
        "ASSERT response->'data'->'volunteer_experiences'='[]'::jsonb;",
    )
    checks = (APP / "supabase/tests/volunteer_experience.sql").read_text()
    sql("BEGIN;\n" + before + "\n" + checks + "\nROLLBACK;")
    print("PASS: live Volunteer CRUD, ownership/RLS, idempotency and scoring/AI invariants; fixtures rolled back.")
    print("NOTE: native Android/WebView/phone acceptance is not verified by SQL.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply-approved-dev", action="store_true")
    arguments = parser.parse_args()
    try:
        run(arguments.apply_approved_dev)
    except ProtectedFailure as error:
        print("BLOCKED:", str(error))
        raise SystemExit(1)
    except Exception as error:
        print("BLOCKED:", type(error).__name__)
        raise SystemExit(1)
