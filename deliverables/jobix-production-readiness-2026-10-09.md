# JobiX V2 — Production readiness, security, capacity and cost assessment

Assessment date: 9 October 2026. Read-only development observations: approximately 13:41–13:52 UTC. Repository baseline: `722a65c206aa583971a905da9e4192ccb3e92dee`.

## 1. Executive verdict

**Recommendation: KEEP Architecture V2; MODIFY targeted controls and release operations. Public production launch: NO-GO today. Overall readiness: 49/100.**

The native Flutter → Supabase Auth/Edge → authenticated Google gateway → private PDF worker → restricted Postgres/GCS design is viable. Two completed development exports and the owner-confirmed Samsung M31 download/open demonstrate a functioning development journey. They do not establish production capacity, hostile-traffic economics, operational recovery or production deployment readiness.

This assessment did not change application code, dependencies, cloud resources, IAM, credentials, gates, Credits or production/staging. It did not run exports, load tests or repeat the already-green test suite. Only assessment documents were prepared.

### Transparent scorecard

Scores measure demonstrated launch readiness, not probability of security or a compliance certification. Unknown controls receive no assumed credit. A serious blocker overrides the numerical score.

| Area | Weight | Score | Weighted points | Main reason |
|---|---:|---:|---:|---|
| Security | 25% | 65 | 16.25 | Strong identity/ownership boundaries and restricted runtime; unsupported Node baseline, abuse protection and privileged-access coverage need work |
| Cost control | 20% | 30 | 6.00 | Reservations and instance caps exist; no demonstrated comprehensive attempt/preview/egress/free-grant budgets |
| Reliability | 20% | 55 | 11.00 | Durable job/fencing/idempotency design; deployed/source drift and incomplete live fault/deletion acceptance |
| Scalability | 10% | 40 | 4.00 | Indexed claims and pooling exist; tiny sample, mixed command/render workload and large accumulating snapshots |
| PDF correctness | 10% | 80 | 8.00 | Canonical snapshots, hashes, font checks, isolated Chromium and actual phone success; broader live Arabic/long-document evidence still needed |
| Observability | 7% | 25 | 1.75 | Provider metrics available; no verified operational alert coverage or export-level SLO dashboards |
| Operations/release | 8% | 30 | 2.40 | Private development services work; production configuration, backups/restore, supported images and release signing not proven |
| **Total** | **100%** | | **49.40 → 49** | Confidence: moderate for development configuration; low for production capacity/cost |

### Highest-priority launch blockers

1. **Finish one coherent deployed release.** Edge is v7, while Gateway/Worker still use earlier images. The merged free-download/disabled-gate recovery changes are not established as deployed end to end.
2. **Complete outstanding live recovery/deletion acceptance.** Local tests cannot substitute for timeout/upload ambiguity, stale-worker, deletion-quiescence and no-duplicate-debit evidence in the deployed system.
3. **Approve and implement abuse/cost admission controls before public access.** Credits do not limit free previews, invalid-token traffic, repeated failed/refunded rendering or multiple-account signup farming.
4. **Resolve the actual GCS soft-delete setting against the approved deletion contract.** There is a second seven-day physical recovery period after object deletion. It is not a download entitlement, but is additional retention that must not be silently accepted.
5. **Move the Node 20 image baseline to a supported release through a separately approved, tested change.** No upgrade was performed here.
6. **Prepare an isolated production release and operational safety net:** release signing, production secrets/URLs/resources, backup/restore evidence, transactional email, monitoring and rollback/runbooks.
7. **Budget snapshot growth and measure capacity.** Persistent canonical HTML is approximately ten times the PDF size in this small sample. No automatic snapshot retention period is approved.

### Preserve the successful work

Keep Supabase Auth, server-derived actor identity, application-account checks, ownership RPCs/RLS, private Worker, keyless bridge-to-worker invocation, restricted DB role/TLS, private GCS objects, 2-Credit successful-export pricing, immutable snapshots, reservations, native idempotency, leases/fencing and the current deletion contract. Keep the successful PDFs and verification evidence. Do not replace the ledger, add an AI service or relocate the development database as part of this assessment.

## 2. Evidence and confidence

**VERIFIED** means source/catalog/API evidence or a specifically recorded real-device result. **ESTIMATE** means stated assumptions. **UNKNOWN** means no sufficient evidence; it is not necessarily absent.

Fresh read-only checks used Cloud Run v2 service/IAM GETs, Scheduler GET, GCS bucket/IAM/object metadata, Artifact Registry metadata, Supabase project/functions/secret metadata/Auth settings, a TLS-verified `BEGIN READ ONLY` PostgreSQL catalog/aggregate session, and Cloud Monitoring reads. No resume contents, personal emails, passwords, bearer tokens or signed URLs appear in this report.

Existing local test results were inspected, not rerun. The prior passing suites and phone result remain valid for their original scope, not as a blanket claim about the current deployed combination. Remaining live acceptance work is already tracked separately; this report does not duplicate or complete it.

### Inventory of actual development configuration

| Component | Fresh evidence | Status / interpretation |
|---|---|---|
| Native client | Flutter project; current tested APK is ARM64 debug; owner reports successful download/open on M31 | VERIFIED development journey; production release build not proven |
| Auth/database | Supabase project `lmouxhbjhtqdtiqijcee`, `ACTIVE_HEALTHY`, region `eu-central-1`; Postgres 17.6 | VERIFIED Frankfurt, not colocated with Doha |
| Auth providers | Email and Google enabled; anonymous login disabled; email autoconfirm false; signup enabled | VERIFIED; these are not complete Sybil controls |
| Email settings | SMTP host not configured; email-send limit 2; token-refresh limit 150; verification limit 30 | VERIFIED configuration values; consult provider-defined units/endpoint rules rather than treating them as export limits |
| Edge | `resume-export`, ACTIVE, version 7, `verify_jwt=true` | VERIFIED current deployment |
| Gateway | `jobix-dev-export-gateway-00010-4rp`; 1 vCPU, 256 MiB, concurrency 20, request timeout 60s | VERIFIED; revision max 1 and service max 3 coexist—plan conservatively, do not assume three current-revision instances |
| Gateway identity/public access | `jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com`; service has `allUsers` invoker | VERIFIED intended public authentication bridge; public invocation is not anonymous application authorization |
| Worker | `jobix-dev-pdf-export-00011-tnk`; 2 vCPU, 2 GiB, concurrency 2, timeout 900s; revision/service max 3; request-based CPU allocation | VERIFIED; theoretical up to six render slots, not guaranteed measured throughput |
| Worker IAM | IAM enforcement enabled; invokers are dedicated Gateway and Scheduler service accounts; no public member | VERIFIED resource policy; no change needed |
| Worker/Gateway gates | Both `JOBIX_EXPORT_ENABLED=false`; deletion-policy approval true; DB export setting disabled and approval true | VERIFIED at audit time; preserved |
| Worker database access | Existing Secret Manager version 1 reference; bundled CA; restricted `jobix_export_runtime` | VERIFIED config/catalog; no credential values inspected |
| DB pool | Runtime `max:5`, connection timeout 10s, statement timeout 15s, verified TLS | VERIFIED source; three ordinary Worker instances imply up to 15 runtime pool connections |
| DB capacity | `max_connections=60`; total current database ≈17.44 MB | VERIFIED; includes other consumers, not 60 dedicated export connections |
| Scheduler | Existing job enabled, every minute, UTC, 900s attempt deadline, OIDC Worker audience/identity | VERIFIED; 43,200 ordinary calls per 30-day month before retries |
| GCS | `ME-CENTRAL1`, STANDARD, uniform access; no public binding; public-access prevention inherited | VERIFIED resource policy; explicit enforcement/org inheritance not established |
| GCS expiry | Lifecycle Delete for `exports/*.pdf` at age 7 | VERIFIED; lifecycle execution is asynchronous, not the logical access-control clock |
| GCS soft delete | 604,800 seconds, seven days | VERIFIED extra physical recovery window after deletion; policy decision required |
| Active bucket contents | Two export objects, 279,847 bytes; seven non-export objects, 2,979,413 bytes | VERIFIED aggregate only; source/build objects are not covered by the PDF-prefix lifecycle |
| Registry | Approximately 1.99 GB reported repository size; cleanup dry-run true, no cleanup policies | VERIFIED; old images/layers can accumulate |
| Production/staging | No resources or configuration inspected or changed | UNKNOWN readiness; dev success is not evidence of production isolation or deployment |

**Deployed image digests:** Worker `69fd2947770a4be0e37b778a7ad7d6bf8063474de7febc3d8fd6b9b57e58e5ef`; Gateway `4754a7409e471ecb8aef8ebf41bf3607de55915fd09246e7da697dc4e69d573d`.

### Financial/data observations—not forecasts

The live aggregate contained six accounts, two COMPLETED exports, one FAILED export, no pending/overdue reservations and two settled upload flights. Finalized aggregate balance was 13 Credits, reserved zero. Ledger totals were signup +15, isolated adjustment +2, exports −4: consistent with that aggregate wallet.

The two successful exports averaged 33.14 seconds from creation to completion. This includes queueing and has sample size two: **not** a renderer p95 or throughput benchmark.

Three snapshots contain 4,459,923 raw HTML bytes and 2,976,716 stored HTML-column bytes. Average raw HTML ≈1,486,641 bytes; average stored HTML ≈992,239 bytes. Total snapshot relation including overhead was 3,227,648 bytes. Postgres already compresses this data; projected storage must not assume all raw bytes are uncompressed on disk.

Three-day provider metrics across current and previous revisions showed Gateway 117 2xx / 25 4xx / 14 5xx and Worker 1,204 2xx / 40 4xx / 22 5xx. Billable instance-time totals were approximately 180.61s and 1,378.89s respectively. These include deliberate negative tests, startup experiments and recovery calls, so they do **not** establish customer error rates or steady monthly usage. Current-revision HTTP p95 readings are similarly mixed and must not be presented as PDF-render latency.

## 3. Request path and authority boundaries

1. Flutter obtains a valid Supabase session and submits a frozen command/idempotency key to Edge.
2. Edge independently verifies the bearer through Supabase Auth, then forwards the user bearer to the public Cloud Run Gateway.
3. Gateway independently verifies the bearer with the fixed development Supabase Auth endpoint. It derives the actor from verified identity, not client-supplied account data.
4. Gateway obtains a short-lived Google identity token from its attached service identity for the private Worker audience. Its Worker-scoped invoker permission permits ingress.
5. Worker checks the internal caller and route: Gateway may use `/command`; Scheduler may use `/recover`. User actions cannot invoke worker-only recovery/cleanup.
6. Restricted database RPCs enforce active account/profile, ownership, source versions and job ownership. Credits are reserved/finalized/released server-side.
7. Worker renders the frozen canonical document, verifies structure/content/hash, uploads a private generation and finalizes only after proof. Downloads use short-lived, generation-bound signed URLs after renewed status/ownership checks.

Direct calls to the public Gateway can bypass Edge, but not Gateway authentication. Therefore controls implemented only in Edge are insufficient. Public Auth/profile RPCs are another abuse boundary outside the export proxy.

### What the existing design does well

- Anonymous/invalid tokens fail closed; upstream verification failure is not treated as an authenticated user.
- Authenticated but unauthorized/inactive accounts are distinguished from genuine verification-service outages.
- Client accounts/Credits/render proof are not authoritative.
- Live authenticated roles cannot insert/update/delete wallet, reservation, ledger, export job or snapshot tables. Export tables have RLS enabled and no client-facing owner policy opening them directly.
- Runtime is non-superuser, does not bypass RLS and has no direct SELECT on the examined export/Credit/user tables. Narrow SECURITY DEFINER functions use an empty search path and explicit checks.
- Finalization locks owner/wallet/job; matching fencing and non-expired lease/deadline are required; terminal completion is replay-safe.
- `FOR UPDATE ... SKIP LOCKED`, due/history/owner indexes, unique operation/reservation/idempotency constraints exist.
- Chromium disables JavaScript, blocks service workers/network and does not inherit server credentials. HTML/hash/font/license/PDF/text/page checks are present.
- Signed downloads are free; expiry/missing objects do not regenerate or debit.

### Exact code/config anchors for critical conclusions

| Finding | Evidence anchor | Consequence |
|---|---|---|
| Unsupported Node baseline | `mobile/jobix/backend/pdf/Dockerfile:9` and `backend/export-gateway/Dockerfile:2`, both Node 20.20.0; official Node release page marks v20 EOL | Supported-runtime release is required; no specific exploitable CVE is claimed without a fresh vulnerability assessment |
| Release signing is still debug | `mobile/jobix/android/app/build.gradle.kts:35`, release signing selects debug | Current successful debug APK must not be treated as production release readiness |
| Source/deployed gate drift | Commit `722a65c`; `backend/pdf/server.mjs`, `worker.mjs`, shared `supabase/functions/resume-export/transport.mjs`; current Cloud Run digests above | Edge v7 alone cannot establish free download/recovery under closed gates through older services |
| Existing create limit | Live `public.jobix_export_create`: five jobs per actor in preceding ten minutes; native replay/source owner locking | A useful short-window control, not a daily/monthly/global cost budget |
| Expensive work before create admission | `backend/pdf/gateway.mjs:42–43,59–68`: source/canonical preparation precedes native create/reservation/rate check | Low-balance and repeated rejected requests can still consume preparation resources |
| Existing preparation bounds | `backend/pdf/document.mjs:32–39,57–65`: 8,000,000-byte subprocess output, 30s preparation signal, visible source text ≤200,000 UTF-8 bytes | Bounded, but not necessarily economical; the source/facts pass occurs before aggregate-text rejection |
| Existing worker bounds | `backend/pdf/worker.mjs:11–22,48–66`; SQL lifecycle claim/finish/recover | Two local slots; rendering up to 600s; validation bounded; max 20 pages; max three attempts and durable deadline |
| Signup funding | `202610030004_core_shell_credits.sql:26–55`; live unique signup index/trigger | +5 once per account; no demonstrated one-human/multiple-account barrier |
| Snapshot accumulation | Live snapshot aggregate and `jobix_export_create` immutable INSERT | ≈0.992 MB stored HTML/export persists beyond PDF expiry |
| GCS retained deleted data | Bucket softDeletePolicy 604800; official soft-delete documentation | Deletion removes usable objects but does not immediately physically erase soft-deleted generations |
| Broad internal bucket readership | Bucket IAM includes legacy object-reader for project viewers and object-owner for project editors/owners | Not publicly exposed, but project membership may confer resume access; review inherited/admin scope |

Ledger protection is application append-only via privileges/uniqueness, not tamper-proof against database owners or privileged service-role credentials. RLS is not forced for owners, and SECURITY DEFINER checks are intentional. Account-deletion cascades must be reviewed under the existing deletion policy; do not invent a separate audit-data retention exception.

## 4. Threat and financial-risk matrix

P0 = launch blocker; P1 = needed for broader beta/public growth; P2 = evidence-driven later improvement.

| Threat | Current protection | Residual gap / unknown | Layer and financial risk | Proposed mitigation |
|---|---|---|---|---|
| Forged JWT, anonymous request | Fixed Auth verification, fail-closed mapping | Public Gateway/Auth calls still incur some cost | Auth/ingress; request flood without Credits | P0 cheap body/time limits and layered admission; P1 edge/network abuse controls verified not bypassable |
| Client-supplied actor or another user's profile/job | Derived actor; authoritative ownership/account RPCs; negative tests | Remaining deployed acceptance must cover complete current release | Gateway/DB; privacy breach if checks regress | P0 two-account tests for document/status/history/download/create/again, with gates safely controlled |
| Client balance/price/finalization forgery | Client write ACL denied; server reservations/proof | Privileged credential theft remains a different threat | DB/runtime; fraudulent debit/grant | Keep ACLs and tests; P1 privileged-access/audit coverage |
| Concurrent double spend/replay | Owner/wallet locks, unique keys, request hashes, terminal replay | Load/failure coverage incomplete | DB; duplicate charge or overspend | P0 concurrent same/different key acceptance with native reconciliation |
| Retry after committed timeout | Durable job/acknowledgement; idempotent reservation/finalize | Live post-commit response-loss proof still pending | Worker/DB; repeated render or charge | P0 fault acceptance; same intent keeps key, Export Again uses a new key |
| Renderer/upload failure | Retry/fencing/settlement; pending release; max attempts | Refunds make Credits reusable for repeated deliberate failures | Renderer; costly work without revenue | P0 rate failed intents and render attempts independently; global cost circuit |
| Huge source/HTML | Text/output/time/page bounds; safe canonical rendering | 200k text and 600s rendering can be expensive; page limit is checked after rendering | Preparation/renderer; CPU/RAM exhaustion | P0 measured smaller beta envelope, early source admission; no unapproved permanent product limit |
| SSRF/script injection | Canonical escaping; JS off; all browser network blocked; isolated environment | Fresh browser/base-image vulnerability status unknown | Renderer; credential/remote-access impact | P0 supported image plus supply-chain/security verification; preserve network block |
| Free preview/status flood | Bodies/timeouts and instance caps | No demonstrated comprehensive per-actor/IP/global preparation/read budget | Worker/Auth/DB/network; no Credit debit required | P0 controls in Gateway and DB, not Edge alone; cache only safe version-bound non-authoritative data |
| Multiple verified signup accounts | Email confirmation; Google identity; unique signup per account | These prove account control, not one person; no verified global free-grant budget | Account/Credits; two initial free exports per new account | P0 invite-only beta and global rewarded-account budget; P1 approved anti-farming signals |
| Daily reward fabrication/replay | V2 requires verified SSV and Cairo-date authority | No operational daily issuer found; no live daily entries | Future reward service; recurring free spending | Do not enable until signature/replay/date/global-grant controls pass |
| Referral farming/collusion | No operational referral issuer found | No approved operational economics demonstrated | Future incentives; self-referral/account loops | Keep disabled; qualification, unique referral and grant budgets require product approval |
| Signed URL sharing/replay | Private bucket; short TTL; generation/expiry binding | URL is a bearer capability until expiry; direct GCS reads bypass app request quotas | GCS; repeated download egress | P1 short TTL, issuance limits and bytes monitoring; proxy only if measured exposure requires it |
| Expired download | Logical expiry/missing rejection, lifecycle cleanup | Lifecycle delay and soft delete still incur storage | DB/GCS; no charge allowed | Preserve no regeneration; monitor expired live objects and resolve soft-delete decision |
| Deletion with stale workers | Freeze, lease invalidation, release, upload-flight quiescence, purge verification | Remaining live races and physical soft-delete policy need acceptance | DB/worker/GCS; data survives deletion | P0 deterministic live deletion acceptance with isolated fixtures |
| Leaked runtime credentials | Gateway has no DB secret; Worker restricted role; native Google runtime identity | Full project/folder privileged membership and operator key lifecycle not freshly established | IAM/secrets; cross-account administrative reach | P1 targeted privileged-access review; no new keys or broad grants |
| Public-worker/command escalation | Worker private; caller/route separation | A compromised trusted Gateway can forge actor requests to Worker | Trusted service boundary; all actors potentially exposed | P0 retain narrow route/actions; P1 runtime hardening/audit; not a client forgery vulnerability |
| Queue burst/recovery stall | Durable deadline, due indexes, local slots, Scheduler | No demonstrated global queue admission; minute polling and mixed commands/rendering | Queue/DB; expired reservations and failed user experience | P0 queue limit before reserve, queue-age alarm and recovery-through-disabled-gate acceptance |

**No honest guarantee of “unlimited free Credits cannot be farmed” is possible merely from unique email/account checks.** Server-authoritative grants stop client forgery for a given account. Cost-bounded cohorts and global work/grant admission are needed even when an attacker can create many accounts.

## 5. Concrete layered controls — proposals, not new policy

Existing: create five/10min/actor; 32KB private request body; preparation/source/output bounds above; three worker attempts; 20-page cap; approximately 30-minute reservation/job deadline; five-minute leases, one-minute heartbeat; two local slots; Worker maximum three ordinary instances. No additional limit below was implemented or approved by this report.

Suggested **small invite-only beta starting values**, subject to measured false positives and owner approval:

| Layer | Proposed starting value | Semantics / rationale |
|---|---|---|
| New logical exports per actor | 1/minute, 3/hour, 2/day, 10/month; at most one active intent/profile | Affects new intents, not replay of an accepted key; reject before reserve/expensive preparation |
| Failed/retry work | Max two automatic attempts per logical job for beta; count attempts globally and per actor, including released reservations | Three attempts currently exists; lowering it is an explicit policy/config approval, not a test fix |
| Preparation/preview | 10/minute, 60/hour, 200/day per actor; version-bound cache; invalid-token/IP envelope | Protect free work; do not cache ownership/account status as an authority |
| Status/history | 30/minute/actor, history page max 25; exponential polling backoff from existing cadence | Read availability should remain when create is disabled |
| Signed URL issuance | 10/hour, 30/day/actor; initial TTL proposal 60–120s versus current up to 300s | Downloads remain zero Credits; direct URL byte traffic still requires monitoring |
| Rendering envelope | Trial full-job service budget ≤120s; render target ≤60s; beta text envelope 50k visible bytes; keep existing 20-page safety cap | Measure legitimate Arabic/long resumes before adopting; preserve explicit failure and reservation release |
| Global ordinary active renders | Initially 2–4, max ordinary Worker instances 2–3; do not raise concurrency without RSS/CPU tests | Keep DB connections/headroom; avoid making two Chromium jobs compete blindly |
| Queue admission | Max 50 accepted pending jobs; estimated wait <5min; reject new work before reserving when full | No silent acceptance followed by predictable deadline expiry |
| Global accepted intents | 100/day and 1,500/month initial ceiling | A planning ceiling, not a capacity claim; separate attempt budget may become binding first |
| Global render-cost budget | Proposed $3/day and $30/month incremental rendering/preparation admission budget | Use conservative per-attempt resource reservation and reconcile measurements; not the user Credit ledger |
| Signup freebies | Keep approved +5 per account; begin invite-only, e.g. 20 newly rewarded accounts/day and a finite cohort grant budget | Budget exhaustion behavior needs approval; do not silently give a different signup amount |
| Daily/referrals | Remain disabled until authoritative verification and reward-specific budgets approved | V2 daily +2 is approved conceptually, not currently operational |
| Provider backstop | Evaluate monthly Cloud Run spend-cap budget, e.g. $50 gross estimated usage, alongside 50/80/90% alerts | Actual amount requires regional pricing and other-service inventory; not an application-only throttle |

Admission must be race-safe in the authoritative backend. Avoid an unlocked `COUNT` followed by enqueue, client clocks or per-instance-only counters. Store the accepted intent and its reservation atomically after ownership/version/capacity checks. Replays do not reserve a second time. Do not merge operational dollar budgets into the approved user Credit ledger.

**Provider-budget nuance:** current official documentation lists Cloud Run as eligible for spend-cap budgets. They apply to one project + one eligible service, monthly, using gross estimated costs, excluding discounts/credits. An alerts-only budget does not stop spending. Eligibility of this billing account and an existing cap are UNKNOWN. A Cloud Run cap can pause both Gateway and Worker, including free downloads/recovery—not just new renders. Use it as a last-resort backstop with an explicit pending-reservation recovery runbook, not the normal product gate.

Automatic application throttling proposals: stop accepting new exports if oldest queued age >5min, queue ≥50, Worker OOM, render p95 >60s for a sustained window, terminal failure rate >5% across ≥20 jobs, cost admission ≥daily/monthly budget, or unexplained wallet/ledger mismatch. Keep status, eligible downloads and safe reconciliation available. Pause all financial mutations and investigate any balance invariant or duplicate-debit anomaly immediately.

## 6. Capacity estimates—not load-test claims

Assume light 1, normal 2 and heavy 10 exports/MAU/month; normal renderer service time 30s; six ordinary theoretical render slots; normal peak = 10% of a day's exports in five minutes. Mixed API calls and CPU contention can reduce effective capacity.

| MAU | Light / normal / heavy exports monthly | Normal daily | Normal peak concurrent demand | 5% of MAU exporting simultaneously: optimistic drain |
|---:|---:|---:|---:|---:|
| 500 | 500 / 1,000 / 5,000 | 33 | 0.33 | 25 jobs, ≈2.5min |
| 1,000 | 1,000 / 2,000 / 10,000 | 67 | 0.67 | 50 jobs, ≈4.5min |
| 5,000 | 5,000 / 10,000 / 50,000 | 333 | 3.33 | 250 jobs, ≈21min |
| 10,000 | 10,000 / 20,000 / 100,000 | 667 | 6.67 | 500 jobs, ≈42min |

Formula: concurrent demand = arrival rate × mean service time; burst drain = `ceil(jobs/6) × 30s`, excluding dispatch/cold-start/DB/command overhead. At 60s instead of 30s, those drain times double. At 10,000 normal MAU the illustrative peak already exceeds six slots; a synchronized burst can exceed the current job deadline. A monthly average cannot prove burst capacity.

**500–1,000 MAU:** likely configuration/admission/observability work, not architectural replacement, provided measured latency and failure rates pass. **5,000 MAU:** snapshot storage, pooled connections, command/render sharing and bursts become important. **10,000 MAU:** current caps are not demonstrated adequate; measured scaling, queue admission and possibly separating heavy dispatch from read/preparation traffic may be needed. Increasing instances alone multiplies pool connections and spend.

### Safe staged load plan requiring separate approval

| Stage | Work / resource ceiling | Acceptance |
|---|---|---|
| Local/disposable | 10k logical replay/ownership operations with mocked renderer; zero live Credits | No duplicate reserve/debit; isolation and accounting invariants hold |
| Development baseline | One existing fictional source, ≤10 specifically funded exports; peak two renders; proposed gross test ceiling $2 | Collect CPU/RSS/DB/queue timings; successful output, no orphaned pending state |
| Small beta burst | ≤50 separately approved jobs, peak four renders, proposed $5 ceiling | Warm render p95 ≤60s, end-to-end p95 ≤120s, no OOM, no unexpected 5xx/financial mismatch |
| Capacity qualification | 500/1k/5k/10k MAU **synthetic request distributions**, not real signup farming; staged 1/2/4/6 concurrency | API p95 ≤2s excluding rendering; queue <5min; measured connection usage <70% of 60; documented degradation/429 behavior |

Pause the test on any unexpected debit, stale-worker success, inaccessible completed PDF, cross-account success, OOM or agreed gross spend ceiling. Full fault/timeout tests are distinct from ordinary load and need their own bounded fixtures. No load stage was executed here.

## 7. Pricing evidence and monthly cost model

USD, before taxes, contractual discounts and credits. Official pages were fetched on 9 October 2026. Pricing is mutable; obtain a region-selected quote before setting enforceable dollar limits.

### Official current rates and missing prices

| Item | Official evidence | Application to this project |
|---|---|---|
| Cloud Run request-based default Iowa | CPU $0.000024/vCPU-s; memory $0.0000025/GiB-s; requests $0.40/million | VERIFIED default-table reference, **not verified Doha rates** |
| Cloud Run region/free tier | Doha is Tier 2; free tier based on us-central1 active pricing: 180k vCPU-s, 360k GiB-s, 2m requests | Billing-account shared; do not subtract raw Tier 1 allowances blindly from another region or assume unused |
| Doha CPU/RAM/request SKU | Region-selected price not returned by flattened default table; catalog read returned HTTP 403 | **UNKNOWN**; do not present a made-up Tier 2 multiplier as official |
| GCS STANDARD storage | Default Iowa $0.000027397/GiB-hour ≈$0.02/GiB-month at 730h | Doha storage price **UNKNOWN**, use `P_storage_Doha` |
| GCS regional operations | Flat namespace STANDARD Class A $0.005/1,000; Class B $0.0004/1,000 | VERIFIED published regional-operation table; operation mix still estimated |
| GCS internet transfer | Worldwide/Egypt-relevant initial band $0.12/GiB; destination exceptions/bands apply | VERIFIED published table; count repeated signed downloads |
| GCS free storage | Region-restricted free storage program must not be presumed for Doha | No assumed Doha storage allowance |
| Cloud Run internet transfer | Provider network pricing applies; actual Doha→Frankfurt/user mix not retrieved | **UNKNOWN** additional outbound cost |
| Scheduler | First three jobs/billing account free; otherwise $0.10/job/31 days | One known job; executions themselves not Scheduler-priced, but trigger Run/DB work |
| Supabase Pro | $25/org/month; $10 compute credits cover one Micro; 8GB DB disk/project | Proposed production baseline, **current actual subscription/tier UNKNOWN** |
| Supabase additional Micro projects | $10/project/month before shared $10 credit | Two Micro projects in one Pro org ≈$35; three ≈$45 before usage |
| Supabase usage | 100k MAU then $0.00325/MAU; 250GB egress then $0.09/GB; 2m Edge invocations then $2/million; disk then $0.125/GB | Organization/project quota semantics apply; ordinary app traffic matters |
| Cloud Logging | First 50GiB/project/month; $0.50/GiB ingestion/storage including 30 days | Actual volume/retention/alerts not established; do not log PII |
| Artifact Registry | First 0.5GiB/billing account free; ≈$0.10/GiB-month | Current reported ≈1.85GiB gives ≈$0.14 if its allowance is available, otherwise ≈$0.19 |
| Cloud Build default e2-standard-2 | $0.006/min; 2,500 promotional free minutes/billing account/month | Release frequency/machine/regional pricing must be confirmed; not a per-export charge |
| Secret Manager/monitoring/network/SMTP | Small but nonzero possible costs | Actual invoice/usage/plan UNKNOWN; not silently excluded from a final quote |

### Formula for the actual regional bill

`Monthly = fixed platform/compute + CPU_seconds × P_cpu_Doha + GiB_seconds × P_memory_Doha + requests × P_request_Doha + GCS_GiB_month × P_storage_Doha + GCS operations + signed_download_GiB × P_GCS_egress + Cloud_Run_outbound_GiB × P_Run_network + Supabase overages + logs + retained images + builds + other services − applicable unused credits.`

For each attempted job: Worker CPU seconds = `2 × runtime`; RAM seconds = `2 × runtime`. Include failed/retried work, not just successful PDFs. For concurrent requests, allocation is shared; the conservative tables below do not assume a perfect concurrency discount. Each additional minimum Worker instance left continuously active would materially change the model; none is evidenced configured now.

### Numerical reference scenarios—not verified Doha invoice predictions

The table uses the official **Iowa reference** Run/storage prices solely to make resource sensitivity visible. It assumes one Pro/Micro production project $25, registry $0.14, one-minute recovery calls at 1 billed second each, no free-credit deductions, and the following export-path assumptions:

| Scenario | Worker time/attempt | Attempts/offered job | Gateway calls/job and active seconds/call | PDF size / downloads |
|---|---:|---:|---|---|
| Low | 10s | 1 | 8 × 0.2s | 0.15MiB / 1 |
| Expected | 30s | 1.05 | 22 × 0.5s | 0.30MiB / 2 |
| High | 120s | 3 | 60 × 1s | 1MiB / 5 |

Soft-delete is included as an estimated 14 days of billed PDF residence—seven active plus seven soft-deleted—assuming timely lifecycle deletion and steady arrivals. This is a **cost observation, not approval of an extra retention policy**.

| PDFs/offered logical jobs monthly | Low reference subtotal | Expected reference subtotal | High reference subtotal |
|---:|---:|---:|---:|
| 500 | $27.75 | $28.46 | $38.04 |
| 1,000 | $28.05 | $29.48 | $48.63 |
| 5,000 | $30.44 | $37.59 | $133.37 |
| 10,000 | $33.43 | $47.74 | $239.30 |

These are **export-path subtotals**, not complete production bills. Add regional price differences, preparation/preview traffic not represented by those calls, outbound Run transfer, retained snapshot disk, regular profile/auth traffic, additional dev/staging compute, email, builds and logs. High includes failed work; “10,000 successful PDFs” with additional failures can cost more.

Expected reference coefficients before credits: Worker ≈$0.001670/job; Gateway ≈$0.000271/job plus request charges; two 0.30MiB GCS downloads ≈$0.000070/job. Recovery ≈$2.31/month gross at the stated 1s assumption. The two observed exports cannot calibrate these coefficients reliably.

Free Run credits may lower the compute line substantially at small volumes, but unused billing-account credits and actual regional SKUs are UNKNOWN. Do not model every cloud component as free indefinitely. The Pro subscription remains even if PDF compute falls within credits.

### Whole-app traffic and persistent data sensitivity

Canonical HTML is a large response, not only a storage concern. At 20 preview preparations/MAU/month, roughly 1.487MB each:

| MAU | Preview responses/month | Raw response volume, before transport compression | New stored snapshot HTML/month at normal 2 exports/MAU |
|---:|---:|---:|---:|
| 500 | 10,000 | 14.87GB | 0.992GB |
| 1,000 | 20,000 | 29.73GB | 1.984GB |
| 5,000 | 100,000 | 148.66GB | 9.922GB |
| 10,000 | 200,000 | 297.33GB | 19.845GB |

Preview assumptions are not measured actual user behavior. Do not double-count a preview already included in an export-path call model. GCP output to Frankfurt and Supabase output to the phone are separate network legs; intercloud transfer is not same-region free traffic. Compression/cache/version reuse can change volumes. At 10k MAU this alone approaches/exceeds Supabase's 250GB included egress before other app traffic.

Persistent snapshot HTML per month at 500 / 1k / 5k / 10k exports is approximately 0.496 / 0.992 / 4.961 / 9.922GB using the measured stored-column mean. Raw HTML growth is about 1.5 times that; indexes, source JSON, photos, WAL/backups and future document variation add overhead. At 10k exports/month, 12 months would add roughly 119GB stored HTML alone under unchanged behavior. PDF expiry does **not** authorize deletion of these snapshots.

A current Free project, **if that is the actual plan**, could reach its 500MB database allowance after only roughly 500 similarly sized snapshots, before other data. A Pro project's included 8GB is not indefinitely adequate. Inspect paid subscription/disk provisioning rather than infer a plan from `max_connections`.

No factual per-MAU revenue forecast is possible without payment/reward revenue data. Light/normal/heavy user exports map to the capacity table; cost depends on previews, failures and accumulated history as well as PDFs.

## 8. Credit/free-reward unit economics

Current operational rules: signup +5 once/account; a new successful PDF −2; existing eligible download zero; unsuccessful jobs release pending Credits rather than permanently debit. The app presently demonstrates no recurring daily/referral Credit issuer or revenue-producing purchase flow.

V2 explicitly approves **verified Daily Reward +2**, completed by verified AdMob SSV and a server Cairo date. That is not the same as the AI allowance of three requests/day, and neither should be mistaken for an operational daily Credit grant.

| Policy scenario | First-month grant pool | Maximum PDFs if all Credits spent on exports | Status |
|---|---:|---:|---|
| Current signup-only | 5 | 2 | Implemented |
| V2 verified daily +2, every day for 30 days | 65 | 32; subsequently 30/month before other spending | Approved concept, not enabled; economics/abuse verification needed |
| Smaller signup, e.g. +2 only | 2 | 1 | Alternative requiring owner approval; not recommended as an unapproved change |
| Capped daily campaign, e.g. max six rewarded days/month | 17 | 8 | Alternative requiring owner approval; alters current planned availability |
| Referral grant | Not specified by operational evidence | UNKNOWN | Do not invent or enable |

**Recommendation for initial beta:** retain +5 signup and no newly enabled rewards/referrals; bound the invited/rewarded cohort and aggregate rendering/attempt spend. Observe cost per successful PDF, cost per failed attempt and whole-user preparation traffic first. Then evaluate V2's +2 verified daily reward against actual AdMob revenue and abuse, without changing export pricing or the ledger.

Let `c` = all-in incremental cost per successful PDF including failure amplification; `q` = operational cost/preview/read traffic; `r` = verified net reward revenue/user/month. Signup subsidy/user ≈`2c + q`. Fully claimed daily +2 creates ≈`30c + q` recurring monthly liability. Reward revenue must exceed that liability plus fixed-cost allocation/support/risk reserve; geography-specific ad CPM is **UNKNOWN**, not guaranteed.

Refund safety does not make repeated failures financially free to the business. Quotas must count attempts even when the user's reservation is released. Saved Credits can also accumulate spending demand for later bursts. No Credit balance cap, expiry or new formula is adopted in this assessment.

## 9. Ordered cost optimizations

| Order | Proposal | Expected impact | Risk / approval |
|---:|---|---|---|
| 1 | Admission limits for free preparation and render attempts; bounded cohorts | Highest protection against unmonetized traffic | Medium; explicit product/abuse limit approval |
| 2 | Consolidate/reuse version-bound canonical preparation and reduce unnecessary polling | Lower CPU, intercloud bytes and Auth/DB traffic | Low–medium; never reuse stale authorization or financial state |
| 3 | Deduplicate immutable font/template assets or store compressed immutable representations with verified reconstruction | Highest persistent snapshot/storage reduction | Medium–high; approved immutable bytes/render parity and deletion integration must be preserved |
| 4 | Measure single/two-render RSS/CPU; tune slots/instances and right-size only after benchmarks | Moderate compute efficiency | Medium; do not raise concurrency and trigger OOM |
| 5 | Registry/source archive cleanup policy after release evidence preservation | Small direct cost, simpler operations | Low–medium; preserve rollback images and successful build artifacts |
| 6 | Reduce needless recovery work using measured query/cleanup batching | Small steady cost; DB load relief | Medium; must not delay reservation release or deletion |
| 7 | Review GCS soft delete / inherited viewer access | Retention/security clarity; small PDF storage savings now | Owner/admin decision; no silent policy or IAM change |
| 8 | Production regional placement based on measured user/DB latency | Potential latency/network reduction | High; a separate production choice, not moving current dev data |

Do not switch to instance-based billing, keep permanent warm Workers, replace Supabase, introduce a queue product, or split services merely for speculative savings. First demonstrate the current bottleneck and compare complete costs. A dispatch/read split is a possible later targeted improvement, not a rebuild recommendation.

## 10. Metrics, alerts and runbooks

Use opaque operational identifiers only in restricted logs; no personal profile text, raw email/phone, tokens, credentials or complete signed URLs. Aggregated dimensions should be low-cardinality: action, stage, result code, template/language version, revision and environment.

| Signal | Proposed alert / action |
|---|---|
| API and end-to-end export latency | Read/ACK p95 >2s; render p95 >60s; job p95 >120s sustained over meaningful samples |
| Queue depth/oldest age | ≥50 or oldest >5min: stop new admission, retain reads/recovery |
| Worker health | OOM or repeated validation/renderer failures: pause new work, reconcile flights/reservations |
| Reservation state | Any deadline-expired pending reservation after two recovery cycles: page and native read-only reconciliation |
| Financial invariants | Negative/over-reserved wallet, debit without completed proof, duplicate debit: immediate financial-mutation stop |
| Retry/failure amplification | >5% terminal failures over ≥20 jobs or attempts/success >1.2: investigate stage and resource limits |
| Auth/ownership abuse | Sustained invalid-token/cross-account attempts and new-account grant velocity: throttle/investigate without revealing existence |
| Deletion | Non-quiescent upload flight, late object, residual snapshot or overdue purge: block completion and investigate |
| Storage | Expired live objects, snapshot growth vs budget, unused image/source accumulation |
| Cost | Daily/monthly admission budget; 50/80/90% provider alerts; Cloud Run spend-cap status if separately configured |

Runbooks must cover: invalid/upstream Auth outage; canonical/render failure; ambiguous upload; post-commit response loss; Scheduler/recovery failure; expired signed object; deletion quiescence; wallet invariant; cost/abuse surge; and rollback. For each: stop only appropriate new mutations, inspect native durable state before retry/refund, retain keys/fences, avoid a second debit, and preserve safe reads. A provider-wide Run pause needs manual/independent authorized recovery because the paused Worker cannot release reservations itself.

Provider metrics are available, but actual alert policies, log exclusions, on-call ownership, cost export and tested runbooks are UNKNOWN. Current `/ready` startup success is not a continuous real-user-path or recovery correctness test.

## 11. Prioritized backlog and release gates

Effort estimates assume one experienced engineer and no administrative delays. They are not task authorizations.

| Priority | Minimal scope | Effort | Benefit / risk | Required before |
|---|---|---|---|---|
| P0 | Reconcile source/deployed gate behavior and one pinned release manifest | 0.5–1 day | Restores consistent free-download/recovery contract; deployment approval needed | Wider beta |
| P0 | Complete already-tracked live replay/failure/deletion safeguards | 1–3 days | Financial/data integrity; controlled fixtures/approval required | Wider beta |
| P0 | Supported Node baseline + scoped dependency/image security verification | 1–2 days | Removes unsupported runtime; compatibility regression risk | Public launch |
| P0 | Authoritative preparation/attempt/queue/cost admission and finite reward cohort | 2–4 days | Prevents most predictable unbounded subsidy/compute exposure | Public access |
| P0 | Resolve soft-delete physical retention decision; verify deletion semantics | 0.5–1 day + admin | Avoids silent extra retention; irreversible-policy implications | Public launch |
| P0 | Production isolation, signed release, SMTP and backup/restore/rollback evidence | 2–4 days + admin | Operationally viable launch; no current dev changes | Public launch |
| P0 | Minimal financial/queue/recovery/cost alerts and named runbooks | 1–2 days | Finds silent failure promptly | Wider beta |
| P1 | Snapshot/preparation byte optimization with reconstruction/parity tests | 2–4 days | Controls persistent DB/transfer growth; immutable-contract risk | 5k MAU or earlier storage threshold |
| P1 | Staged concurrency/load qualification and pool/instance tuning | 1–3 days | Evidence-based capacity, avoids DB/render saturation | Expansion beyond measured cohort |
| P1 | Privileged/inherited IAM review, signed-download byte monitoring | 0.5–2 days | Limits insider/URL-abuse exposure | Broad public growth |
| P1 | Daily SSV/referral business and abuse verification before enablement | 2–4 days when chosen | Sustainable rewards; new product scope | Any reward rollout |
| P2 | Separate heavy dispatch/preparation from read path if measurements justify | 3–5 days | Reduces contention; added service/ops overhead | Only demonstrated bottleneck |
| P2 | Regional architecture change/authenticated download proxy | Separate design | Potential latency/egress control; significant migration/availability risk | Only demonstrated need |

### Pass/fail/unknown launch checklist

| Requirement | Status now |
|---|---|
| Real native authenticated PDF download/open | **PASS**, development M31 owner-confirmed |
| Server authority over actor, ownership and Credit mutation | **PASS** for inspected source/catalog and recorded security checks |
| Worker not public; keyless runtime bridge identity | **PASS**, current service IAM/config |
| Exactly one successful export debit; pending reservations currently reconciled | **PASS** for tiny observed sample, not global capacity proof |
| Current deployed closed-gate free download/recovery semantics | **NOT VERIFIED / release drift** |
| Live ambiguous-upload/post-commit/deletion race acceptance | **STILL UNVERIFIED** for all required cases |
| Supported server runtime | **FAIL**, Node 20 baseline EOL |
| Additional physical retention explicitly resolved | **FAIL as an approval gate**, current soft delete is extra |
| Broad cost/abuse admission demonstrated | **NOT VERIFIED**, existing five/10min is insufficient alone |
| Production release signing/environment/backup restore/SMTP | **NOT READY / UNKNOWN**, debug signing and no configured SMTP are verified gaps |
| 5k/10k MAU burst/load capacity | **UNKNOWN**, no load qualification |
| Regional cost quote and actual subscription/billing controls | **UNKNOWN** |
| Operational alerts/runbooks tested | **UNKNOWN** |

### Rollout recommendation

1. **Internal development:** preserve gates/known successful PDFs; resolve coherent-release and remaining acceptance evidence under existing explicit approvals.
2. **Invite-only beta:** 25–100 invited users, finite grant/render budgets and named operator; only after P0 beta gates. Observe at least a meaningful multi-day sample before increasing cohort.
3. **Broader beta:** increase to 500/1k only after measured latency, queue, accounting, privacy and cost acceptance.
4. **Public:** isolated production setup, supported runtime, policy decisions, budget/abuse controls, tested recovery and signed release. Qualify 5k/10k separately rather than claiming those counts from two PDFs.

**KEEP:** core V2 services, contracts and successful implementation. **MODIFY:** admission, data efficiency, release consistency and operations. **REARCHITECT:** not justified now. Targeted workload separation or regional changes become justified only if measurements show the current arrangement cannot meet latency/cost targets after lower-risk improvements.

## 12. Unknowns and smallest safe resolution checks

| Unknown | Exact next safe evidence |
|---|---|
| Doha CPU/RAM/storage/Run-network unit prices | Region-selected official calculator/SKU quote, or authorized read-only Catalog lookup; existing lookup was 403—do not broaden credentials just to guess |
| Supabase current plan/compute/disk/add-ons | Owner-provided sanitized billing/usage page with plan/tier, allocated disk, org projects and quota use; no payment data or credentials |
| Existing budgets/cap eligibility/account credits | Sanitized billing budget/credit inventory; confirm first-party eligibility and scope of any Run spend cap |
| Source/deployment parity | Existing build provenance/manifest versus commit and each deployed transport/Worker/Gateway version; authorized release then closed-gate contract tests |
| Actual renderer latency/RSS/pool pressure | Existing isolated test metrics where available; otherwise one separately approved bounded load plan |
| Complete live failure/deletion safeguards | Finish already-tracked acceptance using deterministic fixtures, without repeating successful personal export |
| Production isolation/secrets/backup restore | Explicit production configuration review and disposable restore evidence; no inference from dev |
| CAPTCHA/account-farming/privileged access | Read-only effective Auth hook/CAPTCHA settings and inherited principal IAM review; no grants needed for assumptions |
| Alert/on-call/log retention | Read-only Monitoring alert policy/log bucket/sink inventory and operator-approved runbook exercise |
| Long/Arabic real-device correctness | Existing evidence first; then approved representative source/layout/device tests, not a rebuilt happy-path export |

No new architecture decision is requested by this report. Before implementation, the owner should approve the P0 scope, operational limit policy and soft-delete resolution. Existing approved Credit, retention and deletion rules remain unchanged.

## 13. Official sources

- [Cloud Run pricing](https://cloud.google.com/run/pricing) — published tables/default selection and free-tier basis.
- [Cloud Run locations](https://cloud.google.com/run/docs/locations) — Doha Tier 2.
- [Cloud Run maximum instances](https://cloud.google.com/run/docs/configuring/max-instances) — caps can briefly be exceeded; not an absolute monetary guarantee.
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing) — regional operations, transfer and default storage table.
- [Cloud Storage soft delete](https://cloud.google.com/storage/docs/soft-delete) — additional recovery retention and inability to permanently delete during it.
- [Supabase pricing](https://supabase.com/pricing.md) and [billing](https://supabase.com/docs/guides/platform/billing-on-supabase) — plan, compute credits and quotas.
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) — actual endpoint semantics and configured-rate access.
- [Cloud Scheduler pricing](https://cloud.google.com/scheduler/pricing).
- [Cloud Observability pricing](https://cloud.google.com/stackdriver/pricing).
- [Artifact Registry pricing](https://cloud.google.com/artifact-registry/pricing).
- [Cloud Build pricing](https://cloud.google.com/build/pricing).
- [Budgets](https://cloud.google.com/billing/docs/how-to/budgets) and [spend-cap budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps) — ordinary alerts versus supported monthly service caps.
- [Node.js release status](https://nodejs.org/en/about/previous-releases) — v20 EOL as of retrieval.

Scope complete: assessment and recommendations only. No deployment, gate enablement, funding, export, policy implementation or dependency upgrade was performed.
