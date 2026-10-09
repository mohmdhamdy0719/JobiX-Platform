# Phase 3 acceptance — Worker fix deployed, personal phone export pending

## Personal phone window — first export completed; stopped on extra intent

Owner approved one real-account export and reported APK installed, signed in,
personal resume visible. Read-only baseline: active/confirmed account, one active
profile, 5 finalized/available Credits, zero reserved, no prior exports/debits.
Only the four approved development gates opened; no funding/profile edits or
export creation by operational tooling. A bounded monitor watched the phone.

The first real job completed: one page, 127100 bytes, PDF SHA256
`105b24b7daa65ce48111965f280ad12a7a635b3338732392fc13d069e46e6a16`.
Exact object read/hash/header verified through trusted backend access, not
phone download proof. One -2 debit, reservation CONSUMED, finalized balance 3
and reserved balance 0 at completion. The original operation's native replay
RPC returned the same acknowledgement in a rolled-back transaction; no new
create call or second charge. This is database replay, not phone HTTP replay.

The monitor then observed a second job with a distinct idempotency key, about
three minutes after the first request. It closed all four gates immediately,
without refunding/altering Credit data. Post-stop: one COMPLETED job, second
QUEUED job with PENDING 2-Credit reservation, finalized balance 3, reserved 2
(available 1), exactly one debit. Origin/user action is not yet established;
do not assume automatic client retry or blame user action.

Closed Worker `00011-tnk`, Gateway `00010-4rp`; same deployed image digests.
Edge and database export gates closed; deletion-policy approval unchanged.
No second test/export may be started. Do not reopen gates merely for download:
download is also gated and reopening Worker can run the queued second job.
Use only established expiry/recovery semantics after reconciling this job;
no forced expiry, fabricated cancellation/refund or manual balance change.
Phone download/open/layout and actual request replay/ownership evidence remain
unverified. Overall status NOT READY; task acceptance is not complete.

## Current development delivery — export status NOT READY

The owner authorized a current debug APK and only necessary development backend
fixes. No export gate may be opened or chargeable export performed without
separate approval. Final acceptance must use the owner's real authenticated
development account and existing personal resume, never the earlier fictional
fixture. No funding/balance adjustment is permitted.

- Current ARM64 debug APK build succeeded using `--no-pub`, exact locked
  dependencies, existing SDK/cache and dev defines plus
  `JOBIX_ENABLE_PDF_EXPORT=true` (client UI only).
- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.
  Package `com.mhflow.jobix`, version `1.0.0` / code `1`, debug, min API 24,
  target API 36, ARM64. APK signature verifies and certificate matches the
  earlier delivered M31 native-bugfix APK. No device test is claimed.
- APK SHA-256: `49b7ce41f0085b91ddfbc3c8ad1339ebd930ca9bd75722f941fc68b5043fa214`.
  Download: `deliverables/jobix-phase3-m31/jobix-phase3-m31-debug.zip` contains
  the unchanged APK; archive integrity passed. ZIP is necessary because raw APK
  exceeds Library's 100 MiB limit.
- Allowlisted managed Worker build succeeded, source hash
  `9b387ab79d28a3feb45239781987816d7558aeb7682d409c6f34759c114c38f0`.
  Only existing development Worker image updated, region `me-central1`.
  Ready revision `jobix-dev-pdf-export-00009-hg8`, image digest
  `sha256:69fd2947770a4be0e37b778a7ad7d6bf8063474de7febc3d8fd6b9b57e58e5ef`.
  Upload-rejection fix is now in this deployed image.
- Gateway unchanged: `jobix-dev-export-gateway-00008-8p9`, digest
  `sha256:4754a7409e471ecb8aef8ebf41bf3607de55915fd09246e7da697dc4e69d573d`.
  Edge `resume-export` v5 ACTIVE, JWT verification enabled; its configured
  Gateway URL matches the actual deployed Gateway. Development Auth rejects
  invalid token (403). No signing configuration changed.
- Worker identity, Secret version 1, CA path, flags and IAM policy preserved.
  Worker remains private; Gateway alone has public invocation. GCS uniform
  access enabled, no public IAM binding; no storage privacy changes.
- Six post-deployment checks pass: Gateway startup-health 200, anonymous Worker
  403, absent/invalid Gateway token 401, Gateway recovery path 404, forbidden
  cleanup command 400. Gateway `/ready` reports its startup check, not a fresh
  personal-user call through the updated Worker.
- Worker/Gateway/Edge export-enabled flags remain false; database enabled=false,
  approved deletion-policy flags preserved. No Credit data modified, funding,
  new PDF export, migrations, IAM/credential changes or production/staging work.
  All three tracked dependency lock hashes remain unchanged.

Pending: owner installs APK/signs in/confirms personal resume; identify the
owner's account for a read-only active-account/profile/Credit balance check.
Request approval for a bounded development window changing only Worker and
Gateway `JOBIX_EXPORT_ENABLED`, Edge `JOBIX_EXPORT_ENABLED` and existing
`export_settings.enabled` to true. These are global development gates.
Keep deletion-policy approval unchanged. Insufficient existing Credits means
stop, never fund. One new 2-Credit intent only; no repeat/fabrication of prior
successful export. Close gates after the controlled test.
Personal sign-in/export/device save/open, replay accounting, reservation and
unauthorized access evidence are still UNVERIFIED; status must remain NOT READY.

## Earlier local increment

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
