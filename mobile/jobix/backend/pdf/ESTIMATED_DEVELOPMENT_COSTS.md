# Initial Development export accounting

Owner-approved engineering estimates, prepared 2026-10-16. These are not measured
per-export provider costs, production approval, or a guaranteed invoice ceiling.
Normal Development export is intended: no one-export timer or automatic trial lock.

## Configuration

| Database field | Integer micro-USD | Basis and remaining uncertainty |
| --- | ---: | --- |
| `shared_cost_reserve_microusd` | 3,000,000 | $3 held back from the existing $10 rolling-seven-day admission budget. This is an explicit 30% operational allowance for shared/unattributed work and estimation error, not a measured charge. The owner's approximately $0.85 project-level, 15-day CSV is a scale sanity check only, not PDF attribution or an amount added to settlements. Existing Supabase usage has no displayed overage, but plan costs and future incremental use are not proven zero. |
| `runtime_cost_microusd_per_second` | 100 | Worksheet estimate 75 for the whole 2-vCPU/2-GiB instance, rounded upward by one third. Applied to every measured attempt second without dividing by concurrency, conservatively overallocating shared instance time. Startup/probe time outside the attempt remains an overhead/reserve uncertainty. |
| `output_cost_microusd_per_gib_7d` | 12,000 | Worksheet seven-day Standard estimate 5,290, doubled to 10,580 for seven days live plus seven days soft-deleted; rounded up to 12,000 for metadata/lifecycle timing headroom. The existing column name is retained: the estimator applies this single rate once, not once per day. It deliberately includes the soft-delete allowance here, not in overhead. Lifecycle execution is asynchronous: this is not a strict storage-time bound. |
| `storage_operation_cost_microusd` | 7 | Provisional worksheet rate retained. The official single-region Standard table fetched shows $0.005/1,000 Class A flat-namespace operations, $0.0065/1,000 hierarchical operations, and lower Class B rates. Seven micro-USD exceeds those displayed per-operation values. It prices each Worker-metered call at the higher planning rate; no claim that all calls actually bill at Class A. |
| `per_export_overhead_microusd` | 25,000 | $0.025 per operation for costs outside the attempt/storage meters: repeated signed downloads, Gateway/status/signing requests, per-export cleanup/recovery, logs and Supabase RPC/Edge work. Planning envelope: five full 10-MiB downloads at the published upper $0.23/GiB internet-transfer reference consume about $0.011231; approximately $0.013769 remains for other per-export overhead. Five downloads is an estimate, not a new product restriction. Unlimited free valid re-downloads remain unchanged and can exceed this allowance. |

All five values are estimates. In particular, fetched public price tables can
retain a default regional selection: the worksheet's 75/5,290 are not promoted
to independently verified Doha prices by this document. Live metadata verifies
Doha, request-based Worker 2 vCPU/2 GiB, min 0/max 3, concurrency 2, 900-second
timeout, Standard flat-namespace bucket, seven-day lifecycle and seven-day soft
delete. The owner supplied Supabase cycle totals (145 Edge invocations, 0.08 GB
egress, 0.10 GB log ingestion, 37.78 GB log query, no displayed overage) and zero
recorded export attempts in the audited week; those are not per-export samples.
No free-tier credit or rounded $0.00 SKU is treated as a zero marginal price.

Official references consulted 2026-10-16:
- https://cloud.google.com/run/pricing — request-based billing, regional tiers,
  concurrency sharing, billing-time rounding; Doha is Tier 2.
- https://cloud.google.com/storage/pricing — Standard storage, soft-deleted
  storage billed like live storage, operation classes and internet transfer.
- https://cloud.google.com/storage/docs/lifecycle — asynchronous lifecycle.
- https://cloud.google.com/storage/docs/soft-delete — separate soft-delete period.
- https://supabase.com/docs/guides/platform/manage-your-usage — usage/allowances.

## Formula, limits and examples

Migration 021 uses integer micro-USD:

`H + ceil(T_ms * R / 1000) + ceil(B_bytes * O / 1073741824) + N_ops * S`

- Illustrative, **not measured typical**: 30,000 ms, 1 MiB, three metered calls:
  `25,000 + 3,000 + 12 + 21 = 28,033` micro-USD ($0.028033).
- Configured maximum over all attempts: 1,800,000 ms, 10 MiB, 24 calls:
  `25,000 + 180,000 + 118 + 168 = 205,286` micro-USD ($0.205286).
- $7 admission capacity remains after the $3 reserve: 34 simultaneous
  maximum-sized holds fit if there are no prior costs. Existing atomic budget
  admission counts other held/settled costs too. Settlement frees unused
  capacity; ambiguous work retains its hold. This is not a lifetime export limit.

Initial activation advances model version 1 to 2 because rates change, only with
no active exports, pending export Credit reservations, held costs or unsettled
uploads. Idempotent exact configuration replay does not advance it again.
The $10 budget, seven-day window and all existing caps/limits remain unchanged.

## Meter coverage and reconciliation

Worker `storageStep` counts inspect/read/create attempts, including failed
calls, across retries. A fresh successful attempt normally performs inspect,
create and read; the adapter has no automatic fetch retries. `runtime_ms` covers
the attempt; settlement aggregates attempt runtime and operation counts and
uses maximum PDF size, so retries do not multiply storage bytes or fixed H.
Worker rendering/validation are not charged again as separate CPU line items.

Gateway metadata/signing/status traffic, actual downloads and cleanup listing/
deletion are not in the attempt counter: allocate their per-export component
to H. Shared scheduler runs with no export, shared log/Supabase activity and
unattributed residual variance belong to the fixed reserve. Do not add the same
cost again to both H and the reserve when reconciling. Do not add provider
billing totals to reservations/settlements; compare them as evidence and
allocate only the unexplained residual. Existing provider-observation rows are
evidence, not another admission charge.

The five-download envelope, unmeasured Gateway/cleanup/Supabase activity,
lifecycle delays and current lack of resource-level billing attribution remain
uncertainties. Growing downloads or shared use can exceed these estimates; the
admission budget cannot stop every already-issued signed download or all
provider charges. Review against the existing seven-day reconciliation
checklist after real usage; do not claim complete invoice coverage.

## Supported guarded configuration

`tool/configure_estimated_export_dev.mjs` uses the existing approved
`JOBIX_DEV_DATABASE_URL`, verified CA, fixed project and actual object-owner
identity checks, source/ledger checksums through 021 and the existing migration
advisory-lock key. It changes no schema, grants, migration ledger or historical
migration. Policy configuration is transactional; the DB admission gate stays
closed while the existing gate tool creates exactly two gate-only revisions.
Service template, IAM and traffic comparisons must pass before DB admission
opens last. No Scheduler run, export request, user funding or test-record
creation is issued. A failed activation stops; partial cloud gate changes are
not hidden by automatic retries or extra revisions.

Local fixture validation is integrated into `tool/test_rls.sh --resume-export-only`.
The fixture uses its existing Unix socket with TCP disabled and rolls back the
configuration and synthetic test rows before the remaining regression tests.
