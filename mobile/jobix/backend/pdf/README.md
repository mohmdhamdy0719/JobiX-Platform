# Private Resume PDF exports — local implementation

**Development implementation/deployment authorized; actual worker activated,
Scheduler invocation verified, rollout BLOCKED at gateway metadata access.** Six development migrations are applied
with database/client exports still disabled. The private bucket has an approved seven-day `exports/`/`.pdf`
lifecycle rule. The only agent IAM-policy mutation was the owner-approved
obsolete backend bucket-membership removal. The actual worker is deployed;
the existing recovery job is enabled after a successful live invocation.
No Edge rollout or committed live Credit debit has occurred.
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

### Current development checkpoint

**Actual rollout is BLOCKED at gateway:** backend access passes HTTP 200,
anonymous access is denied with 403, and the actual pinned worker is active on
revision `jobix-dev-pdf-export-00002-bpb`. The existing one-minute recovery job
was resumed after the administrator's correction; actual invocation passed
RPC **0 / OK** and the job remains enabled, without a duplicate or agent IAM
change. The subsequent Supabase Management API development secret-metadata
read returned **403** and the rollout stopped. Remote gateway configuration
remains unverified; local Edge code still lacks an implemented keyless identity
transport. No keys, credential substitution or security bypass. Gateway/database
enabling and live billable export tests remain unperformed. Historical
readiness-only evidence below does not imply full export readiness.

**Earlier runtime configuration: READY in read-only mode before activation.** Private Cloud Run
`jobix-dev-pdf-export` in `me-central1` uses the existing pinned image/backend
account, Secret `jobix-dev-export-database` version `1`, and CA file
`/opt/jobix/assets/certs/supabase-root-2021.crt`. Its authenticated `/ready`
response confirms actual hosted Secret resolution, certificate presence/
fingerprint, authorized TLS, restricted database identity and all 19 export
function privileges. Anonymous access is 403; dispatch is 503.

The image entrypoint is overridden with read-only startup verification, not
`server.mjs`. Export processing flags are false; no scheduler or normal worker
is enabled. Do not activate by merely changing flags: a separately authorized
normal worker revision must deliberately restore the entrypoint and complete
the remaining private transport/live export checks. Configuration is managed by
`tool/configure_phase3_runtime_dev.mjs`, which refuses to replace an existing
service blindly. No IAM/credential/Secret/migration changes accompany this
runtime binding. Earlier checkpoints below are historical.

**Latest build/credential checkpoint:** the immutable managed image is built
and pushed; isolated managed verification passed English/Arabic canonical,
font/text/PDF validity and invalid-PDF checks using its actual pinned Chromium.
Restricted development LOGIN and encrypted Secret Manager version provisioning
also passed backend retrieval/TLS/exact-membership/direct-table-denial checks.
No admin DSN was used at runtime; no worker/Edge/Scheduler was deployed.
The owner-approved obsolete bucket membership removal is complete: the custom
role and every unrelated grant/condition were preserved, and effective tests
return exactly create/get/list/delete with no update/restore/move. No objects
or retention rules changed. Signing still exceeds the approved minimum;
deployment remains blocked pending the administrator's signing correction.
The earlier build/secret denials below are historical, not current blockers.

**Latest operator-access verification:** backend object CRUD and keyless signing
now work. The actual `GoogleStorage` adapter passed private backend-identity
upload/read/sign/download, duplicate-create and signed-generation-tamper checks;
its exact-generation isolated fixture was removed and absence verified. This
does not verify metadata identity in Cloud Run or PDF generation.

Submission now fails specifically on deployer actAs of the default Compute
builder. The supplied numeric runtime-secret resource belongs to the approved
project, but required deployer/backend secret permissions are still absent.
Effective backend permissions exceed the approved minimum: objectUser also
allows update/restore/move, and signing access also allows token/JWT/delegation
operations. No policy has been changed by the agent; operator scope correction
is required. See `DEVELOPMENT_ACCESS.md` for exact principals and resource scopes.

- The owner-supplied public Supabase Root 2021 CA is bundled at
  `assets/certs/supabase-root-2021.crt`; verified-TLS migration and repeat
  checksum/idempotency checks succeeded on the guarded development target.
- Live development DB tests passed for canonical preparation, atomic
  create/replay, reservation/release, denied direct client table reads,
  cross-actor status denial and frozen export-data purge. Both synthetic Auth
  identities, profile/export rows, settings changes and Credit entries were
  transactionally rolled back. This is not a deployed Edge/worker test.
- A new isolated GCS protocol fixture passed conditional create/conflict and
  anonymous-read denial, then exact-generation deletion and active-object
  absence verification. It used deployment credentials strictly as test
  tooling, not runtime credentials or a substitute for backend access.
- Allowlisted, credential-free managed-build source is uploaded privately under
  `phase3-builds/`, outside the PDF lifecycle prefix. It is retained for retry;
  no extra CV/snapshot retention period is introduced. Managed build submission
  is rejected with 403. No image is built/deployed.
- Original runtime object/self-signing permission tests returned none; these
  are superseded by the operator-access verification above. Earlier necessary
  custom-role/runtime-secret creation attempts were rejected. Do not work
  around remaining blockers with broader roles, new keys or admin DSNs.

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

### Resume layout Migration 022 — Development only

The runner has an explicit, separately guarded `--apply-development-resume-layout-022`
mode. It is pinned to Development project `lmouxhbjhtqdtiqijcee`, uses only
`JOBIX_DEV_DATABASE_URL` plus a verified CA file, and takes the same
`jobix_phase3_dev_migrations` transaction advisory lock as the other migration
modes. Before applying anything it verifies ledger versions/checksums 012–021,
the required layout/profile/idempotency schema and read RPC, absence of the exact
new function signature, and that the creating role can own and execute the
security-definer function without violating the referenced tables' RLS boundary.
Migration 022 and its ledger row are committed atomically. The source checksum is
pinned to the reviewed value:
`d34f6dad4d9edcd301486d9d507bed7330c0fde66cfac3630bee087fa8366473`.

Only after separate owner approval, set `JOBIX_DEV_DATABASE_CA_FILE` to the
verified Development CA file path and run from `mobile/jobix`:

```sh
node tool/apply_phase3_dev.mjs \
  --apply-development-resume-layout-022 \
  --ca-file "$JOBIX_DEV_DATABASE_CA_FILE"
```

Do not use a Production URL or bypass the project's Development target guard.
This command was not run as part of local implementation or testing.

Operational tools: `tool/configure_phase3_bucket.mjs` requires explicit scoped
expiry approval and preserves unrelated rules; `tool/build_phase3_dev.mjs`
uploads only a fixed source allowlist and submits managed development builds;
`tool/test_phase3_dev.mjs` requires isolated-fixture approval, rolls back database
fixtures, and removes only its freshly created exact GCS generation.

`tool/narrow_phase3_bucket_iam_dev.mjs` requires explicit owner grant-removal
approval, removes only the obsolete backend objectUser membership, retains the
custom binding, preserves every other principal/condition, and uses etag/
metageneration guards plus full policy/effective-permission readback.

`tool/provision_phase3_runtime_dev.mjs` refuses existing LOGIN/secret rotation,
creates only a restricted development LOGIN and stores credentials encrypted
without writing them to files/logs. `tool/verify_phase3_image_dev.mjs` runs only
the digest-pinned approved image in managed Cloud Build with synthetic source,
no database/storage/runtime credentials. No Docker runs in this workspace.

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
