# 09 — Environment and setup

## Native app

Read `mobile/jobix/README.md` and `VERIFICATION.md`. Recorded toolchain:
Flutter 3.32.0 / Dart 3.8.0, JDK, Android SDK/NDK matching locked plugins, and
SQLCipher for host tests. iOS requires an appropriate Apple/Xcode/signing
environment; no iOS acceptance is recorded.

From `mobile/jobix/`:

```sh
flutter pub get
export JOBIX_SQLCIPHER_LIBRARY=/absolute/path/to/libsqlcipher.so
flutter analyze
flutter test
```

Use `tool/verify.sh` only after reviewing its extra database/codegen prerequisites.
The standard Android script checks all environment definitions; development-only
review builds have used explicit ARM64 target and the genuine ignored dev config:

```sh
flutter build apk --debug --split-per-abi --target-platform android-arm64 \
  --dart-define-from-file=config/dev.local.json
```

Do not turn `NOT_CONFIGURED` staging/production markers into runtime config.
Use real release signing only after owner authorization, never debug signing
for a production release.

## Safe configuration

Copy `config/{dev,staging,prod}.example.json` to ignored `.local.json` equivalents.
Only `APP_ENV`, `APP_VERSION`, `SUPABASE_URL`, and a publishable/anon
`SUPABASE_CLIENT_KEY` belong in Flutter config. Never service-role credentials.
Use placeholders when documenting URLs/client configuration outside secure
setup. The environment hosts must remain distinct.

Required development secret names used by existing tools (values intentionally
absent): `JOBIX_DEV_DATABASE_URL`, `JOBIX_DEV_GCP_DEPLOYER_JSON`,
`JOBIX_DEV_SUPABASE_ACCESS_TOKEN`, `JOBIX_DEV_TEST_EMAIL_A/B`,
`JOBIX_DEV_TEST_PASSWORD_A/B`. `SESSION_SECRET` belongs to workspace services,
not Flutter. Enter owner-provided values through secure environment tooling;
never paste them into documentation or source.

## Supabase and Cloud

Reuse the already-approved development Supabase project and inspect its applied
migrations/policy/auth configuration before running any mutation helper.
`apply_*.py` tools are guarded, development-only tools—not a generic deployment
mechanism. Use TLS verification. The included `prod-ca-2021` CRT is a public
Supabase root CA trust certificate, not a private key.

Architecture V2 describes Cloud Run, Artifact Registry, Vertex AI, GCS,
Scheduler, and AdMob. Do not assume a working AI/PDF/reward service because the
resource name or credential exists. The current repository lacks operational
Vertex/PDF worker pipelines. Existing owner-approved development resources and
access details are recorded in `.agents/memory/development-services.md`; read
that file but independently verify current IAM/resources before use. Do not
recreate staging/production resources as part of a clone.

The pnpm API/mockup workflows are separate starter artifacts and use workspace
dependencies. They are not the Flutter runtime.
