#!/usr/bin/env python3
"""Explicit additive core-shell migration on the existing isolated dev database."""
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
    parser.add_argument("--bootstrap-patch", action="store_true")
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

    if sql("SELECT to_regprocedure('public.claim_registration_entry()') IS NOT NULL;") != "t":
        raise RuntimeError("Existing first-slice Foundation is required.")
    existing = sql("SELECT to_regclass('public.credit_accounts') IS NOT NULL;")
    if existing != "f" and not args.bootstrap_patch:
        raise RuntimeError("Credits schema already exists; refusing to overwrite it.")
    if existing != "t" and args.bootstrap_patch:
        raise RuntimeError("Credits schema is required before its metadata patch.")
    policy_query = """SELECT jsonb_build_object('minimum',minimum_supported_version,
        'recommended',recommended_version,'policy',policy_version, 'configuration',configuration)
        FROM public.app_policies WHERE policy_key='mobile';"""
    before = sql(policy_query)
    if not before:
        raise RuntimeError("Operational startup policy is missing; no bypass attempted.")
    if not args.bootstrap_patch:
        sql((APP / "supabase/migrations/202610030004_core_shell_credits.sql").read_text())
    sql((APP / "supabase/migrations/202610030005_bootstrap_envelope.sql").read_text())
    if sql(policy_query) != before:
        raise RuntimeError("Unexpected policy difference requires administrator review.")
    checks = sql("""BEGIN READ ONLY;
SELECT count(*)=2 AND bool_and(relrowsecurity) FROM pg_class
 WHERE oid IN ('public.credit_accounts'::regclass,'public.credit_transactions'::regclass);
SELECT NOT has_table_privilege('authenticated','public.credit_accounts','INSERT,UPDATE,DELETE');
SELECT NOT has_table_privilege('authenticated','public.credit_transactions','INSERT,UPDATE,DELETE');
SELECT has_function_privilege('authenticated','public.app_bootstrap(text,text)','EXECUTE')
 AND NOT has_function_privilege('anon','public.app_bootstrap(text,text)','EXECUTE');
ROLLBACK;""").splitlines()
    if checks != ["t", "t", "t", "t"]:
        raise RuntimeError("Core schema security readback failed.")
    print("PASS: additive core-shell Credits/bootstrap migration applied to isolated dev.")
    print("PASS: RLS, client-write denial, protected RPC and unchanged startup policy.")
    print("Historical accounts: zero initial wallet; no retroactive signup grant.")
    print("New accounts: atomic +5 signup grant. Staging/production untouched.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error) if isinstance(error, RuntimeError) else "Protected dev migration failed."
        print("FAIL: " + message, file=sys.stderr)
        sys.exit(1)