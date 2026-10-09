# Phase 3 acceptance — local fix verified, live/Android acceptance pending

## Current local increment

The rejected-upload blocker is fixed locally, not deployed. The production
adapter preserves HTTP rejection classification and privately mints no-write
evidence tied to the original object path and upload fence. Only definitive
401/403 rejection or failure before issuing any upload can settle that exact
flight. Forged/copied error properties cannot settle it. Timeouts, connection
failures, lost success bodies, 408/429/5xx remain unresolved; existing object
verification/adoption, fencing, reservation and exactly-once debit rules remain.
Attempt identity is captured before asynchronous work.

- Focused adapter: **11/11 passed**.
- Guarded disposable acceptance: **8/8 passed**, including real adapter HTTP
  403 -> exact flight SETTLED -> same-job/new-fence retry -> COMPLETED,
  zero unresolved SENT flights, zero reserved balance, one debit. Subsequent
  stale/duplicate runs preserve the object and charge.
- Full backend regression after the fix: **101/101 passed**.
- Exact Flutter packages restored using `flutter pub get --enforce-lockfile`.
  All tracked lockfile SHA-256 hashes are unchanged; no dependency upgrades.
  Existing SQLCipher was resolved from its installed binary prefix and supplied
  only to the test process; no library/toolchain was installed.
- Flutter default-off: **4/4 passed**.
- Enabled local fixture flow: **18 cases verified**. Initial enabled run had
  16 passes and two incorrect raw-status text expectations. They were corrected
  to the existing localized UI labels; focused rerun **2/2 passed**. The other
  16 cases were not needlessly rerun. This is actual Flutter widget/SDK execution
  with fixture HTTP and mocked native channels, NOT physical Android evidence.
- Android SDK already has platforms 34/35/36 and build tools 34.0.0/35.0.0.
  ADB has no devices, no emulator/system image/AVD exists, and Flutter detects
  Linux only. No setup, install, signing or APK build was performed.

No cloud resources/gates were changed; no new funding or real export occurred.
The successful real result remains protected. The local worker fix is NOT yet
in the hosted image. Live fault/expiry/deletion and actual Android WebView/file
save remain unverified; do not mark all Phase 3 acceptance complete.

Single next prerequisite: an ADB-visible Android test target, preferably the
existing Samsung M31 over a private connection. No SDK upgrade is required.

## Earlier diagnostic checkpoint (superseded locally)

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
| Definitively rejected upload then provider recovery | **PASS after local fix** | Same job completes on attempt 2; no unresolved SENT flights/reserved balance; exactly one debit |
| Upload-rejection error mapping | PASS after local fix | HTTP classification and exact-attempt evidence retained; ambiguous outcomes cannot settle |
| Duplicate callback/atomic rollback/fencing | PASS, existing disposable SQL | Native callback/recovery assertions and atomic rollback check passed |
| Expired download | PASS, disposable SQL | EXPORT_EXPIRED; original snapshot survives; no replacement/debit |
| Explicit Export Again | PASS, disposable SQL | Changed current source; new job/hash; reserves and consumes 2; no silent regeneration |
| Account deletion freeze | PASS, disposable SQL | DELETING denies even cached replay with ACCOUNT_DELETING |
| Pending-reservation release/stale writer after freeze | PASS, disposable SQL | Profile freeze clears lease/releases funds; old upload-begin rejected; only settlement can acknowledge late request |
| Object/orphan removal and export-data absence | PASS, local object map + SQL | Owner paths removed; jobs/snapshots/reservations/flights/export-command dedupe zero; peer object and immutable ledger remain |
| Flutter preview/status/download/visible retry/failure | **PASS, local fixtures** | Enabled cases verified after exact locked restore; native channels mocked, not Android acceptance |
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

## Original upload root cause — now fixed locally

`google.mjs` collapses non-409/412 provider errors into SERVICE_UNAVAILABLE.
`worker.mjs` settles upload flights only on success or OBJECT_EXISTS.
The native `jobix_export_upload_begin` rejects any new request while an older
SENT flight remains, returning CLEANUP_UNVERIFIED. This is correctly fail-closed
for genuinely ambiguous timeouts, but the adapter loses the evidence needed
to distinguish definitive no-write rejection. Retry cannot reach a recovered
provider, and deletion cannot safely assert quiescence for that old marker.

The implemented local adapter/worker change carries explicit, trustworthy
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

The missing-package blocker is resolved; the actual Android target and live
deployment/fault acceptance are still pending. No extra paid export or cloud
deployment was performed; Phase 3 acceptance is incomplete.
