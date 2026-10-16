#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-full}"
if [[ $# -gt 1 || ( "$mode" != "full" && "$mode" != "--resume-export-only" &&
  "$mode" != "--resume-export-cost-unit-only" ) ]]; then
  echo "Usage: $0 [--resume-export-only|--resume-export-cost-unit-only]" >&2
  exit 2
fi
work="$(mktemp -d /tmp/jobix-rls.XXXXXX)"
if [[ "$mode" != "full" ]]; then
  cleanup_focused() {
    local exit_status=$?
    trap - EXIT
    trap '' INT TERM
    if [[ -S "$work/socket/.s.PGSQL.55439" ]] &&
      pg_ctl -D "$work/data" status >/dev/null 2>&1; then
      psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres \
        >/dev/null 2>&1 <<'SQL' || true
DO $cleanup$
BEGIN
  IF to_regclass('public.export_cost_budget_policy') IS NOT NULL THEN
    EXECUTE 'UPDATE public.export_cost_budget_policy
      SET accounting_ready=false,updated_at=clock_timestamp()
      WHERE singleton AND accounting_ready IS DISTINCT FROM false';
  END IF;
END
$cleanup$;
SQL
    fi
    pg_ctl -D "$work/data" stop -m immediate >/dev/null 2>&1 || true
    rm -rf "$work" || true
    exit "$exit_status"
  }
  trap cleanup_focused EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
else
  trap 'pg_ctl -D "$work/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
fi
initdb -D "$work/data" --username=runner --auth=trust --no-locale --encoding=UTF8 >/dev/null
mkdir "$work/socket"
pg_ctl -D "$work/data" -l "$work/server.log" \
  -o "-k $work/socket -p 55439 -c listen_addresses=''" start >/dev/null
if [[ "$mode" != "full" ]]; then
  local_psql=(psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$work/socket" -p 55439 -d postgres)
  socket_file="$work/socket/.s.PGSQL.55439"
  if [[ ! -S "$socket_file" ]] || ! pg_ctl -D "$work/data" status >/dev/null 2>&1; then
    echo "FAIL: disposable PostgreSQL socket/server verification failed" >&2
    exit 1
  fi
  local_target="$("${local_psql[@]}" -Atc "SELECT current_database()='postgres'
    AND current_user='runner' AND inet_server_addr() IS NULL
    AND current_setting('port')='55439' AND current_setting('listen_addresses')=''
    AND current_setting('data_directory')='$work/data'
    AND current_setting('unix_socket_directories')='$work/socket'")"
  if [[ "$local_target" != "t" ]]; then
    echo "FAIL: disposable PostgreSQL identity verification failed" >&2
    exit 1
  fi
  echo "PASS: isolated disposable PostgreSQL verified (Unix socket; TCP disabled)"

  # The export tests create their own synthetic users/profile fixtures. Apply
  # only the schema prerequisites here; omit the unrelated earlier test suites.
  "${local_psql[@]}" \
    -f supabase/tests/local_auth_fixture.sql \
    -f supabase/migrations/202610030001_foundation.sql \
    -f supabase/migrations/202610030002_first_vertical_slice.sql \
    -f supabase/migrations/202610030003_registration_entry.sql \
    -f supabase/migrations/202610030004_core_shell_credits.sql \
    -f supabase/migrations/202610030005_bootstrap_envelope.sql \
    -f supabase/migrations/202610040006_profile_text.sql \
    -f supabase/migrations/202610050007_profile_sections.sql \
    -f supabase/migrations/202610050008_profile_polish.sql \
    -f supabase/migrations/202610050009_resume_configuration.sql \
    -f supabase/migrations/202610050010_credits_ai_foundation.sql \
    -f supabase/migrations/202610080011_volunteer_experience.sql \
    -f supabase/migrations/202610080012_resume_export_foundation.sql \
    -f supabase/migrations/202610080013_resume_export_lifecycle.sql \
    -f supabase/migrations/202610080014_resume_configuration_concurrency.sql \
    -f supabase/migrations/202610080015_resume_export_local_hardening.sql \
    -f supabase/migrations/202610080016_resume_export_cleanup_hooks.sql
  echo "PASS: local Auth fixture and prerequisite migrations 001–016"

  if [[ "$mode" == "--resume-export-cost-unit-only" ]]; then
    "${local_psql[@]}" \
      -f supabase/migrations/202610080017_resume_export_deletion.sql \
      -f supabase/migrations/202610080018_resume_export_admission.sql \
      -f supabase/migrations/202610100019_resume_export_cost_protection.sql \
      -f supabase/migrations/202610100020_resume_export_cost_purge_recovery.sql \
      -f supabase/migrations/202610100021_resume_export_cost_output_unit.sql \
      -f supabase/tests/resume_export_cost_output_unit.sql
    echo "PASS: migrations 017–021 and resume_export_cost_output_unit.sql"
    ready_state="$("${local_psql[@]}" -Atc "SELECT coalesce(bool_and(NOT accounting_ready),false) FROM public.export_cost_budget_policy")"
    if [[ "$ready_state" != "t" ]]; then
      echo "FAIL: disposable cost-unit fixture did not roll back accounting_ready" >&2
      exit 1
    fi
    echo "PASS: accounting_ready=false remains after cost-unit test"
    exit 0
  fi

  "${local_psql[@]}" \
    -f supabase/migrations/202610080017_resume_export_deletion.sql \
    -f supabase/migrations/202610080018_resume_export_admission.sql
  echo "PASS: migrations 017 and 018 applied in order"
  "${local_psql[@]}" -f supabase/tests/resume_export.sql
  echo "PASS: resume_export.sql"

  "${local_psql[@]}" \
    -f supabase/migrations/202610100019_resume_export_cost_protection.sql \
    -f supabase/migrations/202610100020_resume_export_cost_purge_recovery.sql \
    -f supabase/migrations/202610100021_resume_export_cost_output_unit.sql
  echo "PASS: migrations 019–021"
  JOBIX_DISPOSABLE_PG_SOCKET="$work/socket" node tool/configure_estimated_export_dev.mjs --verify-disposable
  "${local_psql[@]}" -f supabase/tests/resume_export_cost_output_unit.sql
  echo "PASS: resume_export_cost_output_unit.sql"
  "${local_psql[@]}" -f supabase/tests/resume_export_cost_protection.sql
  echo "PASS: resume_export_cost_protection.sql (synthetic disposable rates only)"
  "${local_psql[@]}" -f supabase/tests/resume_export_cost_purge.sql
  echo "PASS: resume_export_cost_purge.sql"
  "${local_psql[@]}" -f supabase/tests/resume_export_admission.sql
  echo "PASS: resume_export_admission.sql"
  "${local_psql[@]}" <<'PSQL'
\i supabase/tests/resume_export_recovery.sql
\echo PASS: resume_export_recovery.sql
\i supabase/tests/resume_export_deletion.sql
\echo PASS: resume_export_deletion.sql
PSQL

  if [[ ! -f backend/pdf/test/integration.mjs || ! -f tool/test_export_cost_concurrency.sh ]]; then
    echo "FAIL: required focused PDF/concurrency test file is missing" >&2
    exit 1
  fi
  JOBIX_DISPOSABLE_PG_SOCKET="$work/socket" node backend/pdf/test/integration.mjs
  JOBIX_DISPOSABLE_PG_SOCKET="$work/socket" bash tool/test_export_cost_concurrency.sh

  "${local_psql[@]}" -c "UPDATE public.export_cost_budget_policy SET accounting_ready=false,updated_at=clock_timestamp() WHERE singleton AND accounting_ready IS DISTINCT FROM false"
  ready_state="$("${local_psql[@]}" -Atc "SELECT coalesce(bool_and(NOT accounting_ready),false) FROM public.export_cost_budget_policy")"
  if [[ "$ready_state" != "t" ]]; then
    echo "FAIL: accounting_ready did not return to false in disposable PostgreSQL" >&2
    exit 1
  fi
  echo "PASS: accounting_ready=false restored before disposable database cleanup"
  exit 0
fi
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
  -f supabase/migrations/202610100019_resume_export_cost_protection.sql \
  -f supabase/migrations/202610100020_resume_export_cost_purge_recovery.sql \
  -f supabase/migrations/202610100021_resume_export_cost_output_unit.sql \
  -f supabase/tests/resume_export_cost_output_unit.sql \
  -f supabase/tests/resume_export_cost_protection.sql \
  -f supabase/tests/resume_export_cost_purge.sql \
  -f supabase/tests/resume_export_admission.sql \
  -f supabase/tests/resume_export_recovery.sql \
  -f supabase/tests/resume_export_deletion.sql
 echo "PASS: Export cost reservations/admission/recovery/deletion (disposable PostgreSQL)"
if [[ -f backend/pdf/test/integration.mjs ]]; then
  JOBIX_DISPOSABLE_PG_SOCKET="$work/socket" node backend/pdf/test/integration.mjs
fi
 JOBIX_DISPOSABLE_PG_SOCKET="$work/socket" bash tool/test_export_cost_concurrency.sh