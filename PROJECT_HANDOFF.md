# Jobix Project Handoff

## Current status

The primary product client is the native Flutter app in `mobile/jobix/`; Supabase
provides Auth, Postgres, RLS and versioned mutation RPCs. The current source
includes an English/Arabic six-step Career Profile flow, encrypted drafts,
optional private profile extras, and a Career-Profile-backed HTML Resume preview.
The app keeps AI generation disabled when the provider path is unavailable. It
does not yet generate, accept, or reconcile AI proposals, and it does not export
PDFs. No billing is implemented.

## Current milestone

Builder polish, first-launch/registration-context lifecycle, server allowance
display, worker-only Credits reservation functions, and Resume configuration /
preview foundation. The most recent native development APK is recorded under
`deliverables/`; it is not a release build or device-acceptance result.

## Next milestone

Implement the server-side AI operation, provider, history, failure reconciliation,
and version-checked proposal acceptance paths before enabling generation. Complete
the Chromium PDF worker and private file lifecycle. Verify the native app on an
authorized Android device.

## Architecture and product sources

- Current architecture: `attached_assets/JobiX_Architecture_V2_1790975874316.md`
- Historical architecture: `attached_assets/JobiX_Architecture_V1_1790975886719.md`
- Constitution: `attached_assets/Jobix_Constitution_1790975874315.md`
- Product behavior: `attached_assets/JobiX_Product_Design_1790975900645.md`
- Visual foundation: `attached_assets/DESIGN_1790975900644.md`
- Detailed status and paths: `docs/handoff/README.md`

Do not replace the native Flutter/Supabase architecture, weaken RLS, introduce a
second editable Resume data model, or put privileged credentials in the app.

## Current repository and Git status (handoff audit)

- Local branch: `main`; 41 commits reachable on this branch before the handoff
  documentation commit.
- The GitHub URL named in the request resolves through the authorized GitHub
  connection to a **private** repository whose default branch is `master`. At the
  time of audit it had only the initial commit `d82acf24eaeddc1b1fcc31333e60a9f8cd479af8`
  (2026-08-20), containing five IDE metadata files. It does not contain the
  current Jobix source.
- No GitHub remote exists in this workspace. Existing Git remotes are Replit
  backup/workspace remotes. The old `master` and local `main` histories are
  unrelated.
- The GitHub OAuth connection is attached for API access, but that is not a
  Git smart-HTTP/SSH remote and cannot safely push the local commit graph.
  Neither history has been overwritten. No GitHub push was made.
- Exact Replit task/checkpoint records are not included in the clone. The
  handoff records only history recovered from Git, persisted plans/notes and
  project documents.

See `docs/handoff/10_MIGRATION_GUIDE.md` for the required non-force reconciliation
before publishing the full repository.

## Setup and verification

Start with `mobile/jobix/README.md` and `mobile/jobix/VERIFICATION.md`. Work from
the `mobile/jobix` directory, use the pinned Flutter/Dart toolchain and only safe
public client configuration. Do not recreate existing Supabase/Google Cloud
resources or apply database migrations to staging/production as part of setup.
Never share secret values in chat or commit them.

## Remaining work

See `docs/handoff/06_CURRENT_ROADMAP.md`, `07_REMAINING_WORK.md`, and
`11_KNOWN_ISSUES.md`. Physical Android and iOS verification is outstanding.
Migration readiness is **PARTIAL** until the current Git history is safely pushed
to the private GitHub repository, access to its current initial commit is
reconciled, and destination-account configuration is completed.

## Complete handoff

Read [docs/handoff/README.md](docs/handoff/README.md) first. It links the
overview, architecture, decisions, implementation/task history, roadmap,
remaining work, test evidence, safe setup, migration steps, known issues, and
file map.
