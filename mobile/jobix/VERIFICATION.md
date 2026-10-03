# Jobix verification evidence

## First vertical slice — 2026-10-03

This is the separately authorized feature slice; it supersedes the historical
Foundation-only scope below, not the remaining native acceptance gates.
See [FIRST_SLICE.md](FIRST_SLICE.md) for source authority, implemented
contracts, minimal Architecture V2 patches and visual handoff limitations.

### Passed in the current checkout

- Flutter localization/Drift generation and dependency resolution.
- `flutter analyze`: **no issues**.
- `flutter test`: **65 tests passed**, including the 19 new contract and
  13 new native-widget journey tests. Final run compared goldens normally,
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
- Final separate visual frames for research/confirmation/recovery/conflicts;
  these use minimum structural UI with the accepted shared styling.

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