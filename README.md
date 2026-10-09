# JobiX V2

JobiX is a native Flutter career-profile and resume app for English- and
Arabic-speaking job seekers. It uses one structured Career Profile as the source
for resume previews and exports; it is not a web app or a collection of
independent CV documents.

> **Current state (2026-10-09):** one authenticated development PDF export and
> download was completed and opened on the owner's Samsung M31. This is a
> verified development happy path, not a production launch or proof of capacity.
> The export gates are now closed. Read [PROJECT_STATUS.md](PROJECT_STATUS.md)
> before treating any feature as current or complete.

## Product and architecture

- Native Flutter/Dart client with English/Arabic localization and RTL support.
- Supabase Auth, PostgreSQL, RLS, and versioned server-side operations.
- A six-step Career Profile builder, editable/reviewable career evidence,
  Volunteer Experience stored separately from paid Work Experience, and a
  configurable Resume preview.
- Server-authoritative Credits and PDF exports using a frozen canonical resume
  snapshot, a private PDF worker, private GCS objects, authenticated downloads,
  idempotent jobs, and reservation/recovery safeguards.
- AI generation, payments/subscriptions, and public production launch are not
  represented as working features. See the current status and roadmap below.

Architecture V2 is the source of truth for intended system boundaries:
[Architecture V2](attached_assets/JobiX_Architecture_V2_1790975874316.md).
The product contract and implementation are separate authorities: read
[product design](attached_assets/JobiX_Product_Design_1790975900645.md) and the
[approved PDF retention/deletion ADR](mobile/jobix/backend/pdf/ADR-retention-deletion.md)
alongside the current code and status. Do not infer deployment state from source
code or treat recommendations as approved policy.

### Export and Credit contract

- A newly completed PDF export costs **2 Credits**; an authenticated valid
  download costs zero.
- Export Again creates a new export from current profile data and costs 2
  Credits. An expired/missing PDF download fails; it never silently regenerates
  or charges again.
- Generated PDFs have a **7-day logical retention**. PDF expiry alone does not
  require snapshot/HTML deletion. Profile/account deletion freezes new export
  work, invalidates leases, releases pending reservations, removes related
  objects/snapshots/export data, blocks stale usable writes, and is not complete
  until absence is verified.
- Do not change Credit, idempotency, account-deletion, or retention behavior
  without explicit approval. AI is outside the PDF milestone.

## Repository map

| Path | Purpose |
|---|---|
| `mobile/jobix/` | Native Flutter application, tests, migrations, and PDF backend |
| `mobile/jobix/backend/pdf/` | Export worker, immutable snapshot/rendering and lifecycle |
| `mobile/jobix/backend/export-gateway/` | Authenticated development ingress bridge |
| `mobile/jobix/supabase/` | Supabase migrations, functions and local fixtures |
| `docs/handoff/` | Architecture references, product decisions and historical implementation notes |
| `deliverables/` | Explicitly retained APK/archive and readiness-report deliverables |
| `attached_assets/` | Product/design references and historical user-provided project briefs |
| `artifacts/`, `lib/`, `scripts/` | Replit pnpm starter infrastructure; not the JobiX mobile application |

The API-server and mockup-sandbox workflows are unrelated supporting artifacts.
Do not start or repair them as a substitute for the native app.

## Development prerequisites and safe configuration

For the native client use Flutter **3.32.0** / Dart **3.8.0**, the committed
`mobile/jobix/pubspec.lock`, Java 17, and the Android SDK/NDK required by the
Android build. The SDK/NDK and Gradle cache in this workspace are under ignored
`.local/` paths; a Git clone does not include them. The local development APK is
debug-signed, not a release artifact.

The development client configuration belongs in the ignored
`mobile/jobix/config/dev.local.json`. It may contain only the development
Supabase URL, public/publishable client key, environment and app version. Never
put passwords, database credentials, service-role keys, Google private keys, or
service-account JSON in Flutter configuration or Git. Staging and production
client configurations are not supplied.

Restore the Flutter packages without changing the lockfile:

```sh
cd mobile/jobix
flutter pub get --enforce-lockfile
```

Then, with the approved SQLCipher library path set in the shell:

```sh
export JOBIX_SQLCIPHER_LIBRARY=/absolute/path/to/libsqlcipher.so
bash tool/verify.sh
```

The wrapper runs localization/code generation, foundation checks, analysis,
Flutter tests and the disposable local PostgreSQL/RLS harness. The SQLCipher
variable is required; the script must not substitute ordinary SQLite.

The narrower recorded PDF checks (from the repository root) are:

```sh
node --test mobile/jobix/backend/pdf/test/*.test.mjs
```

```sh
cd mobile/jobix
bash tool/test_rls.sh
```

Do not mistake these local/disposable checks for deployed Cloud Run, live GCS,
real-account deletion, or production evidence. The recorded full PDF suite is
101/101; the complete `test_rls.sh` result still needs reconciliation against an
older documented 7-pass/1-fail run. See
[Phase 3 acceptance evidence](mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md).

### Development ARM64 debug APK

The previously successful build command, from `mobile/jobix` with the existing
development-only config and local Android/Gradle tooling, is:

```sh
flutter build apk --debug --no-pub --target-platform android-arm64 --split-per-abi \
  --dart-define-from-file=config/dev.local.json \
  --dart-define=JOBIX_ENABLE_PDF_EXPORT=true
```

The recorded M31 APK output is
`mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`. Do not
rebuild it merely to reproduce the previous phone result. The last define
enables the client UI only; it must not reopen backend export/billing gates.
The convenience
`tool/build_android.sh` checks all three environment configs; a fresh workspace
without staging/production configs should use only the documented development
command after verifying its dev configuration. No release build/signing recipe
is approved.

The backend PDF `package.json` specifies Node `>=20.20.0`, but this workspace's
Node 20.20.0 line is end-of-life. The backend is outside the root pnpm workspace
and has its own tracked `pnpm-lock.yaml`. Its Dockerfile pins pnpm **10.26.1**
and uses this isolated frozen install:

```sh
cd mobile/jobix/backend/pdf
pnpm install --ignore-workspace --frozen-lockfile --prod
```

The root `pnpm-lock.yaml` is for the Replit starter, not this backend. Browser/
PDF tools are separate prerequisites: inspect the existing PDF README and
Dockerfile rather than assuming Debian's browser installation recipe works in
Replit's NixOS shell. Do not upgrade dependencies or regenerate either lockfile
as a handoff step.

## Source-of-truth and handoff documents

1. [PROJECT_STATUS.md](PROJECT_STATUS.md) — verified, partial, blocked and
   unknown status.
2. [docs/AI_HANDOFF.md](docs/AI_HANDOFF.md) — instructions for the next coding
   session and preservation rules.
3. [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) — proposed, unimplemented roadmap.
4. [Production-readiness assessment](deliverables/jobix-production-readiness-2026-10-09.md)
   — detailed evidence, security/cost risks and review proposals; not deployment
   authorization.
5. [Phase 3 acceptance record](mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md),
   [native verification history](mobile/jobix/VERIFICATION.md), and
   [docs/handoff/](docs/handoff/README.md).

Resolve conflicts in this order: approved owner decisions/ADRs define product
contracts; Architecture V2 defines intended architecture; current source,
migrations, tests and read-only deployment evidence establish what is
implemented/deployed; dated handoff notes are historical and must not override
newer evidence. Ask before interpreting a proposed policy as approved.

## Current limits

- Development only. The Edge Function, public authenticated Gateway and private
  Worker are deployed in the development environment; all new-export gates are
  false. Do not open them or run a chargeable export without a separately
  approved, bounded test.
- The successful M31 export/download is preserved; do not repeat or refabricate
  it. Local fault, retry, expiry and deletion tests do not prove those failures
  in live cloud services.
- No production/staging changes, production signing, production backup/restore,
  sustained capacity or hostile-traffic economics have been established.
- AI provider requests/history, subscription payments and public production
  launch are not implemented/accepted.

Review proposed work with the owner before implementation. Do not change
authentication, RLS, Credit accounting, deletion/retention, IAM, secrets or
cloud resources as an assumed next step.
