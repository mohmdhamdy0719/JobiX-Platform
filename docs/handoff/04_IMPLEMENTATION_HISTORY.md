# 04 — Recoverable implementation history

This is a repository/workspace reconstruction, not an export of Replit chat,
checkpoints, or complete task records. Git dates come from the preserved local
commit graph; milestone details come from tracked Markdown and persisted task
notes. Do not infer a date for a UI change solely from the file modification
time.

## 2026-09-11 — Repository foundation

The tracked tree begins with a Replit workspace/pnpm starter; the Jobix native
app was subsequently added under `mobile/jobix/`. The starter API-server and
mockup-sandbox remain workspace artifacts.

## 2026-10-02 to 2026-10-03 — Architecture, Foundation and first vertical slice

Git history records project requirements/documentation, architecture, and
first-slice implementation work. `FIRST_SLICE.md` documents the approved
Onboarding → four Research Questions → Supabase Auth → one empty Profile #1 →
Personal Information path. Supabase migration groups add registration,
first-profile creation, policy/read contracts, idempotency and Credits account/
ledger foundation. Product Design and Constitution are tracked in
`attached_assets/`.

Tests/live notes in `VERIFICATION.md` distinguish real development-Supabase
checks from host mocks. These do not prove Android/Keystore/confirmation-inbox
acceptance.

## 2026-10-04 — Development and model/architecture decisions

Preserved project documents and Git subjects record development service setup,
data/completeness decisions, and the approved model default. The live model
provider was **not** implemented. The decision and implementation are separately
stated in `mobile/jobix/README.md`.

## 2026-10-05 — Authentication and Career Profile builder

Git history and persisted task text record authentication fixes, personal profile
data, all builder entity sections, versioned/idempotent mutation, Review/Edit,
Career screens and local drafts. `.local/tasks/career-profile-builder-review.md`
is the plan; its ignored companion `.notes.md` identifies **Task #9** and records
development-side migration/test outcomes. Planned criteria are not proof of
implementation; consult `VERIFICATION.md` and live-test scripts for the evidence.

## 2026-10-07 — Builder polish and Resume foundations

The owner’s brief requested builder fixes, lifecycle separation, private
photo/custom links, allowance UI, Credits reservation, and Resume HTML preview.
Migrations 008–010, renderer/configuration/WebView, quota UI, and extras work
appear in the tracked source and their test assets. The prior build produced a
signature-verified ARM64 debug APK ZIP. Reported full Flutter suite: 177 tests;
later lifecycle-specific tests: 33. AI provider/history/apply and PDF worker were
explicitly not implemented.

## Not recoverable here

Replit checkpoints, archived tasks, exact conversation chronology, task agents'
internal runs, and project dashboards do not exist in the repository history.
The `.local` plans/notes are ignored workspace files and are not present in a
GitHub clone unless explicitly copied. Exact dates/task numbers for other work
are therefore not asserted.
