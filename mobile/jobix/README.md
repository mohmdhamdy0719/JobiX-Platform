# Jobix Foundation

Native Flutter infrastructure only, separate from the pnpm starter. No product
screens, Career Profile tables, AI/ATS, billing, export or sync are implemented.
Product Design, Architecture V2 and Constitution remain unchanged.

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
The three hosts must differ; builds check this. No project is configured yet.

`APP_VERSION` must equal the built package version. The scaffold version is
1.0.0, not an approved release version. `com.example.jobix` and the generated
OS deployment defaults are scaffolding, NOT approved production identifiers
or product OS requirements. They must be replaced/approved before release.
No release signing configuration is supplied.

## Verify

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
Production font family is replaceable and unresolved. Radius ranges and
typography scales are not chosen. Framework defaults in the placeholder
shell are not approved product styling.

## Startup and authenticated app policies

Config -> encrypted database/settings -> secure Supabase session restore.
Signed-out clients reach the signed-out placeholder without reading
app policies: V2 authorizes policy reads only to authenticated clients.
Authenticated sessions call `read_app_policy('mobile')`. Missing policy,
malformed version, connection failure or storage failure is explicit startup
failure. A minimum version above the built version reaches the update-required
placeholder. Subsequent auth changes re-run the guard.

The policy row is deliberately not seeded: its production version is a server
operational decision. Populate it through privileged administration before
testing authenticated startup against Supabase.

Auth restoration and sign-out are provided, not a login/register flow. Both
Supabase session storage and the PKCE adapter use secure storage, never its
default unencrypted SharedPreferences adapters. Android's secure plugin uses
**encrypted** preferences backed by Keystore; no plaintext session preferences
are used.

## Local security

Drift v1 has only `infrastructure_metadata` and `local_settings`.
SQLCipher verifies `cipher_version` and reads page metadata before proceeding.
A random 256-bit key stays in secure storage. A missing key deletes only the
orphaned local Foundation DB and sidecars before creating a fresh DB.
Wrong or corrupt existing keys fail; they never trigger destructive resets.
This is infrastructure/settings only; server resync is a future slice.

Android disables backup and excludes root/files/databases/shared preferences
from both cloud backup and device transfer. HTTPS only.
iOS marks the Application Support Jobix directory backup-excluded **before**
database creation and uses `first_unlock_this_device` Keychain storage.
Live device Keychain/Keystore and restore tests still require native devices.

## Server

One unapplied migration in `supabase/migrations` creates:
* `users` referencing existing Supabase `auth.users`, owner-only non-deleted
  reads, no client lifecycle writes.
* `app_policies`, no direct client access; authenticated safe RPC projects
  only public version fields, with an empty search path.

No resources were provisioned or live databases modified.
`supabase/tests/local_auth_fixture.sql` is **test-only**, never deploy it to
Supabase. Local PostgreSQL tests emulate auth identity and roles; they are not
a claim of live Supabase/PostgREST verification.

## Native build gates

Android SDK/build tools are absent in this workspace; Android APK verification
cannot pass until supplied. JDK is installed.
iOS build requires macOS, Xcode and CocoaPods. Podfile, project and backup bridge
are present but device integration is unverified.

The native splash uses only DESIGN.md navy, no logo or new artwork. Flutter's
generated icon files are scaffolding assets, not Jobix assets. Production
logo/icon and final screens remain gated on approved Figma/asset access.
This project has no browser preview: don't create a web/Expo replacement.