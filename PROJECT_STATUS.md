# JobiX V2 — Project status

**Snapshot date:** 2026-10-09  
**Local source revision at the start of this handoff update:** `20696923c17c` on
`main` (65 commits reachable locally).  
**Assessment:** Development MVP has a verified, bounded authenticated PDF
happy path; **public production is NO-GO**. No tests, cloud checks, exports,
builds, migrations, or deploys were run for this documentation update.

Evidence citations refer to tracked repository records. “Owner-confirmed” is
kept distinct from agent/device instrumentation; local fixtures are not live
cloud evidence.

## Verified working

| Capability | Evidence and scope |
|---|---|
| Native app and authenticated personal resume | The owner confirmed the ARM64 debug APK was installed on a Samsung M31, signed in, and showed the existing personal resume. See `mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md` and `mobile/jobix/VERIFICATION.md`. |
| One personal PDF export, download, and open | Owner confirmed the first PDF was downloaded and opened on the M31. Backend reconciliation recorded one completed job, one 2-Credit debit/consumed reservation, no pending reservation, and the same preserved PDF after the later queued intent expired. This is one successful development case, not a scale or production test. |
| Export status and recovery after the second explicit intent | The owner said they chose Export Again and confirmed it. The gates remained closed before the extra queued request was rendered or charged; the eligible reservation was released after its natural expiry. No manual balance edit, refund or repeat paid export was used. |
| Local export failure/retry/idempotency suite | `PHASE3_ACCEPTANCE.md` records focused adapter 11/11, guarded disposable acceptance 8/8, and backend regression 101/101 after the upload-rejection fix. It also records Flutter default-off 4/4 and 18 enabled-fixture cases, with a focused 2/2 rerun for corrected localized status expectations. These results are recorded evidence; they were not rerun for this handoff. |
| Anonymous PDF access denial and baseline layout | The acceptance record documents 403 for anonymous access to the actual stored PDF and English print inspection without clipping. The actual resume contained no Arabic text, so this does not verify Arabic print quality. |
| Git LFS objects in the current local checkout | Seven tracked APK/archive deliverables are LFS-managed; `git lfs fsck --objects` passed locally. This does not prove the destination GitHub LFS objects can be uploaded or fetched by the other account. |

## Implemented but not fully verified

- The development flow is Flutter → Supabase Auth/Edge → authenticated
  development Gateway → private PDF Worker → restricted database/GCS. Edge and
  Gateway authenticate/authorize user requests; actor identity is server-derived.
  Only the Gateway is intended to be publicly invokable. Current development
  revisions recorded in the assessment are Edge `v7`, Gateway
  `jobix-dev-export-gateway-00010-4rp`, and Worker
  `jobix-dev-pdf-export-00011-tnk`, in `me-central1`. Verify deployment state
  again only under explicit scope; do not rely on a dated revision label as a
  fresh health check.
- The Worker remains private, and the Gateway is the public authenticated
  bridge. The three service-level `JOBIX_EXPORT_ENABLED` flags and the
  development `export_settings.enabled` gate were recorded false after the
  personal test. The approved deletion-policy flag remains true. Do not confuse
  that policy approval with permission to create or charge new exports.
- Job-bound Credit reservations, atomic create/idempotency, immutable snapshots,
  retry fencing, logical expiry, generation-bound signed downloads, recovery,
  and export-aware deletion logic have local tests. Local SQL/object-map
  fixtures are not live injected-failure, stale-writer, or deletion evidence.
- Resume Preview/export UI has fixture-backed Flutter tests. The actual M31
  happy-path download/open is confirmed; Arabic layout, platform failure/retry
  UI and broad device acceptance are not.
- Android backup exclusions, production release signing, Node worker image
  support, monitoring, backup/restore, and capacity limits are not fully
  qualified for production.

## Known gaps, blockers and risks

1. **Deployment/source drift:** the readiness assessment records deployed
   Gateway/Worker images older than the latest source-level closed-gate behavior.
   A green local suite does not prove the deployed image contains that change.
2. **Incomplete live acceptance:** deployed injected renderer/storage failure,
   retry after ambiguous response, stale-worker fencing, expiry and account
   deletion/no-residue checks remain unverified as live cloud behavior.
3. **RLS test record needs reconciliation:** the acceptance document preserves a
   historical full `test_rls.sh` result of 7 pass / 1 fail, followed by a later
   focused guarded acceptance result of 8/8 and backend regression 101/101.
   Do not claim the complete RLS harness is green until its current full result
   is recorded and the historical failure is resolved or shown to be
   superseded.
4. **Node runtime:** PDF package declares Node `>=20.20.0`; the local
   environment is Node 20.20.0, whose major line is end-of-life. No Node upgrade
   is authorized here.
5. **PDF dependency reproducibility:** `mobile/jobix/backend/pdf` is outside
   `pnpm-workspace.yaml` and has no standalone dependency lockfile. A frozen,
   clean-clone install command for its `pg`/Playwright dependencies is therefore
   not established. Do not generate a lockfile or upgrade dependencies without
   approval.
6. **Retention/cost:** PDF logical expiry is seven days. The readiness
   assessment found a separate seven-day GCS soft-delete recovery window after
   object deletion. That is not a download entitlement, but it needs explicit
   review against the owner-approved deletion contract; do not change it
   silently.
7. **Scale and production readiness:** no sustained load/capacity qualification,
   hostile-traffic cost bound, production service-level target, production
   signing, email delivery, or tested backup/restore is established. The
   readiness assessment scores the current production posture 49/100 and
   recommends NO-GO for public launch. Cost figures there are estimates, not a
   regional quote or current invoice.
8. **AI and commerce:** AI generation/provider history and subscriptions/
   payments are not implemented/accepted. Approved model decisions do not
   authorize provider deployment or charges.
9. **Cross-account Git handoff:** the working tree has a GitHub `origin` remote
   and local tracking refs, but no remote fetch/push was performed for this
   handoff. Verify the actual destination branch/history and LFS transfer
   permissions from the other account before publishing or continuing.

## Proposed, not implemented policies

These are review recommendations, not approved product behavior:

- Abuse/rate limits and bounded unauthenticated/authenticated preparation work.
- Cloud and provider cost budgets, admission controls, and operational alerts.
- Any change to storage/deletion retention beyond the approved seven-day logical
  PDF period.
- New-region migration, production scaling/concurrency, public beta limits, or
  launch rollout.
- AI budgets, model fallback, or production AI provider activation.

Do not implement these merely because they appear in the production-readiness
assessment. See `docs/NEXT_STEPS.md` for the scoped review gates.

## Current development configuration

Read-only inventory in
`deliverables/jobix-production-readiness-2026-10-09.md` records:

- Project `mhflow-jobix`, region `me-central1`.
- Public, user-authenticated development Gateway; private PDF Worker.
- Gateway identity `jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com`;
  Worker identity `jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com`;
  recovery identity `jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com`.
- Restricted database role `jobix_export_runtime`; private development PDF
  bucket; existing recovery Scheduler.
- Edge/Gateway/Worker new-export flags false, database export gate false, and
  deletion-policy approval unchanged/true at the assessment snapshot.

These are dated development facts, not credentials or authorization to change
cloud state. Production/staging status must not be inferred from them.

## Current acceptance disposition

- **Verified:** one authenticated personal M31 export/download/open; one debit;
  no outstanding reservation after the explicit extra request expired;
  local deterministic export retry/fencing/failure coverage described above.
- **Partial:** UI interactions exercised in mocked Flutter fixtures; English
  print inspection; baseline anonymous object denial.
- **Unverified:** the full current local RLS script after the recorded earlier
  failure; live injected failures/retries and account deletion; new Android
  failure-state/Arabic-layout coverage; production capacity, release and
  restore/observability qualification; destination-account Git/LFS transfer.

No broader Phase 3 or production acceptance is claimed. Do not repeat or
refabricate the successful personal export.
