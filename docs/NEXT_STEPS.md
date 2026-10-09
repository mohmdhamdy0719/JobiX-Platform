# JobiX V2 — Proposed next steps

This is a planning document only. The production-readiness assessment and its
policy recommendations must be reviewed in the other Replit account before any
implementation. Items below are not automatically authorized by being listed.
Do not open export gates, deploy, migrate, spend Credits, or change production
or staging without a separate scoped approval.

## P0 — repository handoff and launch blockers

### P0.1 — Complete the private GitHub/cross-account handoff safely

- **Objective:** preserve the current source history and deliverable pointers
  while making the repository usable from the destination Replit account.
- **Status:** local `main` is at `20696923c17c`; the local tree was clean apart
  from the newly attached handoff brief before these uncommitted documentation
  edits. Git LFS integrity passes locally for seven tracked APK/archive
  deliverables. The configured GitHub `origin` and destination branch were not
  fetched or written during this task.
- **Relevant files:** `.gitattributes`, `.gitignore`, `docs/handoff/10_MIGRATION_GUIDE.md`,
  `docs/handoff/history/GIT_HISTORY.md`, `deliverables/`.
- **Dependencies:** owner reviews these docs and explicitly stages/commits/
  pushes from the source account; verify native Git authentication and Git LFS
  access in both accounts.
- **Acceptance:** no force push or history rewrite; compare local and destination
  commit graphs before reconciliation; verify every LFS pointer resolves after
  transfer; verify the new account can fetch source and LFS content. Decide
  whether the existing ~615 MiB of APK/archive deliverables belongs in GitHub;
  do not delete/untrack it as an incidental cleanup.
- **Approval/cost:** destination access and any history action require owner
  control. No cloud resources or Credit cost; Git LFS storage/bandwidth may incur
  account-plan costs.

### P0.2 — Review the existing production-readiness assessment and approve a
bounded P0 scope

- **Objective:** owner review of the already completed `49/100`, public-launch
  **NO-GO** assessment; select or reject proposals before implementation.
- **Status:** assessment is in
  `deliverables/jobix-production-readiness-2026-10-09.md` and its self-contained
  HTML counterpart. No recommendation has become policy solely through the
  report.
- **Relevant files:** the assessment, this roadmap, `PROJECT_STATUS.md`,
  `mobile/jobix/backend/pdf/ADR-retention-deletion.md`, and
  `mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md`.
- **Dependencies:** read the handoff in the destination account; review unknowns
  and changes against Architecture V2 and explicit product contracts.
- **Acceptance:** record only the exact approved development/production scope,
  owners, tests and rollback constraints. Preserve disabled export gates and
  seven-day logical PDF behavior unless the owner explicitly decides otherwise.
- **Approval/cost:** owner approval required before code/policy work. Review is
  read-only and no-cost; subsequent cloud work may cost money and needs its own
  approval.

### P0.3 — Reconcile complete local backend/RLS acceptance evidence

- **Objective:** establish one current, reproducible result for the full
  disposable `test_rls.sh` harness after the upload-rejection fix.
- **Status:** focused adapter 11/11, guarded acceptance 8/8 and full Node backend
  101/101 are recorded as passing. The same acceptance file also retains an
  earlier full RLS run with 7 pass / 1 fail. A later focused pass does not prove
  the full harness passed.
- **Relevant files:** `mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md`,
  `mobile/jobix/tool/test_rls.sh`, `mobile/jobix/backend/pdf/test/`,
  disposable SQL fixtures.
- **Dependencies:** use only local/disposable PostgreSQL and the exact locked
  Flutter dependencies already present; inspect the current failure before any
  code change.
- **Acceptance:** rerun the full local RLS harness once in a clean isolated
  environment, record exact totals/log-safe evidence, fix only a proven local
  defect without weakening RLS/Credit/ownership/deletion contracts, and align
  the acceptance record. Do not use cloud test accounts or live Credit rows.
- **Approval/cost:** local test run is no-cost; any product/security code fix
  needs review/approval. No migrations or cloud operations.

### P0.4 — Qualify one coherent development release before any more live
acceptance

- **Objective:** resolve source/deployment drift and complete only the already
  approved live security/recovery acceptance when authorized.
- **Status:** the readiness assessment says the current Edge, Gateway and Worker
  deployment is not yet a single image set containing all newer closed-gate
  source changes. The existing personal happy path passed; export gates are
  closed. Live injected renderer/upload faults, stale-worker, expiry and
  deletion/no-residue checks remain unverified.
- **Relevant files/services:** `mobile/jobix/supabase/functions/`,
  `mobile/jobix/backend/export-gateway/`, `mobile/jobix/backend/pdf/`,
  `mobile/jobix/tool/`, development Edge/Gateway/Worker, Scheduler, Supabase
  dev project and private GCS bucket.
- **Dependencies:** P0.2 owner decision; reconcile P0.3 local results; compare
  exact current image digest/config to source; obtain separate development-only
  deployment/test approval. Preserve private Worker, current identities,
  restricted DB role, and gates.
- **Acceptance:** test invalid/expired tokens, cross-account job/profile
  access, recovery auth separation, idempotency, no duplicate debit, bounded
  Credit reservation/finalization/release, expiry behavior, stale-writer
  barriers and deletion verification. Start with read-only/test fixtures;
  chargeable behavior needs a distinct bounded test approval.
- **Approval/cost:** owner approval for every cloud deployment, gate change,
  live Credit transaction or billable test. Cloud Run/GCS/Supabase operations
  may incur cost. Production/staging are explicitly excluded.

## P1 — Reliability, cost, retention and production preparation

### P1.1 — Resolve the PDF backend runtime and dependency reproducibility

- **Objective:** have a supported Node runtime and a reproducible, frozen
  dependency restore for a fresh clone.
- **Status:** Node 20.20.0 satisfies the package engine range but Node 20 is
  end-of-life. The PDF package has no standalone lockfile and is excluded from
  the root pnpm workspace.
- **Relevant files:** `mobile/jobix/backend/pdf/package.json`,
  `mobile/jobix/backend/pdf/Dockerfile`, `pnpm-workspace.yaml`, Node lockfiles.
- **Dependencies:** P0.2 approval and a package-manager decision that preserves
  existing dependency versions before generating/committing any lock.
- **Acceptance:** choose a supported Node line; lock exact existing compatible
  packages without opportunistic upgrades; demonstrate a clean install and
  complete tests; update runtime images only under a separate development
  deployment approval.
- **Approval/cost:** dependency/runtime changes require approval. Local test is
  no-cost; image builds/deployments may incur cloud cost.

### P1.2 — Validate operational monitoring, backup/restore and incident recovery

- **Objective:** prove operators can detect, contain and recover from worker,
  database, storage and email/Auth failures.
- **Status:** production coverage and tested restore runbooks are not established.
- **Relevant files/services:** readiness assessment, Cloud Run, Supabase,
  Scheduler, GCS, alerting, authentication/email.
- **Dependencies:** P0.2; name the production owner and service-level objectives.
- **Acceptance:** bounded alert tests, backup restore to a non-production
  environment, reservation/deletion recovery rehearsal, and documented
  least-privilege incident steps.
- **Approval/cost:** owner approval required; backups, logs and rehearsals can
  incur costs. Never perform destructive production restore tests.

### P1.3 — Decide cost budgets and admission controls from measured demand

- **Objective:** set transparent operational budgets that bound abuse without
  breaking free downloads or recovery.
- **Status:** the report contains estimates, not verified Doha price quotes,
  current invoices, or an app-specific hard cap. A project/service spend cap
  could pause gateway, downloads and recovery together.
- **Relevant files/services:** assessment cost model, Worker/Gateway request
  limits, Cloud Run/GCS/Supabase usage, logging and account admission checks.
- **Dependencies:** P0.2 and measured, representative traffic/cost data.
- **Acceptance:** owner-reviewed per-operation limits, alerts, abuse handling
  and incident procedure; distinguish an alert budget from an actual service
  cap; verify failure does not violate Credit/idempotency behavior.
- **Approval/cost:** explicit owner approval; cloud billing configuration and
  load tests may affect costs or availability.

### P1.4 — Review physical/logical storage retention and deletion completion

- **Objective:** show object, soft-delete, snapshot and database cleanup follow
  the approved deletion contract.
- **Status:** logical PDF lifetime is seven days; the readiness assessment
  observed a further seven-day GCS soft-delete recovery window. Its policy fit
  remains unresolved; no extra retention period is approved.
- **Relevant files/services:** `ADR-retention-deletion.md`, PDF purge/deletion
  code, GCS bucket lifecycle/soft-delete settings, export snapshots and
  deletion-verification RPCs.
- **Dependencies:** P0.2 product decision and P0.4 live deletion evidence.
- **Acceptance:** distinguish expired-download denial from object physical
  deletion; verify account-deletion freeze, lease invalidation, reservation
  release, stale-worker fencing and zero remaining related exports before
  marking deletion complete. Do not alter account-deletion semantics outside
  PDF integration.
- **Approval/cost:** owner approval for any retention/IAM/GCS change; cleanup
  and storage configuration have cloud cost and data-loss implications.

## P2 — Measured optimization

### P2.1 — Run controlled load and regional cost qualification

- **Objective:** establish safe concurrency, latency and cost bounds using
  representative, synthetic accounts.
- **Status:** production throughput, hostile traffic and regional cost are
  unknown; no sustained load test is recorded.
- **Relevant files/services:** Worker/Gateway limits, PDF renderer, Supabase
  connection pool, private bucket and current regional pricing evidence.
- **Dependencies:** P0.2/P0.4, P1.1 supported runtime, P1.3 cost budget.
- **Acceptance:** explicit test window, owner-approved spend ceiling, no
  production personal data, stable idempotency and reservation reconciliation,
  verified saturation/recovery behavior.
- **Approval/cost:** separate approval; may incur meaningful Cloud Run, GCS,
  database and egress costs.

## Later — product work and wider launch

### Later.1 — Arabic/device print review and deliberate UI polish

- **Objective:** validate Arabic RTL typography/pagination and user-facing
  failure/retry/download states on supported Android devices.
- **Status:** M31 successful English PDF download/open is confirmed; that
  profile had no Arabic text. Arabic print and full failure-state device testing
  remain unknown.
- **Relevant files:** Flutter Resume Preview/export flow, fonts and PDF
  renderer.
- **Dependencies:** P0.2 and an owner-provided device/test plan; no generated
  paid export is necessary for local fixture UI.
- **Acceptance:** signed test data, RTL visual review, accessibility and
  download/open/retry states; keep local fixtures separate from live results.
- **Approval/cost:** local visual work needs scope approval; live export costs
  require a separate explicit Credit budget.

### Later.2 — AI generation, paid plans and public production release

- **Objective:** add only owner-approved product services after the PDF MVP is
  stable.
- **Status:** not implemented/accepted; no AI inference, billing or production
  launch is authorized by this handoff.
- **Relevant files/services:** Architecture V2, AI model decision,
  provider/authentication, usage/credit policy, billing and production release.
- **Dependencies:** explicit product/security/cost decisions and all production
  gates above.
- **Acceptance:** separate architecture and threat review, provider and
  payment tests, quotas/cost controls, production operations and owner
  acceptance.
- **Approval/cost:** explicit approval required for code, provider calls,
  credits, payment integration and deployment; may incur charges.
