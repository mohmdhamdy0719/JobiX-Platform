#!/usr/bin/env python3
"""Owner-approved, zero-credit provisioning of only configured isolated-dev actors."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.parse
import uuid

APP = Path(__file__).resolve().parents[1]
DEV_REF = "lmouxhbjhtqdtiqijcee"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provision-missing-with-zero-credits", action="store_true")
    parser.add_argument("--ca-file", required=True, type=Path)
    args = parser.parse_args()
    if not args.provision_missing_with_zero_credits:
        raise RuntimeError("Explicit approved zero-credit provisioning is required.")
    connection = urllib.parse.urlparse(os.environ["JOBIX_DEV_DATABASE_URL"])
    username = urllib.parse.unquote(connection.username or "")
    if not ((connection.hostname or "").endswith(".pooler.supabase.com")
            and username.endswith("." + DEV_REF)
            and connection.port == 5432 and connection.path == "/postgres"):
        raise RuntimeError("Refusing a database outside the authorized isolated development project.")
    environment = os.environ.copy()
    environment.update(
        PGHOST=connection.hostname, PGPORT="5432", PGDATABASE="postgres",
        PGUSER=username, PGPASSWORD=urllib.parse.unquote(connection.password or ""),
        PGSSLMODE="verify-full", PGSSLROOTCERT=str(args.ca_file.resolve(strict=True)),
        PGCONNECT_TIMEOUT="15",
        PGOPTIONS="-c statement_timeout=20000 -c lock_timeout=5000",
    )
    for key in list(environment):
        if key.startswith("JOBIX_DEV_"):
            environment.pop(key)

    def sql(statement):
        result = subprocess.run(
            ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"],
            input=statement, env=environment, text=True, capture_output=True, timeout=45,
        )
        if result.returncode:
            raise RuntimeError("Protected provisioning SQL failed; sensitive diagnostics suppressed.")
        return result.stdout.strip()

    # No email, credential, UUID or raw database response is printed or persisted.
    actors = []
    for name in ("JOBIX_DEV_TEST_EMAIL_A", "JOBIX_DEV_TEST_EMAIL_B"):
        email = os.environ[name].strip()
        if not email or len(email) > 320:
            raise RuntimeError("A configured test actor is invalid.")
        literal = "'" + email.replace("'", "''") + "'"
        rows = sql("SELECT id::text FROM auth.users WHERE lower(email)=lower(" + literal + ");").splitlines()
        if len(rows) != 1:
            raise RuntimeError("A configured test actor is missing or ambiguous; no Auth account was created.")
        actors.append(str(uuid.UUID(rows[0])))
    if actors[0] == actors[1]:
        raise RuntimeError("Two distinct configured development test actors are required.")
    policy_query = """SELECT jsonb_build_object('minimum',minimum_supported_version,
      'recommended',recommended_version,'policy',policy_version,'configuration',configuration)
      FROM public.app_policies WHERE policy_key='mobile';"""
    before = sql(policy_query)
    if not before:
        raise RuntimeError("Startup policy is missing; no bypass attempted.")
    setup = "SELECT set_config('jobix.authorized_dev_project','" + DEV_REF + "',false);\n"
    setup += "SELECT set_config('jobix.dev_backfill_actor_ids','" + ",".join(actors) + "',false);\n"
    result = sql(setup + (APP / "supabase/maintenance/provision_dev_test_accounts_zero.sql").read_text())
    match = re.search(r"BACKFILL_RESULT:(\d+):(\d+)", result)
    if not match or sum(map(int, match.groups())) != 2:
        raise RuntimeError("Provisioning outcome could not be confirmed; do not retry blindly.")
    if sql(policy_query) != before:
        raise RuntimeError("Unexpected startup-policy difference requires administrator review.")
    print("PASS: isolated-development provisioning completed.")
    print("Missing actors provisioned: " + match.group(1))
    print("Existing actors left unchanged: " + match.group(2))
    print("New application accounts have zero Credits and no retroactive signup ledger entry.")
    print("PASS: signup trigger restored and startup policy unchanged; staging/production untouched.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error) if isinstance(error, RuntimeError) else "Protected provisioning failed."
        print("FAIL: " + message, file=sys.stderr)
        sys.exit(1)