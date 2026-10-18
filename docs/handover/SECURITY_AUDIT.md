# Security review — source-based, not a penetration test

Scope: reviewed current checked-in Flutter, migration and PDF service paths plus historical test records. No remote access, exploit testing, security scanner, credential inspection, or Production assessment was performed for this handover. No vulnerability is asserted as confirmed without evidence.

| Severity | Status | Finding / evidence | Impact and next verification |
|---|---|---|---|
| High | Confirmed operational defect, not a proven security vulnerability | Owner reports existing PDF downloads fail on Android; exact client-save/Storage stage is unknown. `resume_export_service.dart`, Android `MainActivity.kt`. | Users may be unable to retrieve completed documents. Capture safe diagnostic and inspect correlated logs; do not log URL/token/document. |
| High | Not yet tested | Current live RLS, deployed RPC grants, Edge secrets/gates, Cloud Run Invoker/IAM, bucket IAM, and migration 022 state were not re-read in this pass. | Must verify with approved read-only access before production approval. |
| Medium | Confirmed design limitation | $10 rolling-seven-day admission depends on estimated inputs and a shared reserve; `mobile/jobix/backend/pdf/ESTIMATED_DEVELOPMENT_COSTS.md` explicitly excludes a guarantee of total provider invoice. | Shared usage, downloads, already-issued URLs and billing delay can exceed estimate. Reconcile actual billing/usage; no zero-cost assumptions. |
| Medium | Not yet tested | Native Android SAF save, cloud Storage GET, signed URL expiry, device/provider variability, and process interruption are not established by mocked channel tests. | Device matrix and failure tests required; current incident makes this a release blocker. |
| Medium | Not yet tested | Full account-to-account isolation across all tables, every RPC, Edge/Gateway/Worker and object paths has not been independently penetration-tested. | Run controlled two-account disposable/dev negative cases under explicit owner approval; never probe Production. |
| Low | Source-reviewed control | App passes a public Supabase client key only; service credentials are server-side configuration. `app_config.dart`, Edge/Gateway/Worker source. | Do not treat a publishable key as a secret. Verify local configuration is not committed; never put service-role or DB URLs in APK/docs. |
| Low | Source-reviewed control | Download uses a scoped HTTPS Storage URL, disables redirects and validates status, size and `%PDF-`; Android save diagnostics contain stage/size metadata only. | Recheck tests and device behavior. Never add URL/query/token/PDF/profile logging. |
| Informational | Source-reviewed control | Credit reads are authoritative RPC results; reservation/finalization functions are not mobile-invokable. Migration 010 and export migrations. | Preserve server enforcement in all retries and UI changes. |
| Informational | Source-reviewed control | Profile and export snapshots use owner/session checks, versions, idempotency and server-side validation; export object access is private by design. | Verify actual deployed IAM/policies; source alone does not prove cloud state. |

## Source-reviewed protections

- Supabase RPCs use `auth.uid()`/active user checks, profile ownership and version or idempotency constraints; RLS is enabled for private tables in migrations.
- Credit reservation is 2 units, tied to an export operation/fence; final debit and job completion are server-side transactional. Ambiguous work is retained for reconciliation rather than optimistic refund.
- Edge Function/Gateway/Worker divide public user auth from private service auth. Worker is intended to require authentication and remain private. Current Invoker policy was historically verified during deployment, not checked now.
- GCS object is intended private; download grants a time-limited, generation-bound URL only after ownership/state checks.
- Export source has bounded inputs/rendering and validation; do not infer resistance to every malformed input or denial-of-service case without test/review.
- Diagnostic logging is Debug-only and intentionally excludes signed URLs, query parameters, token values, profile data and PDF contents. Still review any new logging diff before shipping.

## Required security work before Production

1. Read-only snapshot of Production schema/checksums, function grants, RLS, gates, service revisions/identities, Invoker IAM, bucket public-access/lifecycle and secret *names/status only*.
2. Controlled two-user IDOR and account-switch tests for profiles, exports, status/history/download and deletion.
3. Concurrency/idempotency/recovery tests against a disposable DB and approved staging; prove one debit on success and none on failure/replay.
4. Review Android session storage, backup behavior, link callbacks, release signing, clipboard diagnostics and data disclosures on physical devices.
5. Expert security review / threat-model update, dependency/SAST scan, privacy and retention review; none is claimed complete here.
6. Verify the safe diagnostic includes no sensitive values and that Production builds do not expose or persist debug-only data.

This document is a focused source review, not a certification, audit attestation, or claim that JobiX is secure or Production-ready.
