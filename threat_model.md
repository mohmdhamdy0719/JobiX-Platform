# JobiX threat model

Assessment reference: `deliverables/jobix-production-readiness-2026-10-09.md`. This is a security reference, not an implementation/task tracker.

## ProjectOverview

Native Flutter career/profile/resume app. Supabase Auth and Edge form the user-facing application boundary; a public Cloud Run bridge independently verifies users and invokes a private PDF worker through its attached Google service identity. The worker uses restricted TLS-verified Postgres RPCs and private GCS objects. Development resources are in `mhflow-jobix`; Cloud Run/GCS Doha and Supabase Frankfurt.

Production and staging were not inspected. Debug APK/device success is development evidence, not a signed production release.

## Assets

- Profile/contact/source facts, photos and immutable export snapshots.
- Generated private PDFs and short-lived signed download capabilities.
- Finalized/reserved Credits, ledger, idempotency acknowledgements and job state.
- Active-account/deletion state, leases/fences and upload-flight quiescence.
- Restricted database credential, attached service identities and operator/deployer credentials.
- Finite rendering/preparation/network/storage budget and availability.

## TrustBoundaries

1. Untrusted Flutter/device/session data → Supabase Auth. The client never authoritatively grants Credits, actor identity or export success.
2. User bearer → Edge and public Google bridge. Both verify against the configured Supabase project; public bridge can be called without Edge, so Edge-only controls are bypassable.
3. Bridge identity → private worker. Google IAM permits ingress; application caller/action routing restricts bridge to user commands and Scheduler to recovery.
4. Worker → restricted Postgres functions. Explicit active-account/ownership checks are needed because SECURITY DEFINER functions deliberately run with owner privileges.
5. Canonical source → isolated Chromium/subprocesses. Disable JavaScript/network/service workers and avoid server credential inheritance.
6. Worker → private GCS generation. Matching immutable hashes, fenced completion and durable upload settlement prevent late/ambiguous success.
7. Download authorization → signed URL. It becomes a transferable bearer capability until expiry; application rate limits do not directly cap repeated GCS reads.
8. Account/profile deletion → async storage cleanup. Freeze/invalidate/release, require quiescence and no usable residual data before completion. GCS soft delete is an additional physical-retention decision.
9. Operator/deployer/database-owner boundary. Client isolation does not make privileged administrators unable to alter/read data.

## ScanAnchors

- `mobile/jobix/supabase/functions/resume-export/index.ts`: Auth verification, fail-closed upstream-error distinction, user forwarding.
- `mobile/jobix/supabase/functions/resume-export/transport.mjs`: allowed actions/body bounds/gate semantics shared by bridge and worker.
- `mobile/jobix/backend/export-gateway/core.mjs`, `identity.mjs`, `server.mjs`: independent verification, derived actor, fixed target/audience, metadata identity token and ingress handling.
- `mobile/jobix/backend/pdf/server.mjs`, `google.mjs`: internal identity, route restrictions, object access/signing and upload-error evidence.
- `mobile/jobix/backend/pdf/gateway.mjs`: canonical preparation, replay, owner/status recheck, expiry and signed download.
- `mobile/jobix/backend/pdf/worker.mjs`, `renderer.mjs`, `document.mjs`: leases/fences, renderer isolation, immutable content and structural validity.
- `mobile/jobix/backend/pdf/cleanup.mjs`: retention/deletion/flight quiescence.
- `mobile/jobix/backend/pdf/database.mjs`: restricted runtime role, development endpoint guards and CA-verified TLS pool.
- `mobile/jobix/supabase/migrations/*credits*.sql`, `*resume_export*.sql`: authoritative wallet/ledger/ownership/finalization/recovery/deletion.
- `mobile/jobix/backend/pdf/test/bridge.test.mjs` and adjacent tests: cross-account, inactive/invalid/upstream-outage and internal-path regression cases; local tests are not live deployment proof.
- `mobile/jobix/android/app/build.gradle.kts`: debug release signing gap.
- Worker/Gateway Dockerfiles: Node 20 baseline EOL; supported-runtime assessment needed.

## ThreatCategories

### Spoofing

Invalid tokens/actor injection must fail closed. Preserve independent bridge verification and server-derived identity. Multiple verified accounts remain possible; account control is not unique-human proof. A compromised trusted bridge can impersonate actors downstream and needs runtime hardening.

### Tampering

Clients cannot directly mutate export/Credit tables. Owner locks, version hashes, immutable snapshots, unique keys and fencing defend ordinary command races. Database owners/service-role credentials are outside client RLS protection; application append-only ledger is not cryptographic tamper evidence.

### Repudiation

Durable job/ledger/idempotency state is evidence. Add operational correlation without profile PII or signed URLs. Existing full alert/on-call coverage and privileged-operator audit coverage are unknown.

### InformationDisclosure

Keep Worker private, bucket private, generation-bound short links and active-account/ownership checks. Review inherited project-viewer object access. Do not log bodies, credentials or signed URLs. Logical expiry and account cleanup do not erase already-downloaded phone copies. Soft-deleted cloud generations remain physically retained under the current bucket policy.

### DenialOfService

Free preparation/reads/Auth rejection consume resources without Credits. Aggregate bounds exist but may still be expensive. Instance caps are not absolute spending guarantees. Missing demonstrated global admission/attempt/queue/egress controls, coupled with shared command/render resources and cross-region DB latency, require financial and availability controls.

### ElevationOfPrivilege

Preserve narrow identity/action routing and runtime function grants. No worker recovery/cleanup through public user commands. Existing credential scopes must not be broadened for convenience. Supported images and effective inherited/operator permissions need review.

### FinancialAbuse

Duplicate-account signup, future daily/referral reward farming, repeated refunded render failures and shared signed URLs are separate from duplicate-charge prevention. Enforce verified reward contracts and finite actor/cohort/global work budgets. Never claim unique account grants prevent unlimited multi-account subsidy.

## AssessmentLimits

No exploit, export, load test, credential modification or cloud mutation was performed. Two completed PDFs do not establish production capacity. Deployed/source gate drift, pending live failure/deletion acceptance, supported runtime, physical retention approval, cost admission and production operations remain launch gates.
