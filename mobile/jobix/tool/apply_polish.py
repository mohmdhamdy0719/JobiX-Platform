"""Guarded dev-only migration/test runner. Never prints credentials or row data."""
import argparse
import os
from pathlib import Path
import subprocess
import urllib.parse

APP = Path(__file__).resolve().parents[1]
MIGRATIONS = [
    "202610050008_profile_polish.sql",
    "202610050009_resume_configuration.sql",
    "202610050010_credits_ai_foundation.sql",
]

def run(apply=False):
    uri = urllib.parse.urlparse(os.environ["JOBIX_DEV_DATABASE_URL"])
    user = urllib.parse.unquote(uri.username or "")
    assert ((uri.hostname or "").endswith(".pooler.supabase.com")
            and user.endswith(".lmouxhbjhtqdtiqijcee")
            and uri.port == 5432 and uri.path == "/postgres"), "Dev guard failed"
    ca = next((APP.parent.parent / "attached_assets").glob("*prod-ca*.crt"))
    env = os.environ.copy()
    env.update(PGHOST=uri.hostname, PGPORT="5432", PGDATABASE="postgres",
        PGUSER=user, PGPASSWORD=urllib.parse.unquote(uri.password or ""),
        PGSSLMODE="verify-full", PGSSLROOTCERT=str(ca.resolve()),
        PGCONNECT_TIMEOUT="15", PGOPTIONS="-c statement_timeout=20000")
    def sql(text):
        result = subprocess.run(
            ["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"],
            input=text, env=env, text=True, capture_output=True, timeout=90)
        if result.returncode:
            # Migration/test input is code, never user rows; only SQLSTATE
            # and static diagnostic category may leave this process.
            import re
            code = re.search(r"ERROR:\s+([^\n]+)", result.stderr)
            safe = code.group(1) if code else "SQL failure"
            if any(word in safe for word in ("syntax error", "does not exist", "ambiguous", "assertion")):
                raise RuntimeError(safe)
            raise RuntimeError("Protected SQL failed; response details suppressed")
        return result.stdout.strip()
    exists = sql("SELECT to_regclass('public.profile_extras') IS NOT NULL;") == "t"
    statements = []
    if not exists:
        for name in MIGRATIONS:
            text = (APP / "supabase/migrations" / name).read_text().strip()
            assert text.startswith("BEGIN;") and text.endswith("COMMIT;")
            statements.append(text[len("BEGIN;"):-len("COMMIT;")])
    checks = (APP / "supabase/tests/polish_foundation.sql").read_text()
    sql("BEGIN;\n" + "\n".join(statements) + "\n" + checks + "\nROLLBACK;")
    print("PASS: protected development transaction, profile extras, structural validation, resume config, Credits and allowance checks; rolled back fixtures.")
    if apply and not exists:
        sql("BEGIN;\n" + "\n".join(statements) + "\nCOMMIT;")
        print("PASS: additive migrations applied to authorized development only.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply-isolated-dev", action="store_true")
    args = parser.parse_args()
    try:
        run(args.apply_isolated_dev)
    except Exception as error:
        print("FAIL:", str(error) if isinstance(error, (RuntimeError, AssertionError)) else type(error).__name__)
        raise SystemExit(1)
