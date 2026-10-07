# Jobix

Jobix is a native Flutter career-profile and resume app backed by Supabase.
Start with `PROJECT_HANDOFF.md`; the root pnpm workspace is supporting Replit
infrastructure, not another Jobix client.

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
flutter pub get
flutter gen-l10n
flutter pub run build_runner build

export JOBIX_SQLCIPHER_LIBRARY="$(dirname "$(dirname "$(readlink -f "$(command -v sqlcipher)")")")/lib/libsqlcipher.so"
test -f "$JOBIX_SQLCIPHER_LIBRARY"
dart tool/check_foundation.dart
flutter analyze
flutter test --reporter expanded
bash tool/test_rls.sh
```

Use real SQLCipher, not plain SQLite. The permission-test script creates and
cleans up a disposable local PostgreSQL instance; it does not contact Supabase.
Live checks under `tool/live_*` require separate authorization and configuration.

Import verification on 2026-10-07: dependencies and generated code restored,
analysis clean, all 178 Flutter tests passed, client safety checks passed and
disposable PostgreSQL permission tests passed. No application code was changed.

## Native launch requirements

The current app has Android/iOS targets, not a browser or Linux desktop target.
The imported Android SDK path is missing and no Android device is connected.
Only local automated checks were requested for this setup; no Android tooling
was installed, APK built, or app run on a device. Supporting web-service
workflows are not a running Jobix mobile app.

To run Android later, restore a compatible Android SDK/NDK, obtain SDK-license
acceptance, and connect an authorized Android device. Follow the native README
to create the ignored `config/dev.local.json` using the existing development
public URL and publishable client key. Then, from `mobile/jobix/`:

```sh
flutter run -d <android-device-id> \
  --dart-define-from-file=config/dev.local.json
```

Do not fabricate staging/production configuration or release signing. The
standard Android build script deliberately requires all three environments to
be configured; follow the documented development-only build path where approved.

## Constraints

Preserve the native Flutter/Supabase architecture and existing project structure.
Do not recreate existing Supabase or Google Cloud resources, weaken RLS/email
verification, substitute fake AI/credits/export results, or embed privileged
credentials in the client. Follow Architecture V2 and the authority map in
`PROJECT_HANDOFF.md`. Never commit local configuration or credentials.
