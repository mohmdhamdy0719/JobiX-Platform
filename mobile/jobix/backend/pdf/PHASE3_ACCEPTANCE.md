# Phase 3 acceptance — focused pass, BLOCKED

## Protected development result

The previously successful real account-A export was not repeated, recreated,
charged, expired or deleted. Read-only SQL and its downloaded byte hash confirm
COMPLETED job, existing immutable snapshot, CONSUMED reservation, exactly one
-2 RESUME_EXPORT debit and zero finalized/reserved balance. Export enabled
remains false; approved deletion flag remains true. No cloud mutation, new
funding, IAM/startup investigation or production/staging operation occurred.

## Results and concrete evidence

All fault/deletion cases below use the guarded disposable PostgreSQL runner
(`/tmp/jobix-rls.*/socket`, no TCP listener) with real application functions.
Renderer/storage faults and object maps are deterministic local adapters, NOT
faults injected into Cloud Run or live GCS.

| Requirement | Result | Evidence |
|---|---|---|
| Terminal renderer failure | PASS, disposable SQL | FAILED; wallet 5 finalized/0 reserved; zero debits/objects |
| Transient renderer retry | PASS, disposable SQL | Same job, new fence, COMPLETED; wallet 3/0; one debit; same-key acknowledgement |
| Worker response timeout after committed finalization | PASS, disposable SQL | Injected exception after native finish commit; COMPLETED; 3/0; one debit |
| Stalled worker/hard deadline | PASS, injected clock + disposable SQL | Existing 30-minute deadline simulated; native recovery twice; FAILED; 5/0; zero debits |
| Upload committed but response lost | PASS, disposable SQL + object map | Retry adopts same verified object; one render/create/debit |
| Definitively rejected upload then provider recovery | **FAIL** | After retry: RETRYABLE_FAILURE, attempt 2, one unresolved SENT flight, zero debit; new lease blocked before retry create |
| Upload-rejection error mapping | PASS, diagnostic confirming defect | Production GoogleStorage with intercepted HTTP 403 throws generic SERVICE_UNAVAILABLE; no real network/credentials |
| Duplicate callback/atomic rollback/fencing | PASS, existing disposable SQL | Native callback/recovery assertions and atomic rollback check passed |
| Expired download | PASS, disposable SQL | EXPORT_EXPIRED; original snapshot survives; no replacement/debit |
| Explicit Export Again | PASS, disposable SQL | Changed current source; new job/hash; reserves and consumes 2; no silent regeneration |
| Account deletion freeze | PASS, disposable SQL | DELETING denies even cached replay with ACCOUNT_DELETING |
| Pending-reservation release/stale writer after freeze | PASS, disposable SQL | Profile freeze clears lease/releases funds; old upload-begin rejected; only settlement can acknowledge late request |
| Object/orphan removal and export-data absence | PASS, local object map + SQL | Owner paths removed; jobs/snapshots/reservations/flights/export-command dedupe zero; peer object and immutable ledger remain |
| Flutter preview/status/download/visible retry/failure | **UNVERIFIED / setup blocked** | `--no-pub` fails before tests load: missing locked pub-cache packages |
| Actual Android WebView/PDF file save | **UNVERIFIED / target absent** | `flutter devices --machine` exposes only Linux, no Android device/emulator |
| Live cloud injected failure/expiry/deletion | **UNVERIFIED** | Not substituted with local evidence; no live test gate opened |

## Commands

- `node --test mobile/jobix/backend/pdf/test/*.test.mjs`:
  existing backend regression **90/90 PASS**.
- `node --test mobile/jobix/backend/pdf/test/upload-rejection.test.mjs`:
  additional production-adapter diagnostic **1/1 PASS**.
- `bash mobile/jobix/tool/test_rls.sh`: baseline SQL/print checks passed,
  **7 new acceptance cases PASS, 1 FAIL**. Failing assertion:
  `backend/pdf/test/integration.mjs`, definitive-upload-rejection retry.
  The disposable server/data were removed by the runner's exit trap.
- `flutter test --no-pub test/resume_export_test.dart --reporter expanded`:
  **0 widget tests executed**, load failure. First cause: missing
  `_fe_analyzer_shared-88.0.0/pubspec.yaml`; `test_api-0.7.4`,
  `flutter_riverpod-2.6.1`, `http-1.6.0` and other locked cache paths absent.
  Undefined-symbol errors are consequences, not proven product defects.
  Formatting also encounters missing `flutter_lints-5.0.0`.

Sanitized run logs: `/tmp/jobix-phase3-acceptance-{node,sql,flutter}.log`.
These are temporary artifacts; this checklist is the durable evidence summary.

## Proven upload blocker and smallest proposed fix — NOT implemented

`google.mjs` collapses non-409/412 provider errors into SERVICE_UNAVAILABLE.
`worker.mjs` settles upload flights only on success or OBJECT_EXISTS.
The native `jobix_export_upload_begin` rejects any new request while an older
SENT flight remains, returning CLEANUP_UNVERIFIED. This is correctly fail-closed
for genuinely ambiguous timeouts, but the adapter loses the evidence needed
to distinguish definitive no-write rejection. Retry cannot reach a recovered
provider, and deletion cannot safely assert quiescence for that old marker.

Propose a local adapter/worker change only: carry explicit, trustworthy
no-physical-write evidence for requests never sent or provider rejections
whose semantics prove no write; settle that exact original flight with null
generation, then retain the existing retry/terminal/debit rules. Never settle
generic network errors, timeouts or ambiguous 5xx, and never treat an absent
object probe or elapsed time alone as quiescence. Keep fencing and conditional
generation-zero creation. No SQL/IAM/Credit/retention/Auth contract change is
needed for the proposed implementation.

Restore only exact locked Flutter packages, not upgrades, to unblock local
widget execution. Real Android acceptance additionally needs an Android test
target; mocked MethodChannels cannot prove WebView or platform file saving.

Stopped at these blockers. No production fix/deployment or extra paid export
is authorized by this diagnostic pass; Phase 3 acceptance is incomplete.
