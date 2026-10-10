#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${JOBIX_DISPOSABLE_PG_SOCKET:?must run against the test_rls.sh disposable PostgreSQL socket}"
tmp="$(mktemp -d /tmp/jobix-cost-concurrency.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
psql=(psql -X -q -U runner -v ON_ERROR_STOP=1 -h "$JOBIX_DISPOSABLE_PG_SOCKET" -p 55439 -d postgres)

"${psql[@]}" <<'SQL'
DELETE FROM public.export_cost_attempts;
DELETE FROM public.export_cost_reservations;
UPDATE public.export_cost_budget_policy SET budget_microusd=10000000,
 shared_cost_reserve_microusd=0,runtime_cost_microusd_per_second=0,
 output_cost_microusd_per_gib_7d=0,storage_operation_cost_microusd=0,
 per_export_overhead_microusd=6000000,accounting_ready=true,updated_at=clock_timestamp()
WHERE singleton;
SQL

(
  "${psql[@]}" >"$tmp/first.log" 2>&1 <<'SQL'
BEGIN;
SELECT public.jobix_export_cost_reserve('92000000-0000-0000-0000-000000000001');
SELECT pg_sleep(0.25);
COMMIT;
SQL
) &
first=$!
sleep 0.03
(
  "${psql[@]}" >"$tmp/second.log" 2>&1 <<'SQL'
BEGIN;
SELECT public.jobix_export_cost_reserve('92000000-0000-0000-0000-000000000002');
SELECT pg_sleep(0.25);
COMMIT;
SQL
) &
second=$!

set +e
wait "$first"; first_status=$?
wait "$second"; second_status=$?
set -e

if { [[ $first_status -eq 0 ]] && [[ $second_status -eq 0 ]]; } ||
   { [[ $first_status -ne 0 ]] && [[ $second_status -ne 0 ]]; }; then
  cat "$tmp/first.log" "$tmp/second.log" >&2
  echo "FAIL: concurrent reservations did not serialize at the $10 budget" >&2
  exit 1
fi

count="$("${psql[@]}" -At -c "SELECT count(*) FROM public.export_cost_reservations WHERE operation IN ('92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002') AND state='HELD' AND reserved_microusd=6000000")"
if [[ "$count" != "1" ]]; then
  cat "$tmp/first.log" "$tmp/second.log" >&2
  echo "FAIL: expected exactly one of two concurrent $6 reservations" >&2
  exit 1
fi
echo "PASS: concurrent reservations serialize; usage remains within USD 10"
