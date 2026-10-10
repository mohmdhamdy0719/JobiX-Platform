# Jobix

Jobix is a native Flutter career-profile and resume app backed by Supabase.
Start with `README.md`, `PROJECT_STATUS.md`, and `docs/AI_HANDOFF.md` for the
2026-10-09 handoff. `PROJECT_HANDOFF.md` is an earlier, superseded snapshot.
The root pnpm workspace is supporting Replit infrastructure, not another
Jobix client.

## Stack and project map

- `mobile/jobix/` — Flutter 3.32.0 / Dart 3.8.0, Riverpod, Drift and encrypted
  SQLite (SQLCipher), Supabase authentication and database.
- `mobile/jobix/lib/main.dart` — native application entry point.
- `mobile/jobix/supabase/` — migrations, permission tests and maintenance scripts.
- `mobile/jobix/README.md` — native setup and public client configuration.
- `mobile/jobix/VERIFICATION.md` — verification history and limitations.
- `docs/handoff/` — architecture, decisions, known gaps and migration guidance.
- `attached_assets/` — authoritative architecture, product and design references.

## Restore and verify locally

The imported environment supplies Flutter, SQLCipher and PostgreSQL through Nix.
From the workspace root:

```sh
cd mobile/jobix
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter pub run build_runner build

export JOBIX_SQLCIPHER_LIBRARY="$(dirname "$(dirname "$(readlink -f "$(command -v sqlcipher)")")")/lib/libsqlcipher.so"
test -f "$JOBIX_SQLCIPHER_LIBRARY"
dart tool/check_foundation.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
bash tool/test_rls.sh
```

Use real SQLCipher, not plain SQLite. The permission-test script creates and
cleans up a disposable local PostgreSQL instance; it does not contact Supabase.
Live checks under `tool/live_*` require separate authorization and configuration.

Import verification on 2026-10-07: dependencies and generated code restored,
analysis clean, all 178 Flutter tests passed, client safety checks passed and
disposable PostgreSQL permission tests passed. No application code was changed.

Fresh-import local verification on 2026-10-10: restored the committed Flutter
lock and generated code; client checks and analysis passed, all 208 Flutter
tests passed, and the complete disposable PostgreSQL permission/export harness
passed, including all eight guarded export acceptance cases. The isolated PDF
backend's frozen production dependencies were restored and all 104 Node tests
passed. These results supersede the older local RLS evidence gap only; they
do not verify live Supabase, GCS, deployed images, or a native device.
Two fixture-tool imports were normalized to package imports, and `tool/verify.sh`
now enforces the committed lockfile. No dependency versions or product behavior
were changed.

Restore the PDF backend separately from the unrelated root Node workspace:

```sh
cd mobile/jobix/backend/pdf
pnpm install --ignore-workspace --frozen-lockfile --prod
node --test test/*.test.mjs
```

## Native launch requirements

The current app has Android/iOS targets, not a browser or Linux desktop target.
At the 2026-10-07 import check, the Android SDK path was missing and only local
automated checks were requested. Subsequent authorized work restored Android
tooling, built the ARM64 debug APK and obtained owner-confirmed personal PDF
download/open evidence on Samsung M31. These ignored local toolchains do not
transfer in a Git clone. No device is attached to the Replit workspace; do not
confuse the owner's phone confirmation with ADB instrumentation. Supporting
web-service workflows are not a running Jobix mobile app.

On 2026-10-10 the owner authorized restoring Android tooling and accepting its
SDK licenses. The current import now has Google command-line tools 12.0,
platform-tools, Android API 36, build-tools 35.0.0/36.0.0 and NDK 27.0.12077973
under ignored `.local/toolchains/android-sdk/`. Flutter doctor confirms a healthy
Android toolchain and accepted licenses; `aapt2` and NDK Clang execute correctly.
Tool downloads and temporary extraction stayed in ignored workspace storage.
Java 17 remains supplied by Nix. Android Studio and Flutter's Chrome target are
not installed; neither is required for this Android command-line setup.

The ignored `config/dev.local.json` was restored from the existing public
development settings and passed the client configuration check. No server
credentials, staging/production configuration or export-gate changes were added.
No Android device is connected. No APK build, native launch or live-service
verification was performed in this setup; local tests are not device evidence.
The SDK and public local configuration must be restored again in a fresh clone.

To launch Android, connect an authorized device, confirm its identifier with
`flutter devices`, then run from `mobile/jobix/`:

```sh
flutter run -d <android-device-id> \
  --dart-define-from-file=config/dev.local.json
```

Do not fabricate staging/production configuration or release signing. The
standard Android build script deliberately requires all three environments to
be configured; follow the documented development-only build path where approved.
Do not build an APK without separate approval or assume a new debug signer can
update the previously installed app; verify signing continuity first.

No native launch workflow was started because there is no Android device.
The artifact-managed API Server and Component Preview Server workflows belong
to unrelated starter infrastructure, not Jobix. Do not repair/start them or
install root Node dependencies as a substitute for launching the native app.

## Constraints

Preserve the native Flutter/Supabase architecture and existing project structure.
Do not recreate existing Supabase or Google Cloud resources, weaken RLS/email
verification, substitute fake AI/credits/export results, or embed privileged
credentials in the client. Follow Architecture V2 and the authority map in
`PROJECT_HANDOFF.md`. Never commit local configuration or credentials.
