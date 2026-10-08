# Private Resume PDF exports — local implementation

**Development implementation/deployment authorized; activation still gated on
verified access/runtime.** No live migrations, IAM/provisioning, Cloud Run/Scheduler
start, object upload/signing, live Credits or deployment was performed.
Native tooling/signing/APK/device verification is not part of this implementation.
The deletion/retention product decision is now approved and recorded exactly in
[the Phase 3 ADR](ADR-retention-deletion.md). The owner subsequently authorized
the complete development vertical slice. Ask before destructive/irreversible
cloud operations; never touch staging/production or create service-account keys.

## Local code boundaries

- `document.mjs` runs the existing pure-Dart renderer via stdin. The gateway reads
  authoritative profile/configuration/link snapshots. Clients supply IDs,
  expected versions and hashes, not source HTML, user IDs or prices.
- Existing default layouts/template IDs/model metadata remain unchanged.
  Visibility is explicit, configuration/profile versions advance together, and
  structural validation does not award completeness, change 30+15 evidence,
  the 50% latch, allowance state or descriptive-quality thresholds.
- Immutable snapshots contain exact canonical HTML with embedded font bytes,
  document/source hashes, bundle identity and complete configuration/version data.
  Preserve the same renderer/fonts/bundle in the approved runtime image; a future
  renderer change must use a new bundle identity and retain the old bundle for
  queued historical jobs. Do not silently replace Chromium or fonts.
- The worker validates source hash, lease and deadline, prints offline, verifies
  PDF structure/page count and extracted text, uploads with
  `ifGenerationMatch=0`, adopts only matching existing objects, and reads back the
  exact generation before fenced completion. PostgreSQL finalization is atomic
  with the existing immutable debit ledger. Missing/expired files never cause
  automatic regeneration or a new charge.
- Reaper is idempotent. Linked legacy reservation endpoints cannot finalize
  exports directly. Leases can retry up to three times inside the total
  30-minute deadline. In-process slots are reserved before asynchronous claims.
- Signed download URLs expire within ten minutes, include generation in the
  signature, and are issued only after authenticated ownership/active-account
  checks. URLs are never persisted.
- Android download uses a user-selected Storage Access Framework document,
  with bytes/URL memory-only in the app; no new storage permissions or dependency.
  User-saved copies are user-owned, not governed by the server's seven-day
  object expiry. Android channel and Flutter UI are **not verified on-device**.

## Tests (no cloud connections)

From repository root:

```sh
dart mobile/jobix/tool/test_resume_document.dart
node --test mobile/jobix/backend/pdf/test/*.test.mjs
bash mobile/jobix/tool/test_rls.sh
python3 mobile/jobix/tool/check_resume_print.py
# From mobile/jobix, with the existing real SQLCipher test-library path:
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true test/resume_export_test.dart
```

The SQL runner creates/destroys a guarded PostgreSQL cluster on a local Unix
socket. It applies the historical migrations first, then the six export migration
files and synthetic export tests. Its integration uses the real SQL procedures,
server-prepared Dart HTML and real existing local Chromium/Poppler, with an
explicit in-memory storage test adapter. It does **not** verify GCS or deployed
identity/IAM. The test-only CDP adapter is not a production second renderer.

Production adapters declare exact `pg`/`playwright` versions in this isolated
directory. Those exact dependencies and their isolated frozen lock are restored.
The matching headless browser was downloaded to ignored local tooling storage,
but cannot launch with the host's available libc/library combination. Do not
substitute the working host Chromium for the pinned production engine, upgrade
system libraries, install/repair root services or claim runtime readiness.

The Flutter lock was restored with explicit owner approval and without changing
dependency versions or manifests. The full default-off suite and opt-in local
export UI fixtures passed. The test-only compile flag is not a rollout flag
change and does not enable any remote service.

## Local deletion/expiry integration

`cleanup.mjs` is a private hook, not an Auth/deletion product endpoint.
`freeze` only accepts an account/profile already marked DELETING by its authorized
owner. Its transaction invalidates all relevant fences and releases PENDING
reservations once, without refunding completed debits.

The distributed upload-flight ledger must prove writer quiescence before object cleanup; waiting
for a timeout alone never proves that an in-flight remote write has stopped.
Cleanup deletes/verifies exact generations and catches replacement/late-write
races. Each physical create is registered before sending and settled only on a
definitive provider success or conditional-create conflict. Ambiguous/aborted
requests remain SENT, preventing deletion completion; an expired lease or timeout
never proves quiescence. If provider response evidence cannot be recovered, deletion
remains pending for verified provider reconciliation, not a guessed timeout.
Every create carries its unique fence marker; a matching stored object can
reconcile its lost acknowledgement. Unresolved creates cannot overlap for a job,
so finding that exact marker proves that physical request completed.
After quiescence and canonical/orphan-object absence checks, a private transaction
removes owned snapshots/jobs/export receipts/reservations and verifies absence.
It returns EXPORT_DATA_REMOVED, not account-deletion completion. Existing status
transitions trigger export freeze; physical profile/account deletion is guarded
until export data is removed. Immutable Credit ledger/account/slot/Auth policies
outside the export integration are untouched.

The approved ADR requires profile/account deletion to remove its export-related
objects, snapshots and related export data and verify no active export
objects/snapshots remain, with late/stale-worker protection. PDF expiry alone
does not require immediate snapshot/canonical-HTML deletion. Existing expiry
fixtures preserve history/replay and completed charges; this must not be confused
with the required removal of export data during profile/account deletion.
No additional snapshot/history retention period is authorized.

Source-only and HTML passes share a single thirty-second preparation budget.
Normalized 200KB validation happens before HTML/font rendering. Snapshot manifests
archive exact embedded fonts and licenses, not hashes of later mutable files.

## Closed readiness/approval gates

`Dockerfile` packages the same Dart 3.8.0 canonical generator as an AOT executable
and installs the locked Playwright engine into a compatible Debian runtime.
It is for managed development Cloud Build, never local Docker. `.dockerignore`
allowlists only pure-Dart source, backend modules/lock and the required fonts/
licenses; credentials, config, user data, node_modules and caches are excluded.
The AOT generator was compiled and exercised locally; the container/image has
not been remotely built or deployed.

`tool/apply_phase3_dev.mjs` is an opt-in, project-guarded, verified-TLS additive
migration runner. It applies all six files in one transaction under an advisory
lock with recorded checksums, rejects partial unmanaged export schemas, and
never enables rollout or provisions administrator runtime access. A trusted
public database root certificate is required; verification is never disabled.

1. Deletion/retention product behavior and development implementation are
   authorized. Destructive cloud cleanup/lifecycle operations require approval;
   actual-cloud purge/barrier/final-verification evidence remains outstanding.
2. Owner-approved development migration, restricted runtime LOGIN with only
   `jobix_export_gateway`/`jobix_export_worker` membership, public CA certificate
   and verify-full TLS. Never fall back to the administrator/deployer DSN.
3. Confirm runtime storage/signBlob permissions, gateway invoker and Scheduler
   invoker isolation, secret access and no public Cloud Run ingress.
4. Approve and configure the Edge-to-Cloud-Run identity transport. The optional
   server-only credential adapter is **unconfigured**, uses only the dedicated
   backend identity, and never reuses the deployer credential. No new key was
   created. Prefer a supported approved keyless provider; do not imply one
   exists without checking.
5. Reproducible runtime image containing this isolated package lock, pinned
   Chromium, Dart CLI, canonical renderer/font/license assets and Poppler.
   Test the production Playwright/GCS/OIDC adapters separately; local CDP/fake
   storage does not establish production readiness.
6. Closed-by-default flags: native `JOBIX_ENABLE_PDF_EXPORT`, server/Edge
   `JOBIX_EXPORT_ENABLED`, `JOBIX_EXPORT_DELETION_POLICY_APPROVED`, and database
   `export_settings.enabled/deletion_policy_approved`. Readiness setup alone
   is not rollout approval.
7. Explicit owner approval before any rollout, live Credits, remote migration,
   IAM/cloud mutation or deployment. Phase acceptance/device verification
   must not be inferred from synthetic tests.

Missing runtime environment values are deliberately fatal. No credentials or
connection strings belong in Flutter, Git, logs or this document. The server
requires `JOBIX_DEV_EXPORT_DATABASE_URL`, `JOBIX_DEV_DATABASE_CA_FILE`,
`JOBIX_DEV_EXPORT_WORKER_URL` and verified development project/runtime identity.
The Edge optional credential adapter would require a separately approved
server-only `JOBIX_EXPORT_GATEWAY_IDENTITY_JSON`; none has been requested or set.
