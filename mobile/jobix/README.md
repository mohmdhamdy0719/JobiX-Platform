# Jobix — Foundation and first vertical slice

Native Flutter, separate from the pnpm starter. The approved first slice adds
three onboarding screens, four research questions, Supabase authentication,
an automatically provisioned empty Profile #1, Home and Personal Information.
AI/ATS, Credits, billing, export, rendering, translation and background sync
remain out of scope. See [FIRST_SLICE.md](FIRST_SLICE.md) for the minimal
dependency patches, contracts, visual sources and outstanding gates.

## Toolchain

Verified here with Flutter 3.32.0 / Dart 3.8.0, locked pub dependencies and
SQLCipher 4.6.1 on Linux. `.replit` installs Flutter, SQLCipher, PostgreSQL and
JDK through Nix. Flutter's wrapped SDK requires `flutter pub run build_runner
build`; plain `dart run` doesn't locate the Flutter SDK in this environment.

## Configuration

Copy `config/{dev,staging,prod}.example.json` to matching `.local.json` files.
The ignored local files must contain only the public project URL and
publishable/anon client key, environment and app version. Never use a service
key. Obtain the public values through the workspace configuration flow.
The three hosts must differ; builds check this. Public development configuration
was previously supplied, but the ignored `dev.local.json` is absent in this
checkout and must be restored from genuine public settings. Staging and production remain
`NOT_CONFIGURED`; do not turn that marker into a client configuration.

`APP_VERSION` must equal the built package version. The workspace configuration
approves version 1.0.0, Android application ID and iOS bundle ID
`com.mhflow.jobix`, Android minimum API 24 / target API 36, and iOS minimum 13.0.
Android compile API is 36 to match the approved target.
No release signing configuration is supplied.

## Verify

See [VERIFICATION.md](VERIFICATION.md) for recorded local results and the
remaining native-device and live-Supabase acceptance gates.

```
export JOBIX_SQLCIPHER_LIBRARY=/absolute/path/to/libsqlcipher.so
bash tool/verify.sh
bash tool/build_android.sh dev
```

`tool/verify.sh` runs code generation, the public-client secret/layout/token
checks, analysis, tests and the disposable PostgreSQL RLS test harness.
`JOBIX_SQLCIPHER_LIBRARY` is required, not optional: encryption tests never
silently substitute plain SQLite. SQLCipher's diagnostic error messages in
wrong-key tests are expected.

Goldens use a bundled **test-only** DejaVu Sans (license in `test/assets`).
It is not a production font and is not included in the app asset manifest.
SHA256: ae7b7855e115a5966d8b1b3f80f254ccc117ec86f9965e202ee2940453837280.
Approved HTML references now supply Inter, typography, radii and colors.
Inter/OFL and the reference logo are bundled production assets.

## Startup and authenticated app policies

Config -> encrypted database/settings -> secure Supabase session restore.
Signed-out clients reach onboarding/research/auth without reading
app policies: V2 authorizes policy reads only to authenticated clients.
Authenticated sessions call `read_app_policy('mobile')`. Missing policy,
malformed version, connection failure or storage failure is explicit startup
failure. A minimum version above the built version reaches the update-required
placeholder. Subsequent auth changes re-run the guard.

The policy row is deliberately not seeded: its production version is a server
operational decision. Populate it through privileged administration before
using authenticated startup against Supabase. The opt-in verification harness
uses a temporary test-only policy and removes it afterward; it never chooses
an operational minimum version.

Email signup, confirmed login, Google OAuth and password reset are provided. Both
Supabase session storage and the PKCE adapter use secure storage, never its
default unencrypted SharedPreferences adapters. Android's secure plugin uses
**encrypted** preferences backed by Keystore; no plaintext session preferences
are used.

## Local security

Drift v1 has only `infrastructure_metadata` and `local_settings`; the tested
v1→v2 migration adds encrypted onboarding progress, acknowledged Profile
snapshots and account-scoped drafts.
SQLCipher verifies `cipher_version` and reads page metadata before proceeding.
A random 256-bit key stays in secure storage. A missing key deletes only the
orphaned local Foundation DB and sidecars before creating a fresh DB.
Wrong or corrupt existing keys fail; they never trigger destructive resets.
No background resync, outbox or worker is implemented.

Android disables backup and excludes root/files/databases/shared preferences
from both cloud backup and device transfer. HTTPS only.
iOS marks the Application Support Jobix directory backup-excluded **before**
database creation and uses `first_unlock_this_device` Keychain storage.
Live device Keychain/Keystore and restore tests still require native devices.

## Server

The Foundation migration in `supabase/migrations` creates:
* `users` referencing existing Supabase `auth.users`, owner-only non-deleted
  reads, no client lifecycle writes.
* `app_policies`, no direct client access; authenticated safe RPC projects
  only public version fields, with an empty search path.

The existing migration has been applied, with explicit authorization, to the
isolated development Supabase project. No staging/production database was
changed. Live SQL checks passed against the real Supabase roles and `auth.uid()`;
the temporary SQL test rows were rolled back. Anonymous PostgREST checks passed.
Live authenticated PostgREST isolation, safe RPC/minimum-version guards, and
real Auth session restoration/sign-out checks now pass using disposable dev
accounts. The session adapter uses an in-memory test store for these checks,
not native Keystore/Keychain; native acceptance remains open.
`supabase/tests/local_auth_fixture.sql` is **test-only**, never deploy it to
Supabase. It was not used on Supabase. Local PostgreSQL tests still emulate auth
identity and roles; keep their evidence separate from the live checks recorded
in [VERIFICATION.md](VERIFICATION.md).

### Opt-in live checks

With isolated-dev authorization and the four `JOBIX_DEV_TEST_EMAIL_A/B` and
`JOBIX_DEV_TEST_PASSWORD_A/B` workspace Secrets for two distinct, disposable,
email-confirmed Auth accounts, run from the workspace root:

```sh
python3 mobile/jobix/tool/verify_live_supabase.py \
  --allow-temporary-dev-fixtures \
  --ca-file /absolute/path/to/the/public-supabase-ca.crt
```

This is separate from `tool/verify.sh`. It requires the server-only
`JOBIX_DEV_DATABASE_URL` session-pooler credential, validates the authorized
dev target, uses verified TLS, and refuses to overwrite existing Foundation
rows for either account or an existing `mobile` policy. Only temporary
Foundation rows are inserted; Auth accounts are not created or deleted.
Temporary rows and test sessions are cleaned up even after a test failure.
On a forced process termination, inspect the dev fixtures before rerunning.
The database credential is not passed into the Flutter test. Credentials,
session tokens and raw SDK errors are not displayed or written to files.
The local Supabase auth fixture is never used remotely.

## Native build gates

Android SDK platform 36, build tools 34.0.0/35.0.0, NDK 26.3.11579264,
CMake 3.22.1 and command-line tools 16.0 are installed in ignored workspace
toolchain storage. `ANDROID_HOME` and `ANDROID_SDK_ROOT` point to that location.
JDK 17 is installed. SDK license acceptance was authorized and recorded for
installed packages. Flutter still reports other SDK licenses unaccepted;
unrelated license agreements have not been accepted.

Command-line tools are pinned because the latest tools replace `sdkmanager`
with Android CLI, which Flutter 3.32.0 does not recognize for license checks.
Android APK verification is still blocked by missing staging/production public
configuration; the three-project build gate has not been bypassed.

iOS build requires macOS, Xcode and CocoaPods. The user confirms no macOS runner
or Android/iOS physical devices are currently available. Podfile, project and
backup bridge are present but device integration is unverified.

The native splash uses only DESIGN.md navy, no logo or new artwork. Flutter's
generated icon files are scaffolding assets, not Jobix assets. The approved
reference logo is bundled for Flutter UI. Launcher icons and missing visual
handoffs remain unverified.
This project has no browser preview: don't create a web/Expo replacement.