# Start here — Google Antigravity handoff

Read every file in `docs/handover/` before changing code. This is a dated snapshot; inspect the current repository, Git state, tests and deployment evidence and correct stale claims before implementation.

## Non-negotiable instructions

- Preserve existing implementation and product requirements. Work in small, reviewable changes; diagnose before fixing.
- The active blocker is PDF download from existing completed exports on Android. Do not overlook it or declare success from a completed job, a server log, a mocked test or a new APK build. Root stage is unknown until the owner supplies safe `JOBIX_PDF_DOWNLOAD` diagnostics.
- Do not create a new export merely to diagnose downloads. Do not debit/refund Credits or modify user records. Use a completed PDF and only a separately authorized controlled environment.
- Local Preview must stay read-only: no server document-preparation action on preview open, no implicit draft save, no export job/Credit mutation. Export must re-fetch authoritative server document and preserve version/hash/renderer checks, idempotency, Credit reservation/settlement and recovery.
- Keep Production, Development, Local Preview and disposable test fixtures distinct. No Production deployment, migration, gate change, IAM/secret change or live-data mutation without explicit owner approval.
- Never print or store credentials, tokens, DB URLs, signed URLs, PDF bytes, resume contents, user identifiers or private logs. Record config names/status only.
- Keep Worker private. Preserve exact verified image digests unless the owner approves another build/deploy.
- Tests using fixture HTTP, in-memory objects, mocked channels or local PostgreSQL are not physical-device/live cloud evidence. Label each accurately.
- Do not mark a feature complete without the specific acceptance evidence in `PROJECT_STATE.md` and `PRODUCTION_READINESS.md`.
- Update this handover when the implementation or evidence changes; preserve historical notes rather than silently rewriting them.
- Report exact changed files, test commands/results, runtime environment, residual risks and the next owner decision.

## First action

Ask for or retrieve the sanitized save diagnostic from one download of an existing completed PDF using the newest Development debug APK. Correlate that one operation with approved read-only logs, then propose a minimal fix and focused regressions. Do not run the download repeatedly or create an export without a reasoned, approved test plan.

## Reproducible local setup notes

The JobiX Flutter project is `mobile/jobix/`; do not use the root Replit artifact workflows as if they were the app. Use the checked-in Flutter/Dart version constraints and locked dependencies. The current Development local config file is `mobile/jobix/config/dev.local.json`; it is environment-specific and must not be copied into Git or this handover. Public example files reveal only key names. Before any cloud-bound operation, verify the intended Supabase/GCP target and use approved least-privilege access.

Useful focused local checks (confirm the current script contract before running): `flutter test --no-pub test/resume_export_test.dart --reporter expanded`; `node --test backend/pdf/test/*.test.mjs`; `bash tool/test_rls.sh --resume-export-only` (disposable local PostgreSQL harness); layout-specific `flutter test --no-pub test/resume_layout_test.dart test/resume_preview_layout_test.dart test/resume_preview_snapshot_test.dart` and `bash tool/test_rls.sh --resume-layout-only` if the mode remains present. Never pass a remote DB URL to the disposable harness.
