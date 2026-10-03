#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/jobix-rls.XXXXXX)"
trap 'pg_ctl -D "$work/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
initdb -D "$work/data" --username=runner --auth=trust --no-locale >/dev/null
mkdir "$work/socket"
pg_ctl -D "$work/data" -l "$work/server.log" \
  -o "-k $work/socket -p 55439 -c listen_addresses=''" start >/dev/null
psql -X -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
  -f supabase/tests/local_auth_fixture.sql \
  -f supabase/migrations/202610030001_foundation.sql \
  -f supabase/tests/rls.sql \
  -f supabase/migrations/202610030002_first_vertical_slice.sql \
  -f supabase/migrations/202610030003_registration_entry.sql \
  -f supabase/tests/first_slice.sql \
  -f supabase/tests/core_mvp_setup.sql \
  -f supabase/migrations/202610030004_core_shell_credits.sql \
  -f supabase/migrations/202610030005_bootstrap_envelope.sql \
  -f supabase/tests/core_shell_credits.sql
echo "PASS: Foundation, first slice, core bootstrap/credits/RLS (disposable PostgreSQL, not live Supabase)"