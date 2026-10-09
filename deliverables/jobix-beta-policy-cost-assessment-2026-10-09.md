# JobiX V2 — beta policies and operating-cost plan

**Date:** 2026-10-09. **Status:** assessment only; no implementation authorized.

Evidence labels: **SOURCE** means inspected repository behavior; **DATED VERIFIED** means the October 9 readiness assessment's development-provider reads, not a fresh live recheck; **ESTIMATE** means stated assumptions; **UNKNOWN** means evidence is insufficient. Recommendations and all new numbers below require owner approval.

## A. Executive summary

**Keep:** Architecture V2, Flutter/Supabase, the verified personal development PDF journey, immutable snapshots and Credit ledger, successful-export charging of 2 Credits, free previews and valid downloads, seven-day logical PDF availability, and existing deletion fencing. Do not repeat the personal export or activate AI/rewards.

**Change before controlled beta:** race-safe admission before expensive preparation, one consistent export policy, verified-signup grant eligibility, bounded free traffic/global resource budgets, and an approved storage/recovery policy. Resolve the already-recorded deployed/source drift before relying on closed-gate download behavior.

**No architecture or regional migration is justified by current evidence.** Exact Doha/Frankfurt prices, actual subscription and end-to-end latency are incomplete. Retain the current development placement until a measured total-cost comparison proves a material benefit.

The principal new policy gaps are:
1. The proposed 1/5-minute, 3/hour, 5/24-hour and 10/30-day limits are not the current 5/10-minute rule.
2. Expensive canonical preparation precedes final admission and Credit reservation.
3. Signup +5 is unique per account, not per person, and the trigger does not wait for verification.
4. PDF expiry does not remove immutable HTML. Recoverable GCS objects can outlast seven days.
5. Credits do not bound free preparation, failed work, signup farming or future AI spend.

## B. Current-state inventory

| Area | Evidence and current state | Unresolved |
|---|---|---|
| Export admission | **SOURCE:** `202610080012_resume_export_foundation.sql`, overridden by `202610080015_resume_export_local_hardening.sql`: five jobs in preceding ten minutes. `jobix_export_replay` locks the user, validates the request hash, and returns accepted-key replay before mutation. `jobix_export_create` reserves 2 Credits and persists snapshot/job/idempotency atomically. | No proposed multi-window policy or demonstrated one-active-intent rejection. |
| Preparation | **SOURCE:** `backend/pdf/gateway.mjs` prepares new `create`/`again` after replay but before transactional create. `document.mjs` invokes Dart canonicalization; 30-second timeout, 8,000,000-byte subprocess output ceiling, 200k-byte source-text ceiling. | These bounds are not a whole-app request/CPU budget. |
| Signup | **SOURCE:** `202610030002_first_vertical_slice.sql` inserts public user on Auth INSERT; `202610030004_core_shell_credits.sql` then grants +5 through `jobix_signup_credits`. Uniqueness is per `user_id`; no verified-state predicate. | No cross-account human identity guarantee or global grant budget. |
| Existing records | **DATED VERIFIED:** six accounts; ledger aggregate signup +15, adjustment +2, export −4; balance 13, reserved 0; two COMPLETED and one FAILED export. | Aggregate does not establish each account's verification/identity eligibility. No personal rows inspected for this report. |
| Supabase/Auth | **DATED VERIFIED:** healthy Frankfurt `eu-central-1`, PG 17.6; email/Google enabled, anonymous disabled, email autoconfirm false; database ≈17.44 MB. | Actual plan, compute, allocated disk, quotas/usage, spend, PITR and backup retention UNKNOWN. |
| Development services | **DATED VERIFIED:** Edge `resume-export` v7; Gateway revision `jobix-dev-export-gateway-00010-4rp`: 1 vCPU/256 MiB, concurrency 20, timeout 60s, revision max 1/service max 3. Worker `jobix-dev-export-worker-00011-tnk`: 2 vCPU/2 GiB, concurrency 2, timeout 900s, max 3. Both Doha. | Current effective instance allocation/minimum settings and source/image coherence require a bounded release check. Instance ceilings are not a monetary guarantee. |
| Gates | **DATED VERIFIED:** Edge/Gateway/Worker/DB export gates false; deletion policy approved. | Current live values not reread here. Do not change them. Local-source free-download behavior is not proof of the older deployed combination. |
| Storage | **DATED VERIFIED:** private STANDARD GCS Doha bucket; uniform access; lifecycle Delete for `exports/*.pdf` at age 7 days; soft delete 604800 seconds. Scheduler every minute. | Versioning, retention locks, independent backups and exact cleanup lag UNKNOWN. |
| HTML | **DATED VERIFIED:** three snapshots; mean raw HTML 1,486,641 bytes, stored column 992,239 bytes; total snapshot relation 3,227,648 bytes. **SOURCE:** accepted exports persist snapshots; preview preparation does not insert an export snapshot. | Sample is too small for a capacity guarantee. No time-based snapshot purge at PDF expiry. |
| AI | **SOURCE/approved decision:** `gemini-3.5-flash`, global endpoint approved; allowance foundation/UI exists, not operational inference. First-profile allowance 6; Cairo-day 3, conditional premium 10. | Exact generation calls, token distribution, timeout/retry/output caps, paid-provider credentials and runtime controls are not implemented/proven. |
| Validation | Existing handoff: Node 104/104; Flutter analysis blocked by 144/150 unavailable package roots; PDF runtime `pg`/`playwright` unavailable. | No new build, package restore, paid test or export run. These results do not prove deployed behavior. |

Repository was clean before this report: `main`, ahead of its locally recorded `origin/main` by two commits. No remote refresh or history action was performed.

## C. Policy matrix and action costs

| Proposed policy | Current behavior | Required layer / contract impact / approval |
|---|---|---|
| 1 accepted new export/5m; 3/rolling hour; 5/rolling 24h; 10/rolling 30d | 5 jobs/10m | SQL-authoritative admission, replacing—not stacking with—the old rule. Product limit change; approve numbers and counting semantics. |
| One active intent per user/profile | User lock serializes transactions, but does not itself reject another active intent | SQL invariant covering preparation lease and active job states; approve what “active” includes. |
| Replays free; Again new; failed logical jobs count but are not charged | Replay/Again and successful-only settlement exist | Preserve them; accepted FAILED/released jobs consume logical quota. Rejected invalid/preparation requests consume separate resource budgets, not a new logical export. Approve. |
| Insufficient Credits prevents paid work | Reservation is authoritative, but follows preparation | Begin bounded admission/reservation before preparation; no preview/download charge. Lifecycle change needs approval. |
| +5 only after verified first eligible signup | +5 immediately once per public account | Server grant eligibility + registry, non-destructive backfill; changed timing/eligibility. “Same person” requires an explicit achievable identity policy. |
| Seven-day PDF availability | Download checks expiry; signed TTL capped by remaining lifetime | Preserve. Physical erasure timing differs; soft-delete/lock changes require separate approval. |
| Bounded snapshots and free traffic | Persistent snapshot HTML; no approved time purge/global traffic budget | Monitoring first; choose retention/budget before any purge. Contract/data-loss implications require approval. |
| Bounded AI and signup/reward budgets | Allowance foundation only; no operational AI/reward issuer | Server counters + cost admission; do not activate either. Approve budgets separately from Credits. |

| Action | Credits now | Infrastructure cost | Insufficient-Credit policy |
|---|---|---|---|
| Preview/canonical document | 0 | DB reads, Dart CPU, large response bandwidth | Remains free; separate request/byte/CPU limits. |
| New export / Export Again | Reserve 2; debit only successful completion; failure releases | Preparation, DB writes, render attempts, storage | Reject before expensive paid work through authoritative admission/reservation. Again uses current profile and counts as new. |
| Existing eligible download | 0 | DB/object checks, URL signing, GCS egress per download | Never block for low balance; no new export count. Expired/missing object returns an error, not regeneration. |
| Planned AI | No implemented paid generation contract | Variable model tokens and orchestration | Credit pricing/eligibility UNKNOWN; do not invent a debit. Enforce approved allowance and separate model-cost budget before calls. |

**Admission design:** a new SQL preflight record obtains a bounded lease and reserves 2 Credits against a predetermined operation ID under an account lock, after replay and all gates/ownership/limits checks. Preparation runs only after this succeeds. Final create atomically binds that reservation/admission to the immutable snapshot and job; no second reservation/debit. Preparation validation failure, lease expiry or cancellation releases it idempotently. Recovery handles abandoned admissions. This is a proposed two-phase lifecycle, not an existing RPC; it must be reviewed against reservation timeout and deletion fencing before implementation.

Count accepted logical jobs using server `timestamptz` and windows `(now − interval, now]`, with eligibility at exact boundary expiry. Retain admission-count evidence for at least the longest window while the account exists. Replays neither count nor consume resource permits again; conflicting payload/key fails. Compute retry-after as the maximum wait across violated windows; active intent returns its status rather than starting another. Use SQL locks/constraints, not isolated Edge counters. Protect preparation failures with an independent attempt budget to prevent free retries becoming a bypass.

Suggested bilingual responses:
- `CREDIT_INSUFFICIENT`: “You need 2 available Credits to export.” / “تحتاج إلى رصيد متاح قدره 2 Credits لتصدير الملف.”
- `RATE_LIMITED` + `retry_after_seconds`: “Export limit reached. Try again in {time}.” / “وصلت إلى حد التصدير. حاول مجددًا بعد {time}.”
- Active intent: “An export is already in progress.” / “يوجد تصدير قيد التنفيذ بالفعل.”
- Expired/missing: “This PDF is no longer available. Export Again creates a new export for 2 Credits.” / “لم يعد هذا الملف متاحًا. ينشئ «تصدير مرة أخرى» ملفًا جديدًا مقابل 2 Credits.”

No automatic paid retry/new idempotency key. Allow status polling, explicit same-key replay, and free download. Retry-after UI is informative; server time remains authoritative.

### Verified-signup grant design

Stop awarding from unverified Auth INSERT only after an approved migration. A privileged verified-confirmation path should transactionally check eligibility, claim a new unique server grant record, and append exactly one +5 SIGNUP ledger event. Client cannot request or forge the claim.

Backfill existing SIGNUP ledger accounts as already claimed; never issue a second bonus, revoke balances or rewrite ledger. Existing accounts without a SIGNUP entry need a reviewed eligibility rule—not an indiscriminate backfill. Test email confirmation and linked-provider event ordering.

Same Auth identity recovery should retain claim status. Provider linking must merge claim eligibility without another grant. Duplicate events and concurrent signups require unique constraints plus locking. Account deletion/re-registration needs an approved minimal claim-tombstone policy; retaining an identity digest is still personal-data processing. Any keyed digest/retention requires privacy review and protected server configuration.

Verified email/Google proves account control, not one human. Reinstalls/local-storage clearing/device changes must not reset server claim records, but unrelated verified accounts can still evade a human-level rule. Do not fingerprint devices or treat IPs as identities. For beta, invite eligibility, voluntarily linked verified provider identity, short-lived velocity signals and a global grant budget are a privacy-conscious combination—not a guarantee. Decide what to do when the budget is exhausted before signup is offered; do not silently promise +5 and issue 0.

## D. Storage and deletion matrix

| Category | Current lifetime / deletion mechanism | Proposed control; residual retention |
|---|---|---|
| Disposable preview HTML | Generated response; no accepted-export snapshot insertion | No permanent preview cache. Optional short owner-scoped cache keyed by source/template/asset versions, authorization and hash; invalidate on edits/deletion, never serve cross-account. RAM/TTL cache only if measured worthwhile. |
| Immutable canonical snapshot | Persisted on accepted export; survives PDF expiry; removed by fenced profile/account purge | Keep until owner chooses audit/re-render/verification retention. No automatic seven-day purge. Never remove an active job's snapshot. Backups may retain deleted rows. |
| Profile/resume source and photos | Independent account/profile contract | No new expiry inferred from PDFs. Purge only approved account/profile deletion paths; backup lifetime UNKNOWN. |
| Active PDF generation | Logical expiry at seven days; API denies expired/missing files | Cleanup plus lifecycle asynchronously deletes verified generations. Failures alert/retry; logical denial must not depend on cleanup success. |
| Recoverable PDF generations | GCS soft-delete window seven days after deletion | Recoverable physical storage may approach 14 days or longer with cleanup lag/locks. No promise of immediate hard erasure. Versioning/locks/backups must be verified. No shortening without approval. |
| Signed URL | `gateway.mjs`: TTL `min(600, expiry−server_now)`; `google.mjs` signs exact generation | Source TTL does not extend past logical expiry; no new fix indicated. Test near-expiry rounding/clock margin. URL is shareable bearer access while valid; deletion cannot instantly revoke every previously issued capability unless the object is removed. |
| Jobs/admission/idempotency/ledger | Jobs/snapshots purged via approved deletion; ledger has its own immutable contract | Keep at least admission window evidence, and preserve accounting requirements. Define any longer audit retention explicitly; no ledger rewrite. |
| DB backups/PITR | Current configuration UNKNOWN | Owner must supply retention/recovery settings. Row deletion is not backup erasure. |
| Logs, build images, handoff archives | Actual retention/PII exclusions UNKNOWN | Structured IDs/counts, no resume/token/signed URL logs; choose log/image/archive retention independently. Logging's price inclusion period is not proof of configured retention. |

`cleanup.mjs` and `jobix_export_purge` require deletion state, writer/upload quiescence, verified object absence and no pending reservations. Preserve stale-worker fencing and generation-specific deletes; failed cleanup must never report successful physical purge or reopen downloads.

**Storage optimization:** Postgres already compresses HTML; raw-to-stored reduction is observed. Do not count generic compression savings twice. Benchmark immutable font/template deduplication into versioned content-addressed bundles only after correctness design: preserve canonical hash and exact historical renderer assets. New GCS non-PDF assets would require an Architecture V2 decision; do not introduce them casually. Conditional/versioned preview responses can reduce repeated large transfers without weakening authorization.

## E. Cost and headroom scenarios

### Supabase evidence required

Provide sanitized dashboard values, not credentials/payment details:
1. Organization Billing: plan, compute credits, spend cap/overage setting, current month usage/spend.
2. Project compute/disk: instance size, provisioned disk, used bytes, database/table/index/WAL breakdown and autoscaling settings.
3. Usage: DB/storage included quotas and used bytes; cached/uncached egress, MAU, Edge invocation quotas/usage.
4. Backups: daily retention, PITR enabled/window and charges.
5. Organization allocations across projects/add-ons and forecast/invoice service totals.

Until supplied: all actual plan/compute/quota/headroom/spend values are **UNKNOWN**. Database size/connection count cannot identify the plan. Official Free 500 MB or Pro 8 GB examples are not this project's subscription.

| Exports/month | Stored HTML added/month, decimal GB | At unchanged rate over 12 months |
|---:|---:|---:|
| 500 | 0.496 | 5.953 GB |
| 1,000 | 0.992 | 11.907 GB |
| 5,000 | 4.961 | 59.534 GB |
| 10,000 | 9.922 | 119.069 GB |

These are column-only projections from three rows. Relation overhead, indexes, other tables, images and backups add storage. Use `remaining_exports ≈ (approved usable quota − current total usage − safety reserve) / measured incremental total bytes per export`, not raw HTML alone. Warning candidates: 50/70/85% of the approved disk budget, with forecast alerts at 30/14 days to threshold; pause new snapshot-producing work before exhaustion, preserve downloads/recovery. No approved cleanup period exists yet.

Twenty previews/MAU/month at 1.487 MB raw response is an **illustration**, not measured usage: 500/1,000/5,000/10,000 MAU produce roughly 14.87/29.73/148.66/297.33 GB before transport compression. MAU is not monthly exports.

### Export-path sensitivity, not a Doha quote

Reuse the readiness assessment's transparent **Iowa default-price reference**: CPU $0.000024/vCPU-second; RAM $0.0000025/GiB-second; requests $0.40/million; STANDARD storage about $0.02/GiB-month. These are not verified Doha/Frankfurt rates.

Assumed fixed platform baseline: Pro/Micro $25 + registry $0.14 = $25.14/month, neither actual project billing nor a complete fixed bill. Recovery calls are included in the subtotal; other services are excluded.

| Scenario | Worker seconds/attempt | Attempts/logical job | Gateway calls × seconds | PDF/downloads |
|---|---:|---:|---|---|
| Low | 10 | 1 | 8 × 0.2 | 0.15 MiB / 1 |
| Expected | 30 | 1.05 | 22 × 0.5 | 0.30 MiB / 2 |
| High | 120 | 3 | 60 × 1 | 1 MiB / 5 |

| Monthly logical jobs | Low reference subtotal | Expected | High |
|---:|---:|---:|---:|
| 500 | $27.75 | $28.46 | $38.04 |
| 1,000 | $28.05 | $29.48 | $48.63 |
| 5,000 | $30.44 | $37.59 | $133.37 |

Subtract $25.14 to isolate the model's export/recovery variable subtotal. Conservative per-attempt worker compute at these reference rates is $0.00053 × seconds: $0.0053/$0.0159/$0.0636; failures/retries add work. Steady PDF storage assumes seven active plus seven soft-deleted days, timely deletion, and no locks; this is a costing assumption, not retention approval.

**Excluded/UNKNOWN:** actual regional adjustments, minimum-instance cost, Cloud Run outbound transfer, free-preview volume, snapshot disk growth, normal Auth/profile traffic, additional projects, backups/PITR, SMTP, logs/builds/secrets/monitoring, taxes and discounts. Free allowances are billing-account shared and not deducted here. These subtotals are not full monthly production bills.

Regional monthly formula:
`fixed + allocated_vCPU_seconds×regional_CPU_price + allocated_GiB_seconds×regional_RAM_price + requests×request_price + minimum_instance_allocation + retained_GCS_GiB_month×storage_price + operations + GCS_download_GiB×destination_egress_price + Run_outbound_GiB×network_price + Supabase_overages + AI + other_services − applicable_credits`.

### AI sensitivity

Official pricing inspected for **Gemini 3.5 Flash Global**: $1.50/million input tokens, $9/million output tokens; non-global listed $1.65/$9.90. Use the approved global choice, not an unapproved substitute. App token use is UNKNOWN because inference is not operational.

Formula/request: `input_tokens×1.50/1m + output_tokens×9/1m`, plus separately priced features if enabled. An illustrative 2,000-input/1,000-output request costs $0.012; 500/1,000/5,000 such requests add $6/$12/$60. AI request counts are independent of exports; this is not an app usage forecast or authorization to run calls.

## F. Region comparison

| Placement | Potential advantage | Cost/latency risk and evidence required |
|---|---|---|
| Keep Doha Run + GCS, Frankfurt Supabase | No migration; render objects colocated; current working development path | DB calls cross region/providers. Exact regional Run/storage and outbound network rates UNKNOWN; p50/p95 DB/render/download latency UNKNOWN. |
| Frankfurt Run, Doha GCS | Shorter geographical DB path | PDF writes/reads cross region; CPU savings cannot be assumed. Need selected regional SKUs, transferred bytes and latency. |
| Frankfurt Run + GCS, Frankfurt Supabase | Geographical colocation for DB/object traffic | Supabase remains a separate provider; migration/deletion/recovery/privacy costs. New bucket location/object identities, service audiences/IAM and signed URL verification must be rehearsed. |
| Dammam or another nearby Gulf region | Candidate if residency/user geography supports it | No demonstrated cost/latency advantage. Verify exact service availability, regional constraints/SKUs and GCS colocation before comparing. Not a recommended move. |

Official pages list Doha and Frankfurt, but fetched price tables defaulted to Iowa; selected regional numerical rates were not reliably returned. **Actual low/expected/high total bills for each candidate are UNKNOWN.** Apply section E's workload to selected CPU/RAM/request/idle/network/storage SKUs in a dated calculator export, plus measured transfer volumes. Do not invent regional multipliers.

Published GCS regional STANDARD operation reference: $0.005/1,000 Class A; $0.0004/1,000 Class B. Egypt-relevant initial internet-transfer reference is $0.12/GiB, with destination/band exceptions. Actual billing mix remains unknown. No free Doha storage assumed. Minimum instances and cold-start policy can dominate a small beta; collect actual billed allocation rather than multiplying request counts alone.

**Recommendation:** current placement is the lowest-risk reasonable baseline, not a proven cheapest region. Migration requires measured savings exceeding migration/operations cost, acceptable latency/cold-start availability, residency approval, and proof of unchanged private service authentication, generation-bound signing and deletion fencing.

## G. Prioritized implementation plan

### P0 — before controlled beta

1. **Approve policy semantics and evidence gaps:** limits/counting, grant eligibility, storage/recovery promises, free-traffic/global budgets; obtain sanitized billing/backup/retention fields. Keep gates closed. Risk: contradictory promises or incomplete erasure guarantees.
2. **Admission/reservation lifecycle:** add the preflight lease, multi-window SQL policy and active-intent invariant; reserve before heavy paid preparation; recover abandoned leases; expose retry-after in English/Arabic. Risk: stranded Credits, double reservation or deletion races. Dependency: item 1.
3. **Verified signup grant:** privileged verified-event claim registry and immutable ledger append; backfill already-granted accounts without changing balances. Start invite-only with a finite grant budget. Risk: duplicate grants, privacy retention or denying legitimate recovery. Dependency: explicit identity/deletion policy.
4. **Separate resource budgets:** proposed starting ceilings: 100 accepted export intents/day and 1,500/rolling 30 days globally; 150 render attempts/day, max 3 attempts/intent; preparation 6/minute and 60/day/user, global 2,000/day with byte/CPU ceilings; signing 10/minute/user with egress monitoring, never a Credit charge. These are unapproved planning numbers, not measured capacity. Reject only new work when exhausted; preserve eligible download/status/deletion/reconciliation. Define global bytes/CPU ceilings from billing evidence before activation.
5. **Retention/release consistency:** verify versioning/locks/backups and URL boundary behavior; align Edge/Gateway/Worker source/revision evidence in an approved development release task. Test scheduler/cleanup failure and closed-gate read/recovery contracts. No new personal paid export required for initial proof; use mocks and approved fixtures.

### P1 — before public launch or meaningful growth

- Measure cost/latency/bytes per preparation, render attempt, successful PDF and download; DB total-growth slope; pool/queue pressure. Load tests require separate spend approval.
- Implement the owner-approved snapshot retention/storage budget with idempotent, fenced cleanup only after product/audit review; monitor forecast first.
- Before enabling AI: preserve allowance semantics (6 first-profile, Cairo-day 3; premium 10 only when eligibility is real). Candidate additional abuse ceilings: 30 requests/user/rolling 30 days; concurrency 1/user; input 8k/output 2k tokens; 60-second timeout; at most one bounded transient retry, counted in token/cost budget. Global candidate ceiling 100 calls/day and $5/day/$50/month, whichever binds first, with reservation of maximum token cost and atomic reconciliation. These are separate unapproved controls and may constrain the current daily allowance; explicitly approve that change.
- AI server-only calls, no model keys in Flutter, ownership-safe source/model/prompt-version cache, stable idempotency, payload limits and no automatic background generation. No cross-account content cache. Token budgets include failed/retried calls; stop new AI admission on ceiling/provider uncertainty.
- Privacy-conscious anti-farming signals, production backup/restore proof and release observability. Future AdMob +2 remains disabled until verified SSV/revenue/abuse evidence and approval; AI allowances, ad Credits and operating dollar budgets are distinct.

### P2 — only if measurements justify it

- Immutable font/template deduplication and smaller repeated preview responses; assess exact-render/hash compatibility before migration.
- Regional relocation or service separation only after the total-cost/latency proof in F.

**Financial safety:** operational budget counters are not Credit ledger entries. Use atomic actor/global permits and separate attempt/token/byte meters, bounded queues and alerts at 50/80/90% of approved budgets. Alerts alone do not stop spending. Cloud Run spend-cap budgets are documented for eligible service/project scopes, but this account's support/current cap is UNKNOWN; a cap can interrupt Gateway/Worker downloads and recovery. Treat as emergency backstop with a pending-reservation runbook, not normal admission. Instance caps also are not exact hard spend caps. Do not disable all read paths to stop new generation.

## H. P0 acceptance evidence

| P0 item | Required proof before enabling beta |
|---|---|
| Policy/evidence decisions | Dated approved policy matrix; sanitized dashboard/SKU values or explicit accepted UNKNOWNs; documented recovery/physical-erasure language. |
| Export admission | Exact-boundary tests for all four windows and UTC clock; parallel requests across instances allow only eligible intents; active-intent race; replay returns same job/no new counter or debit; payload/key conflict fails; Again counts; FAILED/released counts without debit; no overlapping 5/10m policy. |
| Preflight/Credits | Low available balance starts no canonicalizer/render; concurrent balance use cannot over-reserve; prep exception, timeout, crash and retry release/expire once; final create reuses reservation; success debit exactly −2; deletion waits for admissions; abandoned lease recovery never creates a duplicate job. |
| Grant eligibility | Unverified INSERT gets no new grant; verification event once yields +5; duplicate/concurrent events/provider link/recovery yield no second grant; client denied grant authority; approved duplicate-identity second account gets 0; backfill leaves historical ledger/balances untouched. Explicitly record residual unrelated-account Sybil risk. |
| Resource budgets/UI | Actor/global concurrency exhaustion bounded; failed attempts still metered; invalid/huge requests cheap-rejected; counters survive instances; bilingual retry-after and low-Credit messages; free preview stays zero Credits; eligible downloads remain free at low balance and do not consume export quota. |
| Retention/release | Sanitized effective lifecycle/soft-delete/versioning/locks/backup inventory; near-expiry generation-bound URL never extends past expiry; expired/missing never regenerates; stale upload cannot resurrect deletion; cleanup outage denies expired access and retries safely; snapshots survive PDF expiry; mocked end-to-end closed-gate download/status/recovery works for the exact intended revisions. |

Run pure Node/SQL/Flutter fixture tests after implementation approval and dependency restoration approval; no live chargeable export or existing personal-test repeat is implied. Record test output, migration diff, counter/ledger invariants and deployed image/source map. Test failures block gate activation.

## I. Exact change anchors

Paths below are relative to `mobile/jobix/`; new objects are **proposed**, not present.

| Phase | Files / SQL / configuration / dashboards |
|---|---|
| P0 export | New additive numbered migration after `202610080017_resume_export_deletion.sql`; latest `jobix_export_create` definition in migration `202610080015_resume_export_local_hardening.sql`, replay in `202610080012_resume_export_foundation.sql`. Preserve `reserve_resume_credits`/settlement from `202610050010_credits_ai_foundation.sql`. Proposed `export_admissions`, global budget/counter records and `jobix_export_preflight`/lease-release RPCs; authoritative active-state constraint. Extend recovery/purge to admissions. Do not edit applied migrations in place. |
| P0 transport/UI | `backend/pdf/gateway.mjs`, `database.mjs`, `document.mjs`, `cleanup.mjs`, `worker.mjs`; `backend/export-gateway/core.mjs`; `supabase/functions/resume-export/index.ts`, `transport.mjs`; `lib/features/resume/resume_export_panel.dart`. Add stable retry-after/admission error contract and bilingual UI; retain bearer ownership checks. |
| P0 signup | New migration replacing grant trigger behavior from `202610030004_core_shell_credits.sql`; Auth-to-public-user trigger in `202610030002_first_vertical_slice.sql`; `credit_ledger`, wallets and proposed `signup_grants` registry. Privileged verified-event integration must be explicitly designed against actual Supabase Auth events; no speculative client grant RPC. Supabase Auth provider/confirmation dashboard reviewed, not silently changed. |
| P0 gates/recovery | `backend/pdf/server.mjs`, `google.mjs`, `ADR-retention-deletion.md`; `export_settings`; `JOBIX_EXPORT_ENABLED`, `JOBIX_EXPORT_DELETION_POLICY_APPROVED`, Flutter `JOBIX_ENABLE_PDF_EXPORT`; `GCP_PROJECT_ID`, worker URL/service audiences and existing DB credential bindings verified without values. Exact Edge config keys to be taken from deployed inventory during approved release, not assumed equivalent to gateway keys. |
| P0 provider evidence | Existing `jobix-dev-export-gateway`, `jobix-dev-export-worker`, private PDF bucket, minute recovery Scheduler. Cloud Run billing/allocation/concurrency/timeout/min/max-instance panels; GCS lifecycle, soft delete, versioning, retention/IAM; Supabase Billing/Usage/Compute/Backups; GCP Billing budgets/spend-cap eligibility. No cloud change authorized by this report. |
| P0 tests | Extend `backend/pdf/test/contracts.test.mjs`, `recovery.test.mjs`, `worker-gates.test.mjs`, gateway/bridge/deletion fixtures; `test/resume_export_test.dart`; SQL RLS/invariant harness `tool/test_rls.sh`. Add multi-session SQL admission/grant tests in approved local fixtures. |
| P1 storage/AI | `export_snapshots`/`export_jobs`, cleanup/purge RPCs in migrations 016/017, `cleanup.mjs`; new migration only after retention decision. `lib/features/builder/ai_allowance.dart`, allowance RPC/table foundation in migration 010; new server inference/admission implementation only after model/cost/semantics approval. Proposed budget keys `AI_MAX_INPUT_TOKENS`, `AI_MAX_OUTPUT_TOKENS`, `AI_TIMEOUT_MS`, `AI_MAX_RETRIES` and actor/global SQL budgets—not current config. |
| P2 | `document.mjs`, immutable template/font manifest and canonicalization/render tests; new versioned schema/bundle only if benchmarked. Region migration requires new resource/config/IAM plan and explicit approval, not just a region variable edit. |

## J. Owner decisions and smallest next task

Approve or revise:
1. Proposed export windows, active-intent definition, accepted-failure counting and preflight reservation lifecycle.
2. Verified-signup eligibility, practical identity/link/recovery/deletion rules, privacy retention and finite grant budget. One bonus per human cannot be guaranteed with current identities.
3. Seven-day availability wording versus asynchronous/recoverable erasure; snapshot/audit retention or storage budget; backup/log obligations. No soft-delete change assumed.
4. Free-traffic, global render/signup/AI budgets, exhaustion behavior and future AI pricing/allowance interaction.
5. Separate release/dependency/test authorization; any load/paid evidence collection remains separately gated.

**Next smallest high-value task:** approve a short beta policy decision sheet covering items 1–4, with unresolved provider fields explicitly marked UNKNOWN. **Benefit:** prevents implementing contradictory Credit, identity or deletion promises and unlocks a narrowly scoped admission migration. **Cost/risk:** no paid calls or provider mutation; decisions can be revised before implementation. **Completion proof:** a dated owner-approved matrix of numbers, counting semantics, retention/recovery promises, identity limitations and budget-exhaustion behavior. No implementation until that approval.

### Evidence and official references

- Repository Architecture V2: `attached_assets/JobiX_Architecture_V2_1790975874316.md`; `README.md`, `PROJECT_STATUS.md`, `docs/AI_HANDOFF.md`, `docs/NEXT_STEPS.md`.
- Dated deployment/aggregate/pricing evidence: `deliverables/jobix-production-readiness-2026-10-09.md`; retention ADR and `backend/pdf/PHASE3_ACCEPTANCE.md`. This report narrows the policy gaps; it does not replace that readiness assessment.
- [Cloud Run pricing](https://cloud.google.com/run/pricing), [locations](https://cloud.google.com/run/docs/locations), [Cloud Storage pricing](https://cloud.google.com/storage/pricing).
- [Supabase pricing](https://supabase.com/pricing), [billing guide](https://supabase.com/docs/guides/platform/billing-on-supabase).
- [Gemini model pricing](https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing). Pricing references inspected October 9, 2026; actual account terms/selected regional SKUs must be confirmed before a binding quote.

**Work performed:** source/document reads and official-pricing research only; this report is the only new deliverable. No application/schema/data/Credit/cloud/gate/dependency/history change, AI inference, export, deployment or personal-account test was performed.
