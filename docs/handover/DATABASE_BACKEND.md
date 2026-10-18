# Database and backend status

## Authority and freshness

Checked-in source under `mobile/jobix/supabase/` is authoritative for intended schema, not proof of a live database. The owner previously confirmed migration 021 applied to Development and later reported Development PDF Export enabled with estimates. This documentation pass did not connect to Supabase; current migration ledger, database values, Edge configuration and gates are therefore **UNVERIFIED live**. No Production database state is known.

Migration 022 is in the repo as `202610170022_resume_layout.sql`; its header says “Local implementation only. Separate approval required before live application.” No evidence in this pass establishes whether Development has it.

## Migration sequence / purpose

The checked-in sequence is 001–022 (filenames in `mobile/jobix/supabase/migrations/`):

- 001–005: user/app policy, onboarding/profile shell, signup Credits and bootstrap envelope.
- 006–011: profile text, structured sections, extras/custom links, Resume configuration/concurrency and volunteer data.
- 012: export settings/jobs/snapshots and server-side source/validation/create/status/history RPC base.
- 013: export lifecycle and Credit finalization.
- 014–016: configuration concurrency, renderer/local hardening, retention/cleanup hooks.
- 017: deletion safety and upload-flight tracking.
- 018: atomic admission and export policy guards.
- 019: estimated-cost budget/reservation/settlement and reconciliation.
- 020: purge/recovery discoverability of held cost reservations.
- 021: corrected seven-day output-storage cost unit in the estimator.
- 022: versioned profile-owned Resume section order/visibility save RPC, `save_resume_layout`.

Before any migration action, verify target project, exact source checksums, ordered ledger, preflight invariants, and current documented runner safeguards. Use only the fixed guarded Development runner under separate owner approval; never use elevated `postgres` as a convenience or apply SQL manually. Current run state is unknown.

## Main data groups

- Identity/policy: `users`, `app_policies`, `onboarding_context`.
- Profile: `profile_slots`, `career_profiles`, `profile_personal_data`, `profile_summaries`, structured `profile_*` section tables, `profile_extras`, `resume_configurations`, and idempotency records.
- Credits: `credit_accounts` (finalized/reserved balances), `credit_transactions` (ledger), `credit_reservations` (per-operation holds/fences).
- Export: `export_settings`, immutable `export_snapshots`, `export_jobs`, `export_upload_flights`, cost policy/reservations/provider observation records. Exact schema is in migrations; do not substitute this inventory for current catalog inspection.

## RLS/RPC model

Migrations enable RLS and revoke broad direct access for sensitive tables. Authenticated users get owner-scoped reads. Writes are routed through owner-checked versioned RPCs with `auth.uid()`, active-account and idempotency/version checks. Export tables are not directly client-readable/writable; narrowly granted gateway/worker functions mediate operations. Treat grants and deployed function definitions as unverified until read-only live inspection.

## Credits and export lifecycle

- New account grant: migration 004 trigger gives 5 signup Credits; historical accounts are initialized at zero, not retroactively granted Credits.
- Credit balance/history are read from `app_bootstrap` and `credit_transactions_page`. History paging is bounded (up to 100) and owner-scoped.
- Migration 010 defines a 2-Credit `RESUME_EXPORT` reservation. Worker service role only can reserve/finalize; only successful, fenced completion inserts one -2 ledger transaction and consumes the hold. Known failure releases; expiry/recovery rules are server-side. Unique idempotency constraints and function transactions prevent duplicate charges.
- New PDF exports are intended to cost 2 Credits after successful completion. Valid existing re-downloads are free for seven days; download action is not create. Product intent is normal ongoing usage, not a single-trial lock.
- Cost estimates configured for Development in the owner-reported activation are planning assumptions, not measured provider charges or a hard $10 invoice cap. Source estimate file: `mobile/jobix/backend/pdf/ESTIMATED_DEVELOPMENT_COSTS.md`.

## Edge, Gateway, Worker and Storage

- `mobile/jobix/supabase/functions/resume-export/`: user-facing authenticated Edge entry point; validates user/session, gate metadata and command before forwarding.
- `mobile/jobix/backend/export-gateway/`: validates caller token/claims and request contract; performs authorized operations using internal Cloud Run authentication.
- `mobile/jobix/backend/pdf/server.mjs`, `worker.mjs`, `google.mjs`: private Worker server, claim/retry/recovery, renderer, cost/accounting adapter, GCS operations, signed download URL.
- GCS bucket identified in Development history as `mhflow-jobix-dev-pdfs`, private and generation-scoped; effective current IAM, lifecycle, soft-delete and service config need live recheck.
- Cloud Run revisions last reported by owner: Gateway `jobix-dev-export-gateway-00017-gqs`, Worker `jobix-dev-pdf-export-00017-8bh`; Worker corrected image was reported deployed. This is historical owner-reported deployment evidence only, not a current live check.

## Development vs Production

Development project reference in prior build/deployment evidence: `lmouxhbjhtqdtiqijcee`; GCP project `mhflow-jobix`, region `me-central1`. User last reported PDF Export enabled in Development after approving estimates. Do not assume any current flags, cost inputs, or revision status from that statement; read-only verify before acting. Production was not authorized or changed in this work, and no Production readiness evidence is established.

Prelaunch database checks: migration checksums through 022; function signatures and grants; export gates and accounting readiness; cost input values/model version; zero unaccounted jobs/holds/flights before policy changes; RLS/owner isolation; deletion/quiescence/recovery invariants; layout RPC availability; and Credit ledger/reservation consistency. Never share row-level user data in a handover.
