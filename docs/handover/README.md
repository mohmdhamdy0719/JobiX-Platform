# JobiX handover — 18 October 2026

This is the current source-based handover for the Flutter JobiX MVP. It is a point-in-time snapshot of checked-in code, local artifacts, repository documentation, and owner-reported Development events. It is not a live cloud/database inspection.

> **Production is not established as ready. Do not release or open Production export gates.** The most important active issue is that the owner still reports PDF downloads failing on Android. The specific failing stage is not yet known because the safe in-app diagnostic payload has not been returned.

## Status at a glance

- Flutter app and Supabase/Google Cloud PDF pipeline are implemented. Some features have strong local/disposable test evidence and one earlier owner-confirmed physical-device export/download/open.
- A later Android session reported that downloads of completed PDFs fail; two supplied jobs were `COMPLETED` (154,591 bytes each, no job error). Gateway/Worker requests were seen in supplied logs; no corresponding Storage GET evidence was found. These facts do not locate the Android save failure.
- Owner last reported Development PDF Export enabled using initial cost estimates. This handover did not query Development; current gates, database values, deployed revisions, and applied migration state must be rechecked before any operational action.
- Migration 022 (`save_resume_layout`) exists in source and explicitly says local implementation only / separate live application approval. Its Development application is unverified.
- Current source contains a Development ARM64 debug APK at `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-development-debug.apk`; hash and metadata are recorded in `EXPORT_DOWNLOAD_INCIDENT.md`. No build was performed for this handover.
- AI allowance reporting exists, but generation is disabled and no provider invocation was found in the current app/backend search. Ads, purchases, and subscription integrations were not found.

## Read in this order

1. `PROJECT_STATE.md` — feature status and evidence.
2. `ARCHITECTURE.md` — components and trust boundaries.
3. `EXPORT_DOWNLOAD_INCIDENT.md` — current PDF incident and next safe diagnostic.
4. `DATABASE_BACKEND.md` — migration/schema and server-side accounting.
5. `SECURITY_AUDIT.md` — source-level controls and unchecked areas.
6. `UI_UX_AUDIT.md` — every registered route and review checklist.
7. `AI_FEATURES.md`, `MONETIZATION_ADS.md` — current feature boundaries.
8. `KNOWN_ISSUES.md`, `PRODUCTION_READINESS.md`, `NEXT_STEPS.md` — release blockers and sequence.
9. `ANTIGRAVITY_START_HERE.md` — handoff instructions for another coding agent.

## Safest first steps

1. Preserve the current Git state; inspect `git status --short --branch` before editing. This checkout was `main`, 66 commits ahead of `origin/main`; the only untracked items at inspection were user-supplied handover attachments. Do not push or rewrite history.
2. Read the unresolved download incident and collect the copyable safe diagnostic from the latest Development debug APK on the owner's device, using an existing completed PDF only. Do not create another export to get diagnostics.
3. Verify Development deployment/gates and migration 022 read-only through owner-approved access before relying on any new RPC or service behavior. This workspace pass did not access live services.
4. Keep all Production changes, live migrations, Credits adjustments, and gate changes behind separate explicit owner approval.

## Evidence labels

`VERIFIED` refers only to a named test/environment and the evidence recorded here. `IMPLEMENTED_UNVERIFIED`, `PARTIAL`, `BROKEN`, `NOT_IMPLEMENTED`, and `UNKNOWN` are used in `PROJECT_STATE.md`. “Owner-reported” is not an independent live query; “source-reviewed” is not runtime proof. Old handover files under `docs/handoff/` and dated root status files are historical, not the current truth when they conflict with source or later evidence.

## Project boundaries

The JobiX application lives in `mobile/jobix/`. The workspace root also contains a Replit pnpm template and workflows for `artifacts/api-server` and `artifacts/mockup-sandbox`; those are not the JobiX mobile product. Historical handover material is retained at `docs/handoff/`; it was prepared on 9 October 2026 and should be used for history, not current runtime status.
