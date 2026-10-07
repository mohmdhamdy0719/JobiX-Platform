# Jobix verification evidence

## ARM64 review build and Android access check — 2026-10-07

- Recreated the ignored development-only `config/dev.local.json` from the
  approved public workspace settings. `dart tool/check_foundation.dart
  config/dev.local.json` passed. Staging and production remain unconfigured.
- Installed Google command-line tools 12.0, Android platform 36, build tools
  35.0.0, NDK 27.0.12077973 and CMake 3.22.1 under ignored workspace storage.
  Android licenses were accepted; Flutter reports the Android toolchain ready.
  Flutter's license check emitted a non-fatal SDK XML version warning.
- `flutter pub get` passed. From `mobile/jobix`, this ARM64 development build
  passed:

  ```sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug --target-platform android-arm64 --split-per-abi \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`
  (97,380,913 bytes), package `com.mhflow.jobix`, version 1.0.0 (1), minimum
  Android API 24, target/compile API 36. The packaged Flutter engine is ARM64.
  APK signature verification passed using APK Signature Scheme v2.
- SHA-256:
  `5b91498893ed9467c2b9c56c1c8b03ba9a58af3cf112f4d354c68099d155d2b7`
- **Physical-device acceptance remains blocked.** `adb devices -l` returned no
  Android devices and Flutter lists only the Linux host. No installation or
  Android launch occurred. Signup email delivery/callback, Keystore-backed
  persistence, Career Profile editing and Resume preview therefore remain
  unverified on a phone. An authorized Android device and, for signup, an
  owner-approved test inbox are still required. An APK build is not device
  verification.
- No product code, database, RLS, Auth settings, staging or production settings
  were changed.

## Real-flow development verification — 2026-10-05

### A. Verified live

- `tool/live_builder_flow_test.dart`: actual Flutter screens against development
  Supabase (no fake Auth/Profile/Core APIs). Confirmed test-account sign-in,
  real startup policy, one stable Profile #1 across repeated reads, six-step
  Continue/Back flow, personal/summary saves, saves in all seven entity sections,
  multiple experience entries, invalid-month Save rejection without a server
  mutation, confirmed experience deletion, Review → Edit → Save → Review, and
  Career using the same profile.
- A successful real mutation acknowledgement was deliberately dropped by the
  host transport. SQLCipher was closed/reopened, the app/providers/SDK recreated,
  and the session recovered. The persisted outbox replayed the original key:
  server version stayed unchanged and each created item appeared exactly once.
  This is host app reconstruction, not Android process-death verification.
- Temporary items were deleted and original personal information, Resume
  Language, summary and existing items restored. The first fake-clock harness
  run required restoration from prior server acknowledgements; the final
  real-time-binding pass completed and verified its own cleanup.
- `tool/live_dev_redesign_test.dart`: confirmed Auth, SDK recovery/startup policy
  and denied direct policy-table access passed.
- `tool/live_profile_sections_test.dart`: live replay, VERSION_CONFLICT,
  VALIDATION_FAILED, DUPLICATE_ITEM, owner B isolation and deletion passed;
  temporary items removed, completeness and Credits unchanged.
- Development Auth configuration was read from the Management API:
  email enabled, signup enabled, confirmation required, built-in mailer,
  two emails/hour and native callback allowlisted. No settings were changed.

### B. Verified with host tests/mocks only

- Full default Flutter suite: 145/145 passed; analyze clean; foundation
  client-secret/layout/token/config checks passed.
- English/Arabic invalid-month draft → Back → disk close/reopen → Edit
  regressions cover experience, education, certification, achievement and
  project drafts. Month labels preserve invalid/incomplete input without a crash.
- AR/EN/RTL layouts, empty states, stale-draft choices and exhaustive Review
  section navigation are covered by host tests, not a physical Android device.
- Live UI test session storage is memory-only. SQLCipher is real disk storage;
  Android Keystore and native App Links are not supplied by this host harness.

### C. Fixed during this verification

- Month formatting now checks the range before indexing localized month names.
  Invalid persisted drafts remain visible/editable; Save validation remains strict.
- Added the opt-in real-network Flutter UI/restart/fault-injection regression.
  It uses a real-time binding and private temporary restoration snapshots.
- No redesign, new features, architecture changes, RLS changes, auto-confirmation,
  external SMTP, AI/model evaluation, staging or production work.

### D. Still requires the Samsung and an authorized inbox

- No connected Android device, installed emulator or `/dev/kvm` is available.
  An APK build is not an installation/launch/runtime test.
- Fresh Sign Up → delivered confirmation email → confirmation callback →
  Sign In → first-registration Step 1 has NOT been verified end to end.
  Existing confirmed accounts work, but that is not proof of new-user delivery.
- Supabase's built-in mailer sends only to project-team addresses, at the current
  two-email/hour limit. The management credential cannot read organization/team
  membership (HTTP 403); no inbox integration is available. An owner-approved
  unused team-member email and owner access to its inbox are needed. Do not use
  an assumed plus alias, auto-confirm, disable confirmation or add external SMTP.
- On the Samsung: install/launch, fresh confirmation link, actual force-stop
  and relaunch, Keystore-backed recovery, offline/interrupted saves,
  native Back/keyboard/scrolling and Arabic RTL must still be checked.
- Official mailer restrictions:
  https://supabase.com/docs/guides/auth/auth-smtp

### Development APK

- Built ARM64 debug APK, package `com.mhflow.jobix`, version 1.0.0 (1),
  minimum Android API 24, target API 36; APK Signature Scheme v2 verified.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.
- Download: `build/verification/jobix-dev-arm64-debug.zip`. Extract first.
  Archive integrity passed. Raw APK exceeds the Library file-size limit.
- SHA-256:
  `545e012cff5ed3fe5ef9604a93a049045a947396a9405690bd8bef9a9d48fe67`.
- Exact command in this workspace:

  ```sh
  cd mobile/jobix
  source /tmp/jobix_env.sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug --target-platform android-arm64 \
    --split-per-abi --dart-define-from-file=config/dev.local.json
  ```

- Existing `config/dev.local.json`, Flutter/JDK/Android SDK and accepted licenses
  are present here. Outside this workspace, supply the genuine development
  configuration and equivalent build toolchain; never put privileged/test-user
  credentials in Dart defines.
- On the computer connected to the Samsung, after extracting the download:

  ```sh
  adb install -r app-arm64-v8a-debug.apk
  adb shell am force-stop com.mhflow.jobix
  adb shell monkey -p com.mhflow.jobix -c android.intent.category.LAUNCHER 1
  ```

  If installation reports a signing mismatch, do not uninstall or clear app
  storage without first preserving data and agreeing on that destructive step.

### E. Exact next recommended task

Samsung acceptance of this development APK, using a fresh Supabase-team-authorized
email: complete signup/confirmation/first entry, all six steps, Review editing,
force-stop/session recovery and offline-save recovery. Fix only observed native
issues. Volunteer Experience and other feature work remain subsequent tasks.

## Screenshot-inspired onboarding update — 2026-10-03

Only the three existing native Flutter introduction screens were revised using
the owner's newly supplied CV, AI-assistance and export/update screenshots.
Approved copy, Skip/Back/Continue behavior, persisted progress, language
switching and the four-question boundary are unchanged. Illustrations are
static, text-free and excluded from accessibility semantics; they do not
introduce AI/export actions, fictional CV facts or unsupported ATS claims.

- `flutter analyze --no-pub`: no issues.
- `dart tool/check_foundation.dart`: passed.
- Ordinary `flutter test --no-pub --reporter expanded`: **88 tests passed**,
  including normal golden comparisons after refreshing only onboarding
  baselines. Four added regressions exercise English/Arabic at 320×568 and
  800×1280 with 1.6 text scaling, reachable fixed Continue, and ordered entry
  into research. Existing auth/profile/draft tests remain passing.
- Actual Flutter English/Arabic renders were visually inspected. Contact
  sheets are `build/review/jobix-onboarding-en.png` and
  `build/review/jobix-onboarding-ar.png`, not physical-device screenshots.
- Development ARM debug APK rebuilt with genuine existing dev defines:
  `build/app/outputs/flutter-apk/app-debug.apk`, 166,618,451 bytes.
  SHA-256: `644df21326c6c011886fe10664798f1fab63340b01b70b07e6b6a4ea4b86a508`.
- APK v2 signature verification passed. Its signing certificate matches the
  previous delivered APK; no uninstall or deletion of local data is required.
- `build/review/jobix-onboarding-debug.zip` contains the unchanged
  `app-debug.apk`, 75,475,988 bytes compressed. ZIP integrity and extracted
  APK hash equality passed.
- No dependencies, localization copy, research/auth behavior, architecture,
  database, provider/policy settings, staging or production were changed.

Physical installation, device rendering and native lifecycle/security acceptance
remain unverified; prior separately recorded live-service evidence was not
rerun or replaced by these widget renders.

## Current delivery — original native redesign, 2026-10-03

The owner's resumed brief supersedes earlier blocked audit/HTML-matching status.
See [VISUAL_REDESIGN_REPORT.md](VISUAL_REDESIGN_REPORT.md) and
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Older sections below are historical
evidence, not current font/icon/policy status.

### Passed

- Final `flutter analyze --no-pub`: no issues.
- Final ordinary `flutter test --no-pub --reporter expanded`: **84 tests passed**,
  including normal comparisons against refreshed visual baselines. Actual
  SQLCipher is used for persistence tests.
- `dart tool/check_foundation.dart`: credential, directional-layout and shared
  design-value checks pass; `git diff --check` has no whitespace errors.
- Real isolated-dev smoke test: **1 live test passed**. Public Auth settings
  Google=true; signed-out startup performs no policy request; confirmed real
  password sign-in, SDK memory-adapter persistence/recovery and authenticated
  startup pass. Authenticated policy RPC returns owner-approved dev
  1.0.0 / 1.0.0 / 1; direct policy-table read remains denied.
- Development-only policy configuration uses the existing protected psql
  mechanism and certificate/hostname-verified TLS. No schema, RLS, production,
  staging or Auth-provider settings were changed.
- English/Arabic 320×568 and 800×1280 research, at 1.6 text scale, retain reachable
  final rows and all four ordered questions. 402×874 renders cover all current
  redesigned flows; a simulated 300px IME inset retains reachable Auth submit.
  Language switching, empty fields, validation, semantic error relocalization,
  App/Resume independence, draft preservation and navigation guards pass.
- ARM debug APK rebuild succeeds with true dev defines, package
  `com.mhflow.jobix`, version `1.0.0+1`, min SDK 24, target/compile SDK 36.
- APK signature verifies (v2); signing certificate matches the prior review
  APK, so no destructive uninstall is requested.
- APK contains approved unchanged brand masters, real Inter and four Noto Sans
  Arabic weights/glyphs plus OFL license. Android/iOS launcher resources use the
  approved icon, replacing Flutter defaults.
- Packaged Flutter engines are ARMv7/ARM64. Other plugin libraries include
  x86/x86_64, but no Flutter engine for those ABIs is packaged; **emulator/x86
  execution is not claimed**.
- Review ZIP integrity passes and the extracted APK hash equals the output APK:
  `3da0dc7ed03916797f9ba2849c1200dc88a5502628f201261d5a05295e32468b`.
- Output APK: `build/app/outputs/flutter-apk/app-debug.apk`
  (166,593,924 bytes). Compressed unchanged package:
  `build/review/jobix-dev-debug.zip` (below the delivery size limit).
- **31 full-size redesigned-flow widget renders** and labelled contact sheets
  delivered in `build/review/`; actual rendered PNGs were visually inspected.

### Explicitly not passed / release dependencies

`adb devices` has no connected device. The owner supplied Galaxy M31 /
M315F/DSN / Android 12 and older problem captures, but no new physical evidence
for this rebuilt APK. Physical installation, Samsung keyboard/system splash,
touch feel, process-death recovery and Keystore acceptance remain unverified.
No simulated capture or debug build is described as physical-device acceptance.

Real Google browser OAuth, email confirmation/recovery delivery and external
deep-link/device lifecycle are not verified by settings flags or test fakes.
Native iOS/Xcode/Keychain verification is unavailable. No confirmation, guard,
session or RLS bypass was introduced.

Terms/Privacy URLs and operational production policy require approved pre-launch
configuration. These were not implementation blockers for this explicitly
authorized development redesign. No next feature slice was started.

## Physical-device visual review — access check, 2026-10-03

**Subsequent owner evidence:** Ten physical-device screenshots were supplied.
They show native launch/initialization, all three English introductions, English
and Arabic Q1, Auth gateway, a signup error and startup failure. The owner later
identified Galaxy M31 / M315F/DSN / Android 12. Q2–Q4, selected states, keyboard
behavior and Personal Information were not established by those old captures.
The owner changed visual strategy to an original
Flutter design system; see [VISUAL_REDESIGN_AUDIT.md](VISUAL_REDESIGN_AUDIT.md).
At audit time, read-only dev checks confirmed Auth health/settings HTTP 200,
email/Google enabled, email autoconfirm disabled and zero operational `mobile`
policy rows. The later explicit dev-only configuration above resolves that gap.
Missing policy is a confirmed authenticated-startup blocker; without device
logs the precise captured exception is not established. No remote changes,
guard bypass, UI implementation or device rerun occurred during this audit.
Review/redesign remains incomplete pending brand/legal inputs and policy
remediation authorization. The initial access check below predates the captures.

**Owner clarification:** Approved logo/icon masters are now supplied but not
integrated. The review device is Samsung M315F/DSN (Galaxy M31), Android 12.
Terms/Privacy URLs remain a documented pre-launch dependency. The owner requires
stopping at missing policy values, with no database/policy/migration changes.
The absent `mobile` policy lacks required `minimum_supported_version` and
`policy_version`; `recommended_version` is optional. No values were invented,
no guard was bypassed, and no new implementation or device rerun is claimed.

- `adb devices -l` returned an empty device list. No physical Android device
  is accessible from this workspace, and no owner-provided device captures or
  observations have been supplied for this review.
- The existing review ZIP and original APK are present at the paths below.
  No installation, native launch or interactive visual inspection was performed.
- The previously documented absent operational `mobile` policy and unverified
  email/Google provider setup remain review limitations; their live state was
  not rechecked or changed. Startup/authentication guards were not bypassed.
- Review is **blocked, not complete**. Physical-device evidence is needed for
  introduction, Q1–Q4, authentication and reachable Personal Information,
  English/Arabic direction, independent App/Resume Language, initial empty
  fields, touch targets, keyboard, scrolling and navigation. An observed issue
  must precede a minimal authorized UI fix and a device rerun.
- No UI/product, architecture, database, provider/policy, staging or production
  change was made. Build/signature/widget evidence is not device acceptance.

## Physical-Android review APK — 2026-10-03

Development/debug build only, explicitly authorized for visual review.

- Installed Android SDK/build components and accepted their licenses. Flutter
  doctor reports a healthy Android toolchain. No emulator or replacement
  Expo/React Native/Linux application was created.
- Restored ignored dev configuration from existing workspace public settings.
  `dart tool/check_foundation.dart config/dev.local.json` passed. No new
  credentials or staging/production configuration was created.
- The first default debug build requested an unavailable legacy x86 profile
  engine artifact. The successful build explicitly targets physical-device
  ARM CPUs. Pinned Android NDK 27.0.12077973 to satisfy the existing native
  plugins instead of the older wrapped-Flutter default.
- Successful command, from `mobile/jobix`, with the workspace-local Gradle cache:

  ```sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug \
    --target-platform android-arm,android-arm64 \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-debug.apk`
- Download archive: `mobile/jobix/build/review/jobix-dev-debug.zip` (73,958,679
  bytes), containing the unchanged `app-debug.apk`. ZIP integrity checked.
  The raw APK exceeds the Library's 100 MiB upload limit.
- Size: 143,700,892 bytes. SHA-256:
  `700ce05a9443b41b10ed6c400d4ee53852ab3fc5c9042a5417d6652ebf967fc7`
- `apksigner verify --verbose`: passed, APK Signature Scheme v2.
- Package `com.mhflow.jobix`, version 1.0.0 (1), debuggable, minimum API 24,
  target/compile API 36. Flutter engines are present for ARMv7 and ARM64;
  other ABI plugin libraries do not imply x86 emulator support.
- No product flow/UI, architecture, schema, migration or remote database changes.
  The standard three-environment build script is unchanged and was not used
  for this specifically authorized development-only review build.

**Not verified:** installation/launch on a physical device, native keyboard,
Keystore/session restore and the full interactive Auth/Profile journey.
The documented operational-policy/provider prerequisites are not bypassed or
changed by producing an APK. No production/staging build or release acceptance
is claimed. Earlier missing-toolchain/build statements below are historical;
remaining native-device acceptance gates still apply.

## HTML/product correction — 2026-10-03

Completed only the requested first-slice revision. No next feature, server
migration, live database write, environment/configuration change or original
HTML edit was made.

- `flutter gen-l10n`, `dart format lib test`, `flutter analyze`: passed;
  analyzer reported **no issues**.
- `dart tool/check_foundation.dart`: public-client secret, directional-layout
  and token checks passed. `git diff --check`: passed.
- Final `flutter test` without `--update-goldens`: **68 tests passed**.
  This includes 20 first-slice contract tests and 15 widget tests, plus the
  existing Foundation tests.
- New regressions cover every incomplete first-time stage and direct Auth,
  Login, confirmation/reset URLs; Skip remains introduction-only.
- Rendered-content assertions cover all three English introduction pages,
  research, empty Personal and mixed-language Personal; they reject fictional
  identities/location/contact claims and the named unsupported ATS/marketing
  claims. The approved ATS-friendly headline remains.
- Empty Personal controllers/server snapshots are asserted for all eight
  fields. Displaying the EG suggestion and saving Resume Language alone sends
  no Country or other personal values. Accepting Egypt explicitly creates only
  a draft until another explicit Save.
- Resume changes preserve content/App Language. App Language changes preserve
  Resume Language, CV labels and user content.
- Disposable local PostgreSQL Foundation/slice RLS/RPC/bootstrap checks passed.
  The empty-bootstrap assertion now covers **all eight** personal fields,
  plus null Profile name and Resume Language. No live checks were repeated.
- Regenerated and visually inspected native-widget goldens: all three
  onboarding pages; all four English research pages; Arabic research;
  empty English Personal (a tall all-section test render); mixed English
  App/Arabic Resume Personal. Existing Auth/Home baselines also still pass.
  A 320px phone/1.6x text check passes. These are test renders, not device captures.

Exact source adaptations and remaining HTML differences are recorded in
[FIRST_SLICE.md](FIRST_SLICE.md#deliberate-differences-from-the-original-html).
The provider configuration, operational policy, native build/device/security
and full location-catalog gates below remain unverified/unchanged.

## First vertical slice — 2026-10-03 (pre-correction evidence)

This is the separately authorized feature slice; it supersedes the historical
Foundation-only scope below, not the remaining native acceptance gates.
See [FIRST_SLICE.md](FIRST_SLICE.md) for source authority, implemented
contracts, minimal Architecture V2 patches and visual handoff limitations.

### Passed in the current checkout

- Flutter localization/Drift generation and dependency resolution.
- `flutter analyze`: **no issues**.
- `flutter test`: **65 tests passed**, including the 19 new contract and
  13 new native-widget journey tests. That run compared goldens normally,
  without `--update-goldens`; no screenshot mismatch or layout error.
- Actual SQLCipher encrypted v1→v2 migration, settings preservation, repeated
  singleton onboarding writes, restart/readback, account-scoped drafts,
  offline retention and offline acknowledged-cache use.
- Atomic research ownership/command writes reject a stale snapshot, a
  switched account or signed-out caller. Context cannot be assigned to a
  different account during a delayed response.
- Three-screen order/Skip, ordered four-question research retention and Q4's
  maximum, confirmation guards, Google/reset boundary calls, returning Home,
  new-registration Personal entry, Save & Continue Later and safe Discard.
- Sign-out explains that local unsaved work is removed but acknowledged
  server data remains; cancelling it preserves the draft.
- Unknown-outcome retries use the same frozen command after further edits;
  version conflicts do not silently overwrite, and non-network failures never
  fall back to an old acknowledged Profile.
- Mixed English App/Arabic Resume labels and direction without content
  translation; optional custom city/history selection; 320px phone and
  1.6× text navigation; native goldens for onboarding, research, auth, Home
  and Personal Information.
- `dart tool/check_foundation.dart`: public-client secret, directional-layout
  and token checks passed. `git diff --check` passed.
- Disposable local PostgreSQL Foundation + slice checks: Auth-trigger
  bootstrap, exactly one empty Profile/slot/personal record per new account,
  no Resume-language default, duplicate prevention, anonymous denial, owner
  isolation, lifecycle exclusion, partial saves, idempotent replay,
  payload-mismatch rejection, version conflicts and first-entry claim isolation.

### Live isolated-development SQL

Applied the two source migrations, in order, using the server-only protected
session-pooler credential, the uploaded public CA and verified TLS:

- `202610030002_first_vertical_slice.sql`
- `202610030003_registration_entry.sql`

The target was checked against the already authorized isolated development
project. Staging/production were not contacted or changed. The existing
Foundation schema was required, not replaced.

The real Supabase PostgreSQL roles and `auth.uid()` passed the slice bootstrap,
RLS and save/retry checks. First-entry routing is server-authoritative:
new identities can claim first entry once; returning identities cannot be
misclassified solely by choosing a Signup or Login button. Anonymous callers,
other owners and inactive accounts cannot claim another user's state.
SQL fixtures were inserted only inside a rollback transaction and removed
by rollback; no new persistent Auth account or profile test data remains.
No operational app-policy version was seeded.

These are **live SQL** results, not real Google/email provider round trips,
native deep-link, Keystore/Keychain or new PostgREST/SDK journey results.
Historical Foundation live HTTP/session evidence below remains separate.

### Still unverified / unavailable

- The previously supplied, ignored public dev client config file is absent
  in this checkout and must be restored from genuine settings.
- Staging/production public settings remain NOT_CONFIGURED. The three-project
  native build gate is preserved; no APK/IPA or release build pass is claimed.
- Supabase Google provider configuration, confirmation enforcement/mail
  delivery, reset emails and native redirect allowlisting/round trips.
  The required redirect is `com.mhflow.jobix://auth/callback`.
- Foundation recorded the operational `mobile` policy as absent; no slice
  migration creates it. Authenticated startup remains fail-closed without
  an administrator-approved policy.
- Physical Android/iOS device storage, process death, backups/device transfer,
  native RTL/locale/deep-link behavior and macOS/Xcode/CocoaPods.
- Full approved location autocomplete catalog; only account history/custom
  input is implemented. No dataset was invented or downloaded.
- Final separate visual frames for confirmation/recovery/conflicts;
  these use minimum structural UI with the accepted shared styling.
  Research HTML frames exist and are used by the correction above.

The source-tested slice is implemented; the unavailable native/provider gates
are not certified. Do not interpret this as production readiness.

## Final disposition — 2026-10-03

The user accepted the successful live Supabase verification and authorized
closing this verification task with the remaining unavailable prerequisites
recorded as **environment blockers**. This closes the authorized work, not the
unverified native acceptance gates. No native build or device pass is claimed.

### Exact environment blockers and unverified checks

| Environment blocker | Checks that remain unverified |
| --- | --- |
| Genuine staging and production public Supabase configuration is unavailable; both remain `NOT_CONFIGURED`. | The existing three-distinct-project build gate stops Android before compilation. No Android APK build is verified. |
| No macOS runner with Xcode and CocoaPods is available. | iOS dependency installation, Xcode validation, compilation and native integration are unverified. |
| No physical Android device is available. | Android Keystore-backed session persistence across process death, immediate sign-out after real cold-start restore, native SQLCipher wrong/missing-key behavior, backup/device-transfer exclusion, locale restoration, RTL and native startup guards are unverified. |
| No physical iOS device is available. | iOS Keychain-backed session persistence across process death, immediate sign-out after real cold-start restore, native SQLCipher wrong/missing-key behavior, backup/device-transfer exclusion, locale restoration, RTL and native startup guards are unverified. |

Do not create or invent staging/production projects or credentials to satisfy
these gates. Staging/production configuration remains unchanged. Do not bypass
the build gate or substitute fake credentials, simulated native verification,
browser results or in-memory SDK results for genuine native evidence.
Further verification requires the actual missing prerequisites and separate
authorization; no feature, UI or architecture work is authorized.

### Persistent migration and data disposition

- The authorized Foundation migration remains applied to isolated **dev**:
  `public.users`, `public.app_policies`, their RLS/grants and
  `public.read_app_policy(text)`. It was not reverted or reapplied.
- SQL test rows were rolled back. Temporary live-verification Foundation user
  and policy rows were removed, and their absence was confirmed during the
  successful run. No operational minimum-version policy remains seeded.
- The user-supplied disposable Auth accounts remain; setup/test sessions were
  revoked. The harness did not create or delete those Auth accounts.
- No staging/production migration or data change occurred.
- `supabase/tests/local_auth_fixture.sql` was never deployed to Supabase.

Finalization changes documentation only. Earlier successful results below are
retained without repeating live writes or claiming unavailable native checks.

### Files changed during this verification work

Source/documentation/configuration inventory, excluding generated Flutter
outputs and installed SDK/cache files:

- `mobile/jobix/README.md`
- `mobile/jobix/VERIFICATION.md`
- `mobile/jobix/tool/live_supabase_test.dart`
- `mobile/jobix/tool/verify_live_supabase.py`
- `mobile/jobix/android/app/build.gradle.kts`
- `mobile/jobix/android/app/src/main/kotlin/com/example/jobix/MainActivity.kt`
  (removed during the approved package relocation)
- `mobile/jobix/android/app/src/main/kotlin/com/mhflow/jobix/MainActivity.kt`
  (approved package relocation)
- `mobile/jobix/ios/Flutter/AppFrameworkInfo.plist`
- `mobile/jobix/ios/Podfile`
- `mobile/jobix/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/jobix/config/dev.local.json` (ignored public dev configuration)
- `.replit` (authorized tooling setup)
- `attached_assets/0_prod-ca-2021_1791007607421.crt` (uploaded public CA)
- `.agents/memory/MEMORY.md`
- `.agents/memory/database-network-access.md`
- `.agents/memory/native-tooling.md`
- `.agents/memory/policy-rpc-compatibility.md`
- `.agents/memory/jobix-authority.md`

This finalization changes only `mobile/jobix/VERIFICATION.md` and
`.agents/memory/jobix-authority.md`. The existing migration source and local
auth fixture are unchanged; staging/production configuration is unchanged.

## Local verification — 2026-10-02

Executed from the Linux workspace:

```sh
JOBIX_SQLCIPHER_LIBRARY=/nix/store/j6vh2fybrzqqac8fkhwdd2dzvk539ql2-sqlcipher-4.6.1/lib/libsqlcipher.so \
  bash mobile/jobix/tool/verify.sh
```

Result: exit status 0.

- Dependency resolution, localization and Drift generation passed.
- Public-client secret, directional-layout and design-token checks passed.
- Flutter analysis reported no issues.
- All 33 Flutter tests passed.
- SQLCipher 4.6.1 exercised encrypted database creation/reopening, wrong-key
  rejection, missing-key rejection and locale persistence on Linux.
- The real Supabase SDK restoration/sign-out test passed with synthetic session
  data, in-memory secure-storage replacement and fixture HTTP transport.
- Disposable local PostgreSQL checks passed for anonymous denial, owner
  isolation, deleted-account exclusion, authenticated policy RPC access,
  direct policy-table denial and client mutation denial.

These results do **not** verify Android Keystore, iOS Keychain, device backups,
device transfer or live Supabase Auth/PostgREST. Expected SQLCipher
wrong-key diagnostic errors were emitted during the passing negative test.

## Saved configuration checks

After the workspace configuration was supplied:

- `dart tool/check_foundation.dart config/dev.local.json` passed. The ignored
  dev file contains only public client configuration.
- Static checks confirmed the Android namespace/activity/application ID,
  compile/minimum/target API levels, all three iOS app and test bundle IDs,
  all project deployment targets, Podfile and Flutter framework minimum OS,
  and package version agree with the approved values.
- `git diff --check` passed.

These checks do not claim native compilation. No staging/production local
configuration was generated from the `NOT_CONFIGURED` markers.

## Remaining acceptance gates

| Requirement | Current evidence / blocker |
| --- | --- |
| Approved application identifiers, OS targets and build version | Supplied through workspace configuration: `com.mhflow.jobix` on both platforms, Android minimum API 24 / target API 36, iOS 13.0, version 1.0.0. Applied to native build settings; native compilation remains unverified. |
| Public dev/staging/prod Supabase configuration | Public dev configuration supplied. Staging and production explicitly marked `NOT_CONFIGURED`. Three distinct project hosts are still required by the build gate. |
| Android SDK and APK build | SDK platform 36, build tools 34/35, NDK 26.3.11579264, CMake 3.22.1 and command-line tools 16.0 installed. Build command stopped at missing staging configuration before compilation. No APK verified. |
| iOS validation/build | User confirms no macOS runner is available. No iOS build verified. |
| Native session persistence and immediate cold-start sign-out | Fixture and live real-session SDK restart/sign-out checks pass with in-memory storage. Native devices are still required to verify Keystore/Keychain and actual process restarts. |
| Native SQLCipher wrong/missing-key behavior | Linux tests pass; native library/storage integration remains unverified. |
| Backup and device-transfer exclusion | Platform configuration exists; actual backup/transfer behavior remains unverified. |
| Native locale restoration, RTL and startup guards | Local tests pass; native device execution remains unverified. |
| Live Supabase migration and isolation/RPC checks | Passed: authorized migration, real-role SQL RLS tests, anonymous HTTP denial and authenticated PostgREST isolation/safe RPC checks with two real Auth accounts. |
| Live minimum-version enforcement and session restoration/sign-out | Passed against live dev Auth/RPC with the Foundation startup guard and in-memory session adapter. Temporary policy removed; native startup/storage remains unverified. |

## Safety boundary

Full Foundation/native verification requires evidence for every remaining gate.
The user-authorized task closure above does not certify those blocked gates.
Do not substitute a browser/desktop result for native verification.
Never deploy `supabase/tests/local_auth_fixture.sql` to Supabase.
Only `supabase/migrations/202610030001_foundation.sql` is the application
migration, and applying it requires explicit authorization for the isolated
development project. Flutter accepts only public publishable/anon client keys;
never put service-role/admin credentials into client configuration.

No later feature slice is authorized by this verification work.

## Authorized setup and live connectivity — 2026-10-03

- User authorized Android SDK license acceptance and installation.
- User confirmed the configured dev project is isolated and authorized the
  existing Foundation migration only.
- User stated that no macOS runner or Android/iOS physical devices are
  currently available. `adb devices` also reported no attached devices.
- Public-key requests to the configured dev project returned:
  - `/auth/v1/health`: HTTP 200.
  - `/rest/v1/users?select=id&limit=1`: HTTP 404, `PGRST205`.
  - `/rest/v1/rpc/read_app_policy`: HTTP 404, `PGRST202`.

The latter responses report missing API resources, not proof of database
schema absence or successful RLS enforcement. Administrative schema inspection
is required before applying the migration. No remote SQL, user creation or
policy writes were performed by these connectivity probes.

## Android setup result — 2026-10-03

The workspace package installer supplied `android-tools` and the standalone
SDK manager after rejecting the nested Nix Android SDK package attribute.
SDK packages were downloaded from Google's repository. The install was moved
to ignored workspace toolchain storage after home-directory quota exhaustion;
the incomplete NDK install was replaced and its package metadata checked.

- Flutter detected platform 36 and build tools 35.0.0.
- SDK manager 16.0 runs successfully.
- Build-tools `aapt2 version` runs successfully.
- NDK package metadata and CMake executable are present.
- Authorized `android-sdk-license` acceptance was recorded for installed
  packages. Six unrelated SDK license agreements remain unaccepted; Flutter
  reports this warning.
- Latest command-line tools 23.0 now use Android CLI in place of SDK manager.
  They were removed from the active SDK so Flutter 3.32.0 uses tools 16.0.
- `bash mobile/jobix/tool/build_android.sh dev` failed at
  `config/staging.local.json` because staging/production are not configured.
  No native compilation occurred. The build gate was intentionally retained.

SDK discovery and executable checks are not an APK build or device test.

## Dev database connection check — 2026-10-03

The server-only database URL was supplied through workspace Secrets. Its
connection target matched the authorized isolated dev project and public dev
configuration. Neither its value nor password was displayed or embedded in
Flutter.

Read-only connection attempts failed before database authentication. Network
diagnostics confirmed the direct endpoint resolves only to IPv6, and TCP
connection failed with `EAFNOSUPPORT` in this workspace. Administrative schema
inspection, migration application and live SQL/RLS verification were therefore
unexecuted at this stage. A session-pooler connection URL on port 5432 was
required. The password had not yet been validated, because no database
connection was established. Subsequent pooler and verified-CA checks below
resolved this blocker.

## Replacement session-pooler check — 2026-10-03

The replacement secret passed the authorized-project and port checks. TCP
reachability and PostgreSQL authentication succeeded using `sslmode=require`.
Read-only schema inspection confirmed:

- Existing Supabase `auth.users`: present.
- Foundation `public.users`: absent.
- Foundation `public.app_policies`: absent.
- Foundation `read_app_policy(text)` RPC: absent.

The backend `pg_stat_ssl` flag was false; through a pooler, this describes the
pooler-to-database connection, not the TLS client-to-pooler connection.
`sslmode=require` does not validate the server certificate or hostname.

A separate certificate-validating client handshake failed with
`CERTIFICATE_VERIFY_FAILED` (self-signed certificate in chain). Administrative
writes were paused before reading/applying migration SQL. The public Supabase
server root/CA certificate from the authorized project's dashboard is required
to verify this connection. No migration, test inserts or policy writes occurred
before the CA was supplied and verification succeeded, as recorded below.

## Authorized migration and live RLS — 2026-10-03

The public CA certificate supplied from the isolated dev project enabled
client-to-pooler certificate and hostname validation with TLS 1.3.
PostgreSQL administrative calls used `sslmode=verify-full` with that CA.

The existing `202610030001_foundation.sql` migration was applied to the
authorized isolated development project after checking that Supabase Auth
exists and that the Foundation objects do not already exist. The migration
transaction included a precondition guard and transaction-level advisory lock
to prevent accidental reapplication or overwriting an existing schema.

`supabase/tests/rls.sql` then passed against the real Supabase roles and
`auth.uid()` function. Only rollback-only test rows were inserted; the local
auth schema/role fixture was never read, applied or deployed to Supabase.

Passing checks:

- Anonymous SQL cannot read users or invoke the policy RPC.
- Authenticated owners see only their own non-deleted user row.
- Deleted accounts are excluded.
- Authenticated policy RPC access succeeds; raw policy access fails.
- Client user/policy mutations are denied.
- Both Foundation tables have RLS enabled.
- The RPC is security-definer with an empty search path and does not project
  private `configuration`.
- Follow-up queries confirmed no Foundation user rows, policy rows or temporary
  auth test rows remained after the test transaction rolled back.
- Anonymous PostgREST user query: HTTP 200, empty result.
- Anonymous direct policy query and RPC: HTTP 401, `42501`.

These are live SQL/RLS and anonymous HTTP checks, not proof of authenticated
HTTP behavior, real Auth session restoration, minimum-version startup guards,
or native secure storage. The live Auth/HTTP gates were subsequently checked
below; native acceptance gates remain open.

## Live Auth, authenticated API and SDK verification — 2026-10-03

Two distinct, disposable, email-confirmed dev Auth accounts were supplied
through workspace Secrets. Both password sign-ins succeeded. The opt-in
`tool/verify_live_supabase.py` harness then created temporary Foundation user
rows and a test-only `mobile` minimum-version policy, refusing to overwrite
existing rows. Administrative calls used the verified dev session pooler;
Flutter received no database/admin credential.

Passing live checks:

- Each real JWT can read exactly its own Foundation user row, and cannot read
  the other account's row through PostgREST.
- Direct policy-table access is denied; client user insert/update/delete and
  policy update requests are denied with PostgreSQL permission errors.
- Authenticated RPC returns exactly the four public policy/version fields,
  never the private test configuration.
- The real Foundation startup orchestration blocks approved build version
  `1.0.0` against temporary live minimum `2.0.0`. A test caller at version
  `2.0.0` is permitted; this does not change the approved package version.
- A missing live policy fails closed. The installed SDK can surface HTTP 406
  for an empty RPC `maybeSingle` result rather than returning null; either
  explicit failure prevents startup.
- A genuine Auth session is persisted through `SecureSessionStorage`, then
  refreshed against live Auth and restored after SDK disposal/reinitialization.
- With implicit recovery deferred, explicitly awaited restoration completes
  before sign-out. Immediate sign-out clears current/persisted session state
  and receives successful live server logout.
- The revoked refresh token is rejected by live Auth; no delayed recovery
  resurrects the session.
- A later SDK restart remains signed out, and the signed-out startup guard
  makes no policy request.
- Temporary Foundation user/policy rows were removed and their absence
  confirmed. Setup/test sessions were revoked; supplied Auth accounts remain.

The harness uses a memory-only `SecretStore` across SDK instances. This is not
process-death persistence or Android/iOS secure-storage proof. Database opening
is a test port here, not native SQLCipher verification. Native cold starts,
backup/transfer exclusion, encrypted storage, locale/RTL and device startup
still require the unavailable native runners/devices. No staging/production
resource, product feature, or operational policy was created.