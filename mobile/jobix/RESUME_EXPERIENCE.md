# JobiX native resume experience

## Implemented

- Six-step guided setup records the current step in the encrypted local database,
  scoped to the account and profile. Review does not mark completion. Its explicit
  **Preview & Export** action requires the existing structural contact/evidence
  minimum. After completion, Home opens Career. This marker is local, not a
  cross-device server-completion claim.
- Resume Export uses the actual English/Arabic ATS template supported by the
  renderer, independent of the app language. The inspectable specimen is marked
  fictional. Unsupported accent/font/spacing controls and fabricated ATS scores
  are intentionally absent.
- Preview displays the server-prepared saved content, with inspectable A4 pages.
  Screen pagination does not change the canonical document hash or guarantee
  identical fragmentation to the final print engine; the finished PDF's backend
  `page_count` remains authoritative.
- Explicit 2-Credit confirmation, durable same-key retry, processing/status,
  export history, receipt details, eligible free downloads, and explicitly
  confirmed re-export use the existing lifecycle APIs. No client debit,
  automatic replacement, retry-created logical operation, or invented progress
  percentage was added.
- Read-only history/status/download UI remains available when new creation is
  disabled. Native save still uses the existing Android document-save channel.
  Preview content is invalidated on account change. Account cleanup removes its
  own setup marker without removing a peer's marker.
- For newly accepted operations, frozen template/language from the prepared
  request is kept in encrypted, account/job/profile-scoped local display
  metadata. Retries keep that original metadata. It cannot override state,
  Credits, cost, page counts, or download eligibility. The current deployed
  status/history contract does not expose frozen template/language for older
  jobs or another device; those fields are omitted rather than inferred from
  the current profile.

## Executed local checks

All application checks used local mock HTTP/database fixtures. Opt-in creation
flags in the Flutter tests do not enable the Development deployment.

```sh
cd mobile/jobix
export JOBIX_SQLCIPHER_LIBRARY="$(dirname "$(dirname "$(command -v sqlcipher)")")/lib/libsqlcipher.so"

flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true \
  test/resume_export_test.dart test/resume_experience_test.dart --reporter expanded

flutter test --no-pub test/resume_experience_test.dart \
  test/resume_export_test.dart --reporter expanded

flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true \
  test/resume_export_test.dart --name 'processing screen polls' --reporter expanded

flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true \
  test/resume_export_test.dart --name 'account cleanup removes' --reporter expanded

flutter test --no-pub test/first_slice_widget_test.dart \
  --name 'returning user opens Home|Review -> Edit -> Save|builder narrow scaled layouts' \
  --reporter expanded

bash tool/test_rls.sh --resume-export-only

cd backend/pdf
node --test test/recovery.test.mjs test/cost-protection.test.mjs \
  test/worker-gates.test.mjs test/upload-rejection.test.mjs
```

Results, each exit status **0**:

- Initial combined Flutter run: **32 passed**.
- Updated presentation/default-off run: **13 passed**; overlaps the initial run.
- Newly added processing-screen polling: **1 passed**, same job and no new intent.
- Account-marker deletion isolation: **1 passed**.
- Final frozen-configuration increment: **3 passed** (ambiguous same-key
  reconciliation, processing-to-download with configuration, and display
  metadata unable to grant entitlement/override state).
- Selected existing builder/Home/edit/restart/narrow-layout regressions:
  **4 passed**.
- Disposable harness: bootstrap schema through 016; migrations 017–020 in order;
  focused SQL/RLS, admission, cost, purge, recovery, and deletion checks;
  canonical Dart/Chromium PDF integration; concurrent replay/reservations;
  atomic rollback; duplicate completion; retention; explicit Export Again;
  over-20-page rejection before upload/debit. In-memory storage only.
  `accounting_ready=false` restored before the temporary PostgreSQL instance
  and its data were removed.
- Focused Node recovery/cost/disabled-gate/upload-rejection tests: **35 passed**
  on local Node **20.20.0**. This is not a Node 24 container validation.
- Final targeted Dart analysis: **no issues found**.
- Development-only foundation check:
  `dart tool/check_foundation.dart config/dev.local.json`: **passed**.

Test logs and English/Arabic native-widget captures are under the ignored
`.local/jobix-native-verification/` directory at the workspace root.

Earlier attempts accurately distinguished from executed passes:

- One Flutter command could not start because its output directory did not
  exist; no tests executed.
- A subsequent test collection hit a receipt-widget compilation typo; fixed
  before the affected checks passed.
- `--plain-name` treated the proposed regex literally and selected no builder
  tests. The listed `--name` command actually executed the four regressions.
- Checking all three environment files failed because staging/production local
  define files are absent. They were not fabricated; the genuine Development
  configuration alone passed its check.
- The narrow frozen-configuration check caught two incorrect envelope-field
  assumptions. It passed after reading language from the canonical top-level
  field and the operation ID from the actual acknowledgement. Assertions were
  not weakened.

## Read-only Development verification

One TLS-verified, pinned Development connection was used with `BEGIN READ ONLY`
and rollback, without running migration SQL or acquiring migration locks.

- Project: `lmouxhbjhtqdtiqijcee`.
- Ledger 018, 019, and 020 present with SHA-256 matching the exact source files.
- Nine expected relations/indexes, thirteen migration functions, and both
  purge-recovery columns present.
- `enabled=false`; `deletion_policy_approved=true`.
- `accounting_ready=false`; all five cost-rate fields remain null.
- Existing central policy remains USD 10 estimated admission budget over seven
  days. It is **not a guarantee of the total provider invoice**.

No live writes, gate changes, rate configuration, deployment, paid tests, paid
resources, billing exports, or Git-history changes were performed.

## Development APK build

The build uses only the existing genuine Development define file; it does not
set `JOBIX_ENABLE_PDF_EXPORT=true`.

```sh
cd mobile/jobix
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")" \
GRADLE_USER_HOME="$PWD/../../.local/gradle" \
GRADLE_OPTS='-Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process -Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.workers.max=2' \
flutter build apk --debug --no-pub --split-per-abi \
  --target-platform android-arm64 \
  --dart-define-from-file=config/dev.local.json
```

The first build failed in Kotlin daemon startup. Explicit local JDK discovery
and process-scoped in-process Kotlin compilation passed that stage; an intervening
build then caught preview ownership/import compilation errors, which were fixed
before the final build. No repository Gradle settings or dependency versions
were changed to bypass the tooling failure.

Final build exit status: **0**. Package/signature verification exit status:
**0**, APK Signature Scheme v2 valid. ARM64 Flutter engine only, package
`com.mhflow.jobix`, version 1.0.0 (1), target/compile SDK 36.

- Build output:
  `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`
  (workspace-relative).
- Delivery copy:
  `.local/jobix-native-verification/JobiX-V2-resume-arm64-development.apk`.
- Download archive:
  `.local/jobix-native-verification/JobiX-V2-resume-arm64-development.zip`
  (**56,906,966 bytes**). Extract the APK before installation.
- APK size: **121,418,530 bytes**. The unchanged APK is zipped because it exceeds
  the Library's per-file limit; archive integrity and contained APK identity
  were verified.
- SHA-256:
  `5b48b2802ea60b57ed90356f0dfdc1f0a71d305098adf9fbf7345b1038ab307b`.
- The packaged debug kernel contains the latest preview owner-invalidation
  guard, frozen display helpers, and resume-journey module.

**Confirmed signing mismatch:** new certificate SHA-256
`0992f7c73668a5c76e9936d79bc0c1be5a12768f9b633eff6598b95c5c70c790`
differs from the verified archived
`deliverables/jobix-profile-text/jobix-profile-text-dev-arm64.apk` certificate
`109e7d8f025f4999cd084c8a1841aca199344a515d9482b52fa192617f326f6b`.
Both APK signatures verify, but Android will reject an in-place update over
that earlier signer. Preserve the existing installation and data. Original
signing-key recovery, or a separately approved safe test arrangement, is needed
before using this binary to update that installation.

## Live-activation checkpoint and limitations

- First-device signup eligibility is not proven by an account-unique signup
  Credit grant. The client requires confirmed email/Google identity, but no
  device attestation/uniqueness enforcement was found in the signup grant.
  The grant/reward policy was not changed, and no invasive fingerprint was added.
- Current deployed Gateway/Worker gate configuration and image compatibility
  were **not live-verified in this increment**. Read-only database verification
  and local fixtures do not establish live readiness.
- No physical Android device was controlled in this increment. WebView
  pagination, native save, and process-death behavior require device evidence;
  host widget captures and the local PDF harness are not that evidence.
- Before an in-place APK update, compare the signing certificate with the
  installed build. Never uninstall JobiX or clear app data to bypass a mismatch.
- Live export activation requires separate approval of cost assumptions,
  accounting readiness, verified runtime gates, and a disable/rollback plan.
  No activation or next phase was started.
