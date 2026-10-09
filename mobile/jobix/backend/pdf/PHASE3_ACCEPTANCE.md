# Phase 3 development MVP — personal phone export verified

## Current outcome — READY for the controlled personal export milestone

The owner confirmed the current APK installed/signed in/showed the existing
personal resume, and that the first PDF downloaded and opened on Samsung M31.
This is owner-reported physical-device evidence, not agent ADB instrumentation.
Backend evidence proves one completed export from that account/current snapshot,
one -2 debit and consumed first reservation. Actual PDF hash/header/object read
verified; rendered English layout inspected with existing tools, no clipping.
No Arabic content is present in this actual resume; live Arabic remains untested.
Anonymous access to the actual stored PDF returned 403.

The owner confirmed explicitly pressing Create/Export Again and confirming the
second intent. It was not an automatic retry or same-key duplicate. Gates were
closed before it rendered/debited. The owner separately approved expiry cleanup.
After its original natural deadline, the existing native recovery RPC processed
only this sole eligible queued job (including a guard against unrelated completed
expiry rows and unresolved uploads), in a repeatable-read guarded transaction.
It became FAILED / RESERVATION_EXPIRED; reservation RELEASED. No timestamp edits,
gate reopening, refunds, manual wallet updates or new export work.

Final checked accounting: finalized=available=3, reserved=0, exactly one -2 export
debit, one COMPLETED export, one expired FAILED intent, no pending reservation.
First PDF/hash remained unchanged. The extra immutable snapshot is not deleted:
PDF expiry alone does not authorize snapshot deletion under the approved policy.

All four export gates stay closed. Ready means this specific current-APK/private
development-backend personal export/download milestone succeeded; it does NOT
mean permanent export enablement or full production/staging acceptance.
Original operation's replay was verified through the authoritative native RPC;
real phone HTTP lost-response/replay and supplemental live fault/deletion checks
remain separate test gaps. No further paid tests/AI/new implementation authorized.

Owner-selected local gate contract: `JOBIX_EXPORT_ENABLED` blocks new create/again
requests, dispatch, rendering and new charges, but does not block an authenticated,
owner-authorized free download of an existing completed PDF when the existing
deletion-policy approval remains enabled, or safe expiry recovery. Disabled
recovery must not dispatch; unresolved upload flights continue to block deletion
completion. This is a source/test change only: no deployed gate, service or
environment value was changed. Deploying this behavior still needs separate
scoped development approval.

## Earlier personal phone window — first completion and extra-intent stop

> Historical checkpoint. Its immediate post-export observations below are
> superseded where noted by the current outcome at the top of this document.
> Preserve the accounting and sequence as evidence; do not use this checkpoint's
> old “unverified” wording as the current device status.

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
without refunding/altering Credit data. The owner later confirmed explicitly
choosing Create/Export Again and confirming; this was a separate user intent,
not a same-key replay or automatic retry. Post-stop: one COMPLETED job, second
QUEUED job with PENDING 2-Credit reservation, finalized balance 3, reserved 2
(available 1), exactly one debit.

Closed Worker `00011-tnk`, Gateway `00010-4rp`; same deployed image digests.
Edge and database export gates closed; deletion-policy approval unchanged.
No second test/export may be started. The deployed versions still gate downloads;
do not reopen gates or enable Worker merely to download, since it can run the
queued second job. Local source now permits free completed downloads and expiry
recovery without dispatch while those gates are closed. No deployment or gate
change is included here. Use only established expiry/recovery semantics; no forced
expiry, fabricated cancellation/refund or manual balance change.
At this checkpoint the phone download/open and layout were not yet confirmed.
The owner later confirmed that the first PDF downloaded and opened on the M31;
Arabic print, phone HTTP lost-response replay, and broader ownership/failure
acceptance remain separate gaps. The later current outcome is at the top of this
document.

## Current development delivery — export status NOT READY

> Historical pre-test gate checkpoint. Its “pending” and “not ready” statements
> predate the separately approved personal export window and the successful
> phone result recorded at the top. Preserve the original approval boundary;
> use the current outcome above for present acceptance status.

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
At this checkpoint, personal sign-in/export/device save/open and replay/
ownership evidence were pending. The owner subsequently confirmed the
authenticated M31 happy path; only the specific evidence listed in the current
outcome is accepted.

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
| Actual Android happy-path PDF download/open | **PASS, owner-confirmed** | The owner reported the first PDF downloaded and opened on Samsung M31; not independent ADB instrumentation and not failure/Arabic-layout acceptance |
| Live cloud injected failure/expiry/deletion | **UNVERIFIED** | Not substituted with local evidence; no live test gate opened |

## Commands

> The 90/90, 7-pass/1-fail RLS output and missing-Flutter-cache error below are
> from an earlier diagnostic run. Later post-fix evidence is recorded above:
> 101/101 backend, 8/8 guarded disposable acceptance, 11/11 adapter, and the
> stated fixture-backed Flutter results. Do not claim the complete current RLS
> harness passed until a fresh full `test_rls.sh` result is recorded.

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
