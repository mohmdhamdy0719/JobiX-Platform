# JobiX V2 — AI coding handoff

**Snapshot:** 2026-10-09  
**Product:** native Flutter/Supabase JobiX V2.  
**Current posture:** development happy path verified on the owner's Samsung
M31; public production is **NO-GO**. The owner requested repository
documentation/hygiene only in the source account. Do not treat this document or
the older approvals in chat as authorization for new work in another account.

## First actions in a fresh Replit account

1. Read `README.md`, `PROJECT_STATUS.md`, this file, and
   `docs/NEXT_STEPS.md`; then read `docs/handoff/README.md`.
2. Inspect `git status`, current branch/HEAD, remotes, commit graph and Git LFS
   pointers. Do not push, force-push, reset, rebase, rewrite history, or alter
   remotes as an assumed setup step.
3. Distinguish local source from deployment. Use the 2026-10-09 readiness
   report for its dated development inventory, not as fresh cloud verification.
4. Do not repeat the personal paid export, reopen gates, start the production
   worker, apply migrations, run cloud mutations or build a replacement APK
   without a new, explicit scoped approval.
5. If a requested task requires cloud access or live Credits, state the exact
   target and mutation/test budget and get approval before acting. The old
   source-account approvals do not silently transfer to another Replit account.

## Product context

JobiX is a native English/Arabic resume and career-profile app. The structured
Career Profile is the source for the rendered Resume. The intended user path is:

`Flutter app → Supabase Auth/session → Supabase Edge Function → authenticated
Google Cloud Run Gateway → private PDF Worker → restricted development database
and private GCS bucket`.

Supabase Auth remains the user-facing identity boundary. The Edge Function and
Gateway verify user access; backend services derive the actor from verified
claims, enforce active-account and ownership checks, and never accept a
client-supplied actor as authority. The public Gateway cannot invoke worker-only
recovery/cleanup paths. The PDF Worker stays private and only its designated
service identities invoke it. Never use Google service-account private keys or
put privileged database/provider credentials in Flutter or Supabase secrets.

### Non-negotiable product/security rules

- Preserve Architecture V2, native Flutter, Supabase Auth, RLS, service
  identities and the restricted runtime database role.
- Preserve the existing account/profile lifecycle and deletion contract outside
  PDF/export integration. A `DELETING` account cannot create new work.
- The authoritative Export Again action uses current profile data and creates a
  new export for 2 Credits. A valid download is free. Expired/missing PDF means
  expired/missing—never automatic regeneration or another charge.
- Logical PDF retention is exactly seven days. PDF expiry alone does not require
  immediate snapshot/HTML deletion; do not invent another retention period.
- Account/profile deletion freezes export mutations, invalidates leases, releases
  pending reservations, stops late/stale workers from preserving usable
  objects, removes related objects/snapshots/export data and verifies none remain
  before completion.
- Keep snapshot immutability, server-derived ownership, atomic
  create/idempotency, reservation/finalization/release, retries, fencing and
  duplicate callback protection. Never “fix” a failing test by weakening them.
- Volunteer is first-class unpaid career evidence, separate from paid Work
  Experience; its Phase 2 approval explicitly excluded completeness percentage
  and algorithm changes.
- AI, subscriptions and public production rollout are separate, unimplemented
  scopes.

## Current verified result and deployed development facts

- The owner confirmed the current ARM64 debug APK was installed on a Samsung
  M31, signed in, displayed their existing resume, downloaded the first
  completed PDF and opened it. The backend recorded exactly one 2-Credit debit
  and consumed reservation; an explicit later Export Again request expired and
  released its reservation without another debit. Preserve this result. Do not
  recreate the PDF or repeat the charge.
- Local recorded tests after the upload-rejection fix: adapter 11/11; guarded
  disposable acceptance 8/8; full Node backend suite 101/101; Flutter
  default-off 4/4; 18 enabled fixture cases, with focused 2/2 for two corrected
  UI expectations. See `mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md`.
- The same acceptance file retains an earlier 7-pass/1-fail full RLS harness
  result; later 8/8 focused acceptance does not establish a current green
  complete `test_rls.sh`. Keep that as a local evidence gap until reconciled.
- Current state in the readiness snapshot: Supabase Edge `v7`, Gateway
  `jobix-dev-export-gateway-00010-4rp`, Worker
  `jobix-dev-pdf-export-00011-tnk`, project `mhflow-jobix`, region
  `me-central1`. Gateway is the only public invocation bridge; worker is
  private. Export gates are false; deletion-policy approval remains true.
- The readiness report identifies drift between recently changed local source
  and deployed Gateway/Worker images. Live injected failure, expiry,
  stale-worker and account-deletion acceptance is incomplete. Do not claim
  end-to-end Phase 3 or production readiness from local fixtures.
- Production readiness assessment: 49/100, public launch NO-GO. Treat cost
  tables as estimates, not invoices or verified regional quotes.

All service revisions, identities, and flag values above are dated facts. They
are safe operational identifiers, not credentials, and must be freshly
verified only when a separately approved task requires them.

## Authority and evidence

Resolve conflicts using:

1. Explicit owner-approved product decisions and current ADRs, especially
   `mobile/jobix/backend/pdf/ADR-retention-deletion.md`.
2. Architecture V2 as the intended system boundary; V1 is historical.
3. Current source/migrations/tests for implemented behavior.
4. Dated read-only deployment inventory for deployed behavior, only as of its
   capture time.
5. `PROJECT_STATUS.md` for this snapshot, `docs/NEXT_STEPS.md` for proposed
   work, and the production-readiness report for its scoped findings.
6. `docs/handoff/` histories and older README/status snapshots are references,
   not evidence that later work did or did not happen.

Replit tasks, checkpoints and local toolchains under `.local/` do not reliably
transfer through Git. The full conversation and secret-store contents are not
part of this handoff. Never infer approval from a stale task, prior account, or
the presence of an environment variable.

## Safe local setup and verified commands

Flutter/Dart constraints are Flutter 3.32.0 and Dart 3.8.0. From
`mobile/jobix/`, restore only the committed lock:

```sh
flutter pub get --enforce-lockfile
```

`JOBIX_SQLCIPHER_LIBRARY` is required for `bash tool/verify.sh`. Native Android
SDK/NDK and Gradle caches were in ignored `.local/` storage and must be checked
in a clone; iOS requires macOS/Xcode. The dev config file is ignored and must
contain only the public Supabase project URL, publishable client key,
environment, and app version. Obtain credentials via the workspace's secure
Secrets flow, never chat or Git.

The recorded native regression command is:

```sh
cd mobile/jobix
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
bash tool/test_rls.sh
```

The recorded PDF Node test command from the repository root is:

```sh
node --test mobile/jobix/backend/pdf/test/*.test.mjs
```

The PDF Node package has no standalone lockfile and is not in the pnpm
workspace. Root `pnpm install --frozen-lockfile` does not establish a frozen
install for it. Its package requires Node `>=20.20.0`, but the workspace's Node
20.20 line is end-of-life. Do not create lockfiles, upgrade dependencies, or
invent clean-install commands during documentation-only handoff work.

The verified Android development build command is recorded in
`mobile/jobix/VERIFICATION.md`:

```sh
cd mobile/jobix
flutter build apk --debug --target-platform android-arm64 --split-per-abi \
  --dart-define-from-file=config/dev.local.json
```

No release signing or production build is established. Do not rebuild the
working M31 APK unless an approved fix requires it.

## Current work limits

- This handoff task changes documentation and narrow ignore rules only.
- Do not modify Flutter product code, Auth, Supabase, RLS, database schemas,
  Credit logic, deletion/retention contracts, runtime/dependencies, IAM,
  secrets, Cloud Run, GCS, Scheduler, production/staging, or export flags.
- Do not start supporting API/browser workflows; they are not JobiX.
- Do not create real Credit transactions, fund accounts, or execute paid
  exports. Do not introduce AI work.
- Do not stage, commit, push, or rewrite history unless a later user message
  explicitly authorizes it.

## Suggested next task

After repository transfer and owner review, review the existing
`deliverables/jobix-production-readiness-2026-10-09.md` and approve a
specific P0 scope from `docs/NEXT_STEPS.md`. Do not rerun completed audits
without a changed premise and do not implement the report's proposed policies
without explicit owner approval.
