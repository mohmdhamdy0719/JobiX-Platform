#!/usr/bin/env python3
"""Opt-in live Foundation verification. Never deploy the local auth fixture."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

APP = Path(__file__).resolve().parents[1]
AUTHORIZED_REF = "lmouxhbjhtqdtiqijcee"


class VerificationError(Exception):
    """Only fixed, credential-free messages may reach the console."""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-temporary-dev-fixtures", action="store_true")
    parser.add_argument("--ca-file", required=True, type=Path)
    args = parser.parse_args()
    if not args.allow_temporary_dev_fixtures:
        raise VerificationError("Temporary isolated-dev fixture permission required.")
    config = json.loads((APP / "config/dev.local.json").read_text())
    base = f"https://{AUTHORIZED_REF}.supabase.co"
    if config["SUPABASE_URL"].rstrip("/") != base or config["APP_ENV"] != "dev":
        raise VerificationError("Unauthorized public project configuration.")
    connection = urllib.parse.urlparse(os.environ["JOBIX_DEV_DATABASE_URL"])
    username = urllib.parse.unquote(connection.username or "")
    if not (
        (connection.hostname or "").endswith(".pooler.supabase.com")
        and username.endswith("." + AUTHORIZED_REF)
        and connection.port == 5432
        and connection.path == "/postgres"
    ):
        raise VerificationError("Unauthorized administrative project target.")
    ca = args.ca_file.resolve(strict=True)
    db_env = os.environ.copy()
    db_env.update(
        PGHOST=connection.hostname,
        PGPORT="5432",
        PGUSER=username,
        PGPASSWORD=urllib.parse.unquote(connection.password or ""),
        PGDATABASE="postgres",
        PGSSLMODE="verify-full",
        PGSSLROOTCERT=str(ca),
        PGCONNECT_TIMEOUT="15",
        PGOPTIONS="-c statement_timeout=15000",
    )

    def sql(statement):
        result = subprocess.run(
            ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"],
            input=statement, env=db_env, capture_output=True, text=True, timeout=35,
        )
        if result.returncode:
            print("FAIL: Flutter live-check process exit " + str(result.returncode),
                  flush=True)
            raise VerificationError("Dev SQL step failed; connection details suppressed.")
        return result.stdout.strip()

    def auth(path, body, token=None):
        headers = {"apikey": config["SUPABASE_CLIENT_KEY"],
                   "Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        request = urllib.request.Request(
            base + "/auth/v1/" + path, headers=headers, method="POST",
            data=json.dumps(body).encode(),
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read() or b"{}")

    sessions = []
    ids = []
    marker = "foundation-verification-" + uuid.uuid4().hex
    created = datetime.datetime.now(datetime.timezone.utc).isoformat()
    fixture_attempted = False
    cleanup_failed = False
    try:
        for account in ("A", "B"):
            session = auth("token?grant_type=password", {
                "email": os.environ["JOBIX_DEV_TEST_EMAIL_" + account],
                "password": os.environ["JOBIX_DEV_TEST_PASSWORD_" + account],
            })
            sessions.append(session)
            ids.append(str(uuid.UUID(session["user"]["id"])))
            if not session["user"].get("email_confirmed_at"):
                raise VerificationError("A disposable account is not email-confirmed.")
        if len(set(ids)) != 2:
            raise VerificationError("Two distinct disposable Auth identities required.")
        fixture_attempted = True
        sql(f"""
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('jobix_foundation_live_verification'));
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM public.users WHERE id IN ('{ids[0]}','{ids[1]}'))
     OR EXISTS(SELECT 1 FROM public.app_policies WHERE policy_key='mobile') THEN
    RAISE EXCEPTION 'Refusing to overwrite existing Foundation data';
  END IF;
END $$;
INSERT INTO public.users(id,created_at) VALUES
  ('{ids[0]}','{created}'), ('{ids[1]}','{created}');
INSERT INTO public.app_policies
  (policy_key,minimum_supported_version,recommended_version,policy_version,configuration)
VALUES ('mobile','2.0.0',NULL,'{marker}','{{"private_test_field":"must_not_project"}}');
COMMIT;
""")
        print("PASS: isolated-dev fixtures created without overwriting data", flush=True)
        child_env = os.environ.copy()
        child_env["JOBIX_RUN_LIVE_FOUNDATION"] = AUTHORIZED_REF
        # The Flutter test receives public config and account credentials only.
        child_env.pop("JOBIX_DEV_DATABASE_URL", None)
        child_env.pop("PGPASSWORD", None)
        result = subprocess.run(
            ["flutter", "test", "--no-pub", "--reporter", "expanded",
             "tool/live_supabase_test.dart"],
            cwd=APP, env=child_env, capture_output=True, text=True, timeout=180,
        )
        # Do not forward SDK/test exceptions: they may contain account metadata.
        for line in result.stdout.splitlines():
            if line.startswith(("LIVE PASS: ", "LIVE FAIL: ")):
                print(line, flush=True)
        if result.returncode:
            raise VerificationError("Live SDK checks failed; sensitive output suppressed.")
    finally:
        if fixture_attempted:
            try:
                sql(f"""
BEGIN;
DELETE FROM public.app_policies
 WHERE policy_key='mobile' AND policy_version='{marker}';
DELETE FROM public.users
 WHERE id IN ({','.join(repr(i) for i in ids)}) AND created_at='{created}';
COMMIT;
""")
                remaining = sql(f"""
SELECT count(*) FROM (
 SELECT 1 FROM public.app_policies WHERE policy_version='{marker}'
 UNION ALL SELECT 1 FROM public.users
 WHERE id IN ({','.join(repr(i) for i in ids)}) AND created_at='{created}'
) AS fixtures;
""")
                if remaining != "0":
                    raise VerificationError("Temporary fixture cleanup not confirmed.")
                print("PASS: temporary user/policy fixtures removed", flush=True)
            except Exception:
                cleanup_failed = True
                print("FAIL: fixture cleanup requires privileged attention.", flush=True)
                print("Non-secret fixture marker: " + marker, flush=True)
                print("Non-secret user-row creation marker: " + created, flush=True)
        for session in sessions:
            try:
                auth("logout?scope=local", {}, session["access_token"])
            except Exception:
                cleanup_failed = True
                print("FAIL: setup session revocation not confirmed.", flush=True)
        if cleanup_failed:
            raise VerificationError("Cleanup incomplete; do not claim verification passed.")
    print("PASS: real-session Foundation verification complete; native checks remain open.")


if __name__ == "__main__":
    try:
        main()
    except VerificationError as error:
        print("BLOCKED: " + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        print("BLOCKED: live verification failed; sensitive details suppressed.",
              file=sys.stderr)
        sys.exit(1)