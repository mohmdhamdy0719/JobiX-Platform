#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/jobix-rls.XXXXXX)"
trap 'pg_ctl -D "$work/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
initdb -D "$work/data" --username=runner --auth=trust --no-locale --encoding=UTF8 >/dev/null
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
  -f supabase/tests/core_shell_credits.sql \
  -f supabase/tests/dev_backfill_setup.sql \
  -f supabase/maintenance/provision_dev_test_accounts_zero.sql \
  -f supabase/maintenance/provision_dev_test_accounts_zero.sql \
  -f supabase/tests/dev_backfill.sql
psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
  -f supabase/migrations/202610040006_profile_text.sql -f supabase/tests/profile_text.sql \
  -f supabase/migrations/202610050007_profile_sections.sql -f supabase/tests/profile_sections.sql
if PGOPTIONS="-c jobix.authorized_dev_project=lmouxhbjhtqdtiqijcee -c jobix.dev_backfill_actor_ids=61000000-0000-0000-0000-000000000001,69000000-0000-0000-0000-000000000099" \
  psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
    -f supabase/maintenance/provision_dev_test_accounts_zero.sql >/dev/null 2>&1; then
  echo "FAIL: missing Auth actor was accepted by maintenance" >&2
  exit 1
fi
psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
  -f supabase/tests/dev_backfill_rollback.sql
echo "PASS: Foundation, first slice, core bootstrap/credits/RLS (disposable PostgreSQL, not live Supabase)"
psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
  -f supabase/migrations/202610050008_profile_polish.sql \
  -f supabase/migrations/202610050009_resume_configuration.sql \
  -f supabase/migrations/202610050010_credits_ai_foundation.sql \
  -f supabase/tests/polish_foundation.sql \
  -f supabase/tests/volunteer_before_migration.sql \
  -f supabase/migrations/202610080011_volunteer_experience.sql \
  -f supabase/tests/volunteer_experience.sql
echo "PASS: Resume foundation and non-scoring Volunteer CRUD/RLS/migration regressions (disposable PostgreSQL)"
psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
  -f supabase/migrations/202610080012_resume_export_foundation.sql \
  -f supabase/migrations/202610080013_resume_export_lifecycle.sql \
  -f supabase/migrations/202610080014_resume_configuration_concurrency.sql \
  -f supabase/migrations/202610080015_resume_export_local_hardening.sql \
  -f supabase/migrations/202610080016_resume_export_cleanup_hooks.sql \
  -f supabase/migrations/202610080017_resume_export_deletion.sql \
  -f supabase/migrations/202610080018_resume_export_admission.sql \
  -f supabase/tests/resume_export.sql
psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
  -f supabase/tests/resume_export_admission.sql \
  -f supabase/tests/resume_export_recovery.sql \
  -f supabase/tests/resume_export_deletion.sql
echo "PASS: Disabled-by-default private export/credits/snapshot/lifecycle/concurrency (disposable PostgreSQL)"
if [[ -f backend/pdf/test/integration.mjs ]]; then
  JOBIX_DISPOSABLE_PG_SOCKET="$work/socket" node backend/pdf/test/integration.mjs
fi