# Architecture

## Runtime components

- Mobile: Flutter/Dart, Riverpod providers, GoRouter, Supabase Flutter SDK, Drift local database encrypted by SQLCipher. Android/iOS native bridges handle platform storage and auth links.
- Data/API: Supabase Auth, PostgreSQL with RLS and narrowly granted `SECURITY DEFINER` RPCs, and the `resume-export` Edge Function.
- PDF services: Cloud Run Export Gateway and private Cloud Run PDF Worker. The Gateway validates caller identity and forwards authorized commands using service identity; the Worker claims/recover jobs and calls narrowly scoped database functions.
- Files: private Google Cloud Storage bucket `mhflow-jobix-dev-pdfs` in the historical Development configuration; Worker uploads and verifies object generations. Download uses an expiring signed URL obtained through the existing authenticated `download` action and then Android's system document picker.
- AI: current code exposes an allowance read only; generation is disabled. No provider request path was found in targeted source search.

## High-level data flow

    Flutter / authenticated user
       | Supabase Auth session + user command
       v
    resume-export Edge Function
       | validates active user and Edge gate metadata
       v
    Cloud Run Export Gateway
       | verifies JWT and command/version/idempotency; internal service auth
       v
    private Cloud Run Worker
       | claim -> render -> validate -> fenced private upload -> settle
       +--------> Supabase Postgres RPCs (jobs, snapshots, Credits, cost holds)
       +--------> private GCS PDF object

    Flutter existing-file download
       | authenticated action=download, export_id only
       v
    Edge Function -> Gateway -> Worker/database ownership check
       | bounded signed URL for exact object generation
       v
    Flutter HTTP GET -> PDF/size/header validation -> Android ACTION_CREATE_DOCUMENT

The image/deployment/gate state in this diagram is from repository and owner-reported history, not a live check performed for this handover.

## Application startup and configuration

`mobile/jobix/lib/main.dart`, `mobile/jobix/lib/app.dart`, `mobile/jobix/lib/core/config/app_config.dart`, `mobile/jobix/lib/core/providers.dart`, and `mobile/jobix/lib/features/boot/startup.dart` are key entry points. Startup opens the encrypted local database before restoring the Supabase session; the router waits for startup/session/research state and sends unconfirmed sessions to sign-out/auth flow. Minimum app version comes from an authenticated policy read. Configuration comes from compile-time defines (`APP_ENV`, `APP_VERSION`, `SUPABASE_URL`, `SUPABASE_CLIENT_KEY`); never copy local configuration files or values into documentation. The public app key is not an administrative credential.

Android uses application ID `com.mhflow.jobix` for Development. The `localPreview` flavor appends `.localpreview`, so it has a different package identity. The auth repository uses the standard `com.mhflow.jobix://auth/callback` redirect; verify redirect compatibility before using provider-based sign-in from the Local Preview flavor. `JOBIX_ENABLE_PDF_EXPORT` controls only client presentation; server-side Edge/database/Gateway/Worker checks remain authoritative.

## Auth and authorization boundaries

1. Supabase Auth supplies the user session. Profile and export RPCs use the authenticated user identity, ownership checks, active-account state, and version constraints.
2. The Edge Function verifies the bearer token against Auth and applies the configured export gates before forwarding.
3. The Gateway verifies the user identity and restricts operation schemas. Worker calls are authenticated with Google service identity; the Worker is designed to be private, not publicly invokable.
4. PostgreSQL direct access is not the client model. RLS is enabled on private data; RPC execution is granted by purpose to `authenticated`, `jobix_export_gateway`, or `jobix_export_worker` as needed. Credit reservation/settlement functions are not callable by the mobile client.
5. GCS objects are private. Signed download capability is short-lived and generation-bound; do not log signed URLs.

These are source-level properties and historical deployment descriptions. IAM bindings, effective grants, revisions, and Edge runtime configuration require fresh authorized inspection before release.

## Source-of-truth ownership

- Profile facts, saved Resume presentation, and current source versions: Supabase profile/configuration rows/RPC acknowledgements; local SQLCipher stores drafts and frozen pending requests for recovery.
- Balance and transaction ledger: Postgres `credit_accounts`, `credit_transactions`, `credit_reservations`; client displays authoritative RPC data only.
- Export job and immutable snapshot: Postgres export jobs/snapshots and server-side function results. Worker lease/fence controls retries and finalization.
- PDF bytes: private GCS object with recorded generation, size and hash evidence. A `COMPLETED` job is not proof the Android file picker saved/opened it.
- Local Preview: a locally assembled, read-only snapshot; it does not itself persist profile changes or mutate Credits/export records. Before export, `ResumeExportPanelState.createPdf` re-fetches server `document`, checks renderer compatibility and compares the reviewed document; changes require refreshed review rather than silent export.

## Reliability and observability concerns

- The user-visible `SERVICE_UNAVAILABLE` can hide multiple stages. The latest download case is not correlated to a complete safe diagnostic payload.
- Cloud Billing CSV project totals and Cloud Storage aggregate metrics do not attribute cost/GET requests to one export or distinguish end-user download from Worker activity.
- Cost reservations use configured estimates and the $10 rolling seven-day admission policy. They constrain new admissions, not all provider invoice costs, issued signed downloads, or shared platform spend.
- Migration 022 supports saved layout/order in source. Its deployed status is unknown; mismatch can block layout persistence or renderer-compatible export.
- This repository is a mono workspace with a separate JobiX app; root Replit API and mockup workflows do not run the Flutter app.
