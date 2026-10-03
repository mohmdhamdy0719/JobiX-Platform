#!/usr/bin/env python3
"""Explicit, TLS-verified first-slice migration on the authorized isolated dev only."""
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
    parser.add_argument("--entry-patch", action="store_true")
    parser.add_argument("--ca-file", required=True, type=Path)
    args = parser.parse_args()
    if not args.apply_isolated_dev:
        raise RuntimeError("Explicit isolated-dev migration permission required.")
    # Credential stays inside this process/psql's environment, never output or argv.
    connection = urllib.parse.urlparse(os.environ["JOBIX_DEV_DATABASE_URL"])
    username = urllib.parse.unquote(connection.username or "")
    if not ((connection.hostname or "").endswith(".pooler.supabase.com")
            and username.endswith("." + DEV_REF)
            and connection.port == 5432 and connection.path == "/postgres"):
        raise RuntimeError("Refusing a target other than the authorized isolated dev.")
    environment = os.environ.copy()
    environment.update(
        PGHOST=connection.hostname, PGPORT="5432", PGDATABASE="postgres",
        PGUSER=username, PGPASSWORD=urllib.parse.unquote(connection.password or ""),
        PGSSLMODE="verify-full", PGSSLROOTCERT=str(args.ca_file.resolve(strict=True)),
        PGCONNECT_TIMEOUT="15", PGOPTIONS="-c statement_timeout=20000",
    )

    def sql(statement):
        result = subprocess.run(
            ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"],
            input=statement, env=environment, text=True, capture_output=True, timeout=45,
        )
        if result.returncode:
            # No raw connection, SQL/SDK errors, credentials or account data are forwarded.
            error = result.stderr.lower()
            if "certificate" in error or "ssl" in error:
                raise RuntimeError("Verified TLS connection failed; no insecure fallback attempted.")
            if "resolve" in error or "timeout" in error or "network" in error:
                raise RuntimeError("Isolated-dev database connection unavailable.")
            raise RuntimeError("Isolated-dev SQL check failed; sensitive diagnostics suppressed.")
        return result.stdout.strip()

    existing = sql("SELECT to_regclass('public.career_profiles') IS NOT NULL;")
    if existing != "f" and not args.entry_patch:
        raise RuntimeError("Slice tables already exist; refusing to overwrite or assume their schema.")
    if sql("SELECT to_regclass('public.users') IS NOT NULL;") != "t":
        raise RuntimeError("Authorized Foundation schema is missing; refusing to substitute it.")
    if args.entry_patch and existing != "t":
        raise RuntimeError("First-slice schema is required before its entry patch.")
    if sql("SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='first_profile_entry_pending');") != "f":
        raise RuntimeError("Entry patch already exists; refusing to overwrite it.")
    if not args.entry_patch:
        sql((APP / "supabase/migrations/202610030002_first_vertical_slice.sql").read_text())
    sql((APP / "supabase/migrations/202610030003_registration_entry.sql").read_text())
    print("PASS: first-slice migration applied to isolated dev only", flush=True)
    sql("""
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM auth.users WHERE id IN (
  '00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012'))
 THEN RAISE EXCEPTION 'Fixture identifier already exists; refusing to touch it'; END IF;
END $$;
""" + (APP / "supabase/tests/first_slice.sql").read_text())
    print("PASS: real isolated-dev PostgreSQL roles, auth.uid, RLS and RPC retry/bootstrap checks", flush=True)
    print("PASS: rollback-only fixtures removed; operational policy and staging/production untouched",
          flush=True)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print("FAIL: " + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        print("FAIL: protected dev-migration process failed; sensitive diagnostics suppressed.",
              file=sys.stderr)
        sys.exit(1)