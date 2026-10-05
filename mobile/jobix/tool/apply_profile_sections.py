#!/usr/bin/env python3
"""Explicit additive Career Profile sections migration on the existing isolated dev database."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import urllib.parse

APP = Path(__file__).resolve().parents[1]
DEV_REF = "lmouxhbjhtqdtiqijcee"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply-isolated-dev", action="store_true")
    parser.add_argument("--ca-file", required=True, type=Path)
    args = parser.parse_args()
    if not args.apply_isolated_dev:
        raise RuntimeError("Explicit isolated-dev migration permission required.")
    connection = urllib.parse.urlparse(os.environ["JOBIX_DEV_DATABASE_URL"])
    username = urllib.parse.unquote(connection.username or "")
    if not ((connection.hostname or "").endswith(".pooler.supabase.com")
            and username.endswith("." + DEV_REF)
            and connection.port == 5432 and connection.path == "/postgres"):
        raise RuntimeError("Refusing a database outside the authorized isolated dev.")
    environment = os.environ.copy()
    environment.update(
        PGHOST=connection.hostname, PGPORT="5432", PGDATABASE="postgres",
        PGUSER=username, PGPASSWORD=urllib.parse.unquote(connection.password or ""),
        PGSSLMODE="verify-full", PGSSLROOTCERT=str(args.ca_file.resolve(strict=True)),
        PGCONNECT_TIMEOUT="15", PGOPTIONS="-c statement_timeout=20000",
    )
    environment.pop("JOBIX_DEV_DATABASE_URL", None)

    def sql(statement):
        result = subprocess.run(
            ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"],
            input=statement, env=environment, text=True,
            capture_output=True, timeout=45,
        )
        if result.returncode:
            raise RuntimeError("Protected development SQL failed; sensitive details suppressed.")
        return result.stdout.strip()

    if sql("SELECT to_regclass('public.profile_summaries') IS NOT NULL;") != "t":
        raise RuntimeError("The approved text slice is required first.")
    if sql("SELECT to_regclass('public.profile_experiences') IS NULL;") != "t":
        raise RuntimeError("Section schema already exists; refusing to overwrite it.")
    policy_query = "SELECT policy_version FROM public.app_policies WHERE policy_key='mobile';"
    before = sql(policy_query)
    if not before:
        raise RuntimeError("Operational startup policy is missing; no bypass attempted.")
    sql((APP / "supabase/migrations/202610050007_profile_sections.sql").read_text())
    if sql(policy_query) != before:
        raise RuntimeError("Unexpected policy difference requires administrator review.")
    tables = ["profile_experiences", "profile_education", "profile_certifications",
              "profile_achievements", "profile_projects", "profile_skills",
              "profile_languages", "profile_optional_sections"]
    for table in tables:
        ok = sql(f"""SELECT (SELECT relrowsecurity FROM pg_class WHERE oid='public.{table}'::regclass)
 AND NOT has_table_privilege('authenticated','public.{table}','INSERT,UPDATE,DELETE')
 AND NOT has_table_privilege('anon','public.{table}','SELECT');""")
        if ok != "t":
            raise RuntimeError("Section security readback failed.")
    ok = sql("""SELECT NOT has_function_privilege('anon','public.profile_mutate(uuid,uuid,bigint,jsonb)','EXECUTE')
 AND has_function_privilege('authenticated','public.profile_mutate(uuid,uuid,bigint,jsonb)','EXECUTE')
 AND NOT has_function_privilege('authenticated','public.jobix_profile_text_snapshot(uuid)','EXECUTE')
 AND (SELECT bool_and(completeness_algorithm_version='core-profile-v2') FROM public.career_profiles);""")
    if ok != "t":
        raise RuntimeError("Mutation security or completeness readback failed.")
    print("PASS: isolated-dev section migration, RLS/write-denial readback, recomputed completeness;")
    print("startup policy unchanged. Staging/production untouched.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error) if isinstance(error, RuntimeError) else "Protected dev migration failed."
        print("FAIL: " + message, file=sys.stderr)
        sys.exit(1)
