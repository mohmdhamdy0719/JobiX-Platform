#!/usr/bin/env python3
"""Apply only the explicitly approved development mobile-policy configuration."""
import argparse
import json
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
        raise RuntimeError("Explicit isolated-dev configuration permission required.")
    config = json.loads((APP / "config/dev.local.json").read_text())
    if (config.get("APP_ENV") != "dev" or
            config.get("SUPABASE_URL", "").rstrip("/") !=
            "https://" + DEV_REF + ".supabase.co"):
        raise RuntimeError("Refusing unapproved public development configuration.")
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
    statement = (APP / "supabase/config/dev_mobile_policy.sql").read_text()
    statement += """
BEGIN READ ONLY;
SELECT minimum_supported_version = '1.0.0'
   AND recommended_version = '1.0.0' AND policy_version = '1'
FROM public.app_policies WHERE policy_key = 'mobile';
SELECT relrowsecurity FROM pg_class WHERE oid='public.app_policies'::regclass;
ROLLBACK;
"""
    result = subprocess.run(
        ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"],
        input=statement, env=environment, text=True, capture_output=True, timeout=45,
    )
    if result.returncode:
        raise RuntimeError("Protected dev configuration failed; no sensitive details forwarded.")
    checks = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if checks[-2:] != ["t", "t"]:
        raise RuntimeError("Dev policy readback or existing RLS check failed.")
    print("PASS: dev mobile policy 1.0.0 / 1.0.0 / 1; RLS retained.")
    print("Development only. No schema, staging or production changes.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error) if isinstance(error, RuntimeError) else "Protected dev configuration failed."
        print("FAIL: " + message, file=sys.stderr)
        sys.exit(1)