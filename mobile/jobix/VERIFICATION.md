# Jobix verification evidence

## Real-user ingress trace — local read-only implementation; cloud proposal pending

Existing Flutter `_call` invokes `resume-export` using the signed-in Supabase
client and action/command body. The Edge source verifies the user through
Supabase Auth and forwards the original bearer/body. A private Cloud Run
Gateway instead requires a Google ID token at its IAM frontend; the Supabase
user token is not that credential, and Edge has no approved native Google
identity/WIF issuer. This is an authorization blocker, not a DNS/network or
startup failure. Do not put service-account keys into Edge.

Development Management API function inventory returned HTTP 200 and no
`resume-export` function. Edge has not been deployed. Both local Edge and
deployed Gateway gates also blocked every action while exports were off.
Configured test-user email/password environment entries A/B are absent.

Prepared minimal local read-only routing: verify the user first and allow
document preview/history/status with export processing false. Canonical HTML
preview does not persist an export snapshot or render a PDF. Create/again,
download signing, dispatch and Credit mutations remain blocked. Worker needs
the corresponding narrow document-read allowance; no ledger/RLS/retention
logic changes. Local two-identity fixtures prove own profile/job reads and
foreign profile FORBIDDEN / foreign job NOT_FOUND. These are mocked Auth/DB
tests, not two real Supabase sessions. Full suite passed **90/90**.

Smallest proposed cloud change: `allUsers -> roles/run.invoker` on ONLY
`jobix-dev-export-gateway`, retaining mandatory independent Supabase
verification and server-derived actor. Worker IAM remains private. Deploy
the Edge function with platform verify_jwt enabled (official Supabase
auth-headers documentation confirms asymmetric signing-key support), its
existing handler verification, Gateway URL, export=false and preserved
deletion approval. Roll out the read-only Gateway/Worker changes; no migrations.
No cloud changes have been applied for this request; exposure approval pending.

Prefer the existing two isolated test accounts and reusable test jobs.
Every export_jobs row requires a credit_reservations reference; do not pretend
an unowned random ID proves owned-job isolation or fabricate Credit rows.
If no reusable jobs exist, fixture-only terminal snapshots/jobs/released
reservations need explicit approval with unchanged balances/ledger, no
reserve/finalize calls, no PDF/GCS objects and exact fixture cleanup.

## One controlled Gateway-only fix deployment — Ready; safe live checks passed

Managed gateway-only build `be9b115a-14e8-4651-9893-64bbb22c788f` succeeded.
Deployed exactly one revision: **`jobix-dev-export-gateway-00003-whw`**.
Pinned gateway image:
`sha256:f41511f939d44072946ed85f03392b55e23520890c708dd0822a112b9eec269d`.
Latest-created and latest-ready revisions match; no startup operation error.
Configuration-stage hostname validation and authenticated native metadata
Gateway-to-Worker startup checks pass.

Existing deployer `run.routes.invoke` on this private Gateway was verified;
an operator Google ID token obtained with the existing deployment credential
allowed actual GET `/ready` (200). Its response confirms worker authentication,
both worker-only path denials, and exportsEnabled=false. This operator token
is never used as a Supabase user credential or a bridge runtime credential.

Executed live checks:
- Operator-authenticated Gateway readiness / Worker integration: 200.
- Valid Google token rejected as a non-Supabase application-user token:
  401 AUTH_REQUIRED.
- Top-level foreign actor override and nested foreign user_id: both 403 FORBIDDEN.
- Worker-only action recover at Gateway: 400 VALIDATION_FAILED.
- Anonymous Worker `/command`: 403.
- Gateway identity `/recover` and `/dispatch` at Worker: both 403, enforced
  and evidenced by the successful hosted startup verification.
- Worker revision/gates and both services' private IAM policies preserved.
All eight recorded live checks passed.

Worker remains revision `00003-frp`; it was not rebuilt or redeployed.
Both services retain export=false and the approved deletion-policy=true.
No IAM bindings, secrets, Supabase Auth, Credit/reservation logic, deletion/
retention policy, production/staging or keys were changed. No real Credit
transaction or billable PDF was attempted.

The tested gateway source was not altered during deployment; reuse the valid
49/49 focused and 88/88 full local results without rerunning them. Only
operational deployment-mode/audience guards were adjusted and syntax-checked.
Deferred honestly: a valid Supabase-user ingress journey and actual two-active-
user profile/job ownership lookup were NOT exercised. Live actor-override
denials are not a substitute for that ownership test. Exports remain closed;
the Gateway is private under the no-IAM-change instruction. No further
deployment or flag enablement was attempted.

## Proven configuration mismatch — hostname validators fixed locally; no redeployment

The owner-provided structured diagnostic event for revision `00002-cf9` is:
`stage=configuration`, `code=EXPORT_NOT_READY`.
Read the exact deployed revision (not just the service's current template).
Its worker URL hostname is `jobix-dev-pdf-export-mnvzhiynwa-ww.a.run.app`.
The original `workerTarget` regex accepted only
`^jobix-dev-pdf-export-[a-z0-9-]+\.run\.app$`, excluding Google's `.a.run.app`
format. HTTPS, root path, no credentials, no query and no fragment all passed.
The public client key passed validation; project and closed-export settings
match the expected configuration. The main environment guard has a distinct
DEVELOPMENT_CONFIGURATION_REQUIRED error, not the reported error.

Reproduced the exact EXPORT_NOT_READY failure locally with the deployed
configuration in workerTarget, GatewayIdentity's constructor and createBridge's
constructor. Thus failure occurs before metadata token acquisition or worker
requests. This is proven URL-validation mismatch, not missing IAM or a probe
timeout, and no setting or credential needs changing.

Smallest local change: accept the explicit optional `.a` label in the worker
hostname validator and the equivalent Edge gateway-target validator. Retain
HTTPS, service-name prefix, anchored hostname and all credential/query/fragment/
non-root-path rejections. Preserve previously accepted hostname format.
Updated normal bridge/Edge fixtures to use managed `.a.run.app` hosts and added
actual-worker constructor regression plus hostile URL rejection coverage.

Focused gateway/startup tests: **49/49 passed**.
Complete `node --test mobile/jobix/backend/pdf/test/*.test.mjs`: **88/88 passed**.
No image build, revision deployment, IAM/secrets/settings/Credit/retention/RLS/
production/staging change was performed. The deployed gateway still has the old
validator and remains unready/private until the owner advances deployment.
Post-deployment metadata/worker integration remains unverified.

## One approved private diagnostic revision deployed

Gateway-only managed build `d7725a17-3b1b-4beb-8c61-21a3ba44fe04` succeeded;
no worker image was rebuilt. Its pinned image is
`sha256:f81e3787be50f6af7525e6fe1ccd2a3f767a878662f14502d043d04c331adddb`.
Updated only the existing gateway container image using its service etag.
New diagnostic revision **`jobix-dev-export-gateway-00002-cf9`** still fails
closed at startup (`HEALTH_CHECK_CONTAINER_ERROR`, operation code 9).
No ready gateway revision and no public invocation binding were established.
Startup probe, runtime identity, configuration, export=false and approved
deletion-policy=true were preserved. No IAM/secret/policy changes were made.

Worker remains unchanged at ready revision `00003-frp`, IAM enforcement on,
export processing false and deletion-policy approval true. Gateway code/tests
are unchanged since the 84/84 pass; only gateway-only build/deploy tooling was
added/adjusted and syntax-checked.

The new diagnostic log read is still rejected with 403 under the deployer.
Need the NEW revision's structured event
`DEVELOPMENT_EXPORT_GATEWAY_NOT_READY` (stage/code/status), not another copy of
the old generic log. The single diagnostic-deployment approval has been
performed; no further revision should be deployed before reviewing evidence.
Actual startup root cause and hosted integration remain unverified.

## Uploaded startup logs — diagnosis evidence and local diagnostic fix

The uploaded log records `DEVELOPMENT_EXPORT_GATEWAY_NOT_READY` at
2026-10-09T05:18:22.911569Z, followed by `Container called exit(1)` at
05:18:23.564552352Z and a failed startup probe at 05:18:23.746412Z.
This establishes an explicit startup abort before the listener, not a probe
timeout. The deployed server's catch handler discarded the exception; no log
contains the failing stage, HTTP status or underlying error. The actual
startup root cause therefore remains unproven.

Read-only checks confirm the deployed gateway image/CMD/environment/probe
match the source, account email matches and is enabled, export processing is
false, approved deletion-policy flag is true, and identity is the dedicated
gateway service account. Using the existing authorized backend identity, the
actual private worker history request for the absent actor returned HTTP 503 /
ACCOUNT_DELETING as expected. This is backend-identity evidence, NOT proof of
the gateway's native metadata token or its complete startup sequence.

Minimal local observability fix: separate startup checks into `startup.mjs`,
retain fail-closed aborts, and emit only allowlisted stage/code/status. No token,
raw exception, provider body, environment value or profile data is logged.
Six new tests cover successful checks, metadata failure, history denial,
Google ingress HTML versus application denial, forbidden-path enforcement,
and redaction. Full regression suite passed **84/84**.

No image was built or revision redeployed for this change: the owner requires
root identification and local verification first. Missing evidence is the
specific metadata/history/recover-denial/dispatch-denial failure stage.
A separately approved private diagnostic-only gateway revision could obtain
that evidence without changing IAM, secrets, worker or export gates. Do not
claim the gateway startup is fixed or ask for the same already-insufficient logs.

## Concrete development bridge rollout — worker deployed, gateway startup blocked

Targeted account policy now binds the deployer through
`projects/mhflow-jobix/roles/CustomRole` (not the role ID `jobixGatewayAttach`).
Effective account tests confirm actAs/get/getIamPolicy and no tested signing/
general-impersonation permissions on that gateway account. No IAM binding was
changed by the agent.

The two old worker flag values came from explicit environment entries on
revision `00002-bpb`, not Dockerfile defaults or the original read-only runtime
configuration. Historical caller attribution is unavailable because audit-log
reads are denied. The approved deletion/retention ADR was verified, so its
approval flag remains true; only export processing is turned off.

Implemented a disabled-processing private worker mode: authenticated history/
status reads remain available for integration verification; create/again,
document rendering, download signing and dispatch are blocked. Export recovery
is skipped while approved retention/account-deletion cleanup remains enabled.
No Credit, RLS, database-function or retention-policy logic was changed.
Local suite passed **78/78**, including three new disabled-mode tests. An old
source-string startup assertion was updated for the explicit true/false mode.

Managed build `15209ddf-97da-47c3-9d67-7796bfc71c67` had a successful worker
step and failed gateway step. The Docker context denylist excluded the new
gateway/shared transport; adding exactly those allowlist paths resolved this.
Build `5d2fb32b-e36e-49f5-9a5e-f42c15a3aef5` succeeded and pushed both images:
- worker: `sha256:7f2cd4dc8e15afa8883e52bd5176527c822c033c0967c5e7cf642aa796dcaa88`
- gateway: `sha256:1dc542a8ecd4a0ebc5bea8b2278cc8d88e783ce8f268c7f54471c948389b1598`

Worker revision **`00003-frp`** is ready and receives 100% of traffic. Its
`JOBIX_EXPORT_ENABLED=false`; `JOBIX_EXPORT_DELETION_POLICY_APPROVED=true`.
Existing runtime identity, Secret version, CA configuration and private IAM
were preserved. Actual anonymous `/command` invocation returned **403**.

Gateway service was created, but revision **`00001-kqh`** failed its startup
probe (`HEALTH_CHECK_CONTAINER_ERROR`, Cloud Run operation code 9). There is
no ready gateway revision. The rollout stopped before adding public invocation.
Command: `node mobile/jobix/tool/deploy_phase3_bridge_dev.mjs --approved-development-bridge-rollout`.
Failing step: POST Cloud Run v2 services `?serviceId=jobix-dev-export-gateway`,
executed as `jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com`.

The runtime root cause is not yet established. Startup-log read returned 403;
project permission test confirms `logging.logEntries.list` is absent on
`projects/mhflow-jobix`. Smallest next action is administrator-provided sanitized
startup stdout/stderr for that exact gateway revision using existing access,
not a broad logging/IAM grant or a blind redeploy. Hosted Gateway-to-Worker
authentication and live user-security checks did not pass and are not claimed.
No real Credits/billable exports, production/staging, keys, Supabase Auth,
ledger/reservation, account-role/RLS or deletion-policy changes were made.

## Gateway deployment preflight — blocked; no cloud mutations

Read-only audit confirms worker `jobix-dev-pdf-export` has IAM enforcement
enabled, no public members, and an unconditional `roles/run.invoker` binding
for the exact gateway service-account email. Gateway Cloud Run service is
absent (404). Its account record and account policy cannot be read by the
deployer (403 for `iam.serviceAccounts.get` and
`iam.serviceAccounts.getIamPolicy`); effective account permission testing
returned none of `iam.serviceAccounts.actAs`, `.get`, `.getIamPolicy`, or
`.keys.list`. Thus the exact role binding and account/key state are unverified,
and deployer `actAs` is not effective. The supplied custom-role description
lists `.actAs`, `.get`, and `.getIamPolicy`; the deployed role definition
could not be independently read.

Verified deployer permissions include project-level `run.services.create`,
`.get`, `.update`, `.setIamPolicy`, and `cloudbuild.builds.create`/`.get`;
worker-scoped Run get/update/getIamPolicy/setIamPolicy; `actAs` on the backend
runtime and existing compute build identity; Artifact Registry get/upload/
download on `me-central1/jobix-dev`; and source-bucket object create/get.
These do not resolve gateway-account attachment.

**Additional safety blocker:** the current worker service has
`JOBIX_EXPORT_ENABLED=true` and `JOBIX_EXPORT_DELETION_POLICY_APPROVED=true`,
contrary to the requested disabled-flag condition. These values were observed,
not changed. Do not proceed to deploy/revise the worker or expose a gateway
until the scoped deployer role binding is corrected/verified and the flags are
disabled. No IAM/service/build/image/flag/Credit/production/staging mutation
occurred during this audit.

## Administrator-created identity — read-only audit: invocation PASS, attachment missing

Read-only checks under `jobix-deployer-dev` confirm the worker policy contains
an unconditional `roles/run.invoker` binding for the exact member
`serviceAccount:jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com`.
The worker retains IAM invocation enforcement, no allUsers/allAuthenticatedUsers
bindings and unchanged revision `jobix-dev-pdf-export-00002-bpb`.
This verifies that binding on this worker, not absence of grants elsewhere.

Account-scoped `testIamPermissions` executed successfully and returned no
`iam.serviceAccounts.actAs` for the deployer. Direct account metadata lookup
returned 403 / IAM_PERMISSION_DENIED / `iam.serviceAccounts.get`; account policy
lookup returned 403 / IAM_PERMISSION_DENIED /
`iam.serviceAccounts.getIamPolicy`. Account email/status cannot be independently
confirmed through metadata, nor its policy inspected, under this credential.
The member email in the worker binding is confirmed exactly.

Missing permissions are for the deployer, on only
`projects/mhflow-jobix/serviceAccounts/jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com`:
actAs for deployment, get/getIamPolicy for metadata/policy audit. Do not grant
these to the runtime gateway identity or add general impersonation/project-wide
roles. No custom role, resource, IAM grant, key, build, deployment, flag or Credit
operation was created/changed in this audit. Provisioning/deployment is incomplete.

## Direct approved account creation attempt — IAM_PERMISSION_DENIED

After the owner's explicit request to perform the scoped setup, read-only lookup
confirmed the proposed gateway account is absent. Attempted only:
`POST https://iam.googleapis.com/v1/projects/mhflow-jobix/serviceAccounts`
with account ID `jobix-export-gateway-dev`, using the existing
`jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com` deployment identity.

Google rejected creation with **HTTP 403**, ErrorInfo
**IAM_PERMISSION_DENIED**, exact missing permission
**iam.serviceAccounts.create**. This is an actual account-create denial, not
the earlier disabled-API or project-policy-audit failure.

Stopped. No service account/key/resource was created and no worker/attachment
policy was changed. Resulting-account policy/key/actAs verification is therefore
not possible yet. No deployment/build/export/real Credit operation was run.
The administrator can perform the three already-approved scoped setup operations
without granting the deployer Owner/Editor/IAM Admin or runtime impersonation.

## Resource Manager enabled — read-only audit blocked on caller IAM

Latest Service Usage check now confirms Resource Manager API **ENABLED**.
Project-scoped `testIamPermissions` executes successfully, but returns no
granted permissions from the tested provisioning/audit set for
`jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com`.
In particular, project account creation (`iam.serviceAccounts.create`) and
project IAM-policy read (`resourcemanager.projects.getIamPolicy`) were not
granted. The subsequent project `getIamPolicy` request returned **HTTP 403**.

Stopped before auditing worker-policy edit permission, the proposed account,
account-scoped actAs, user-managed keys or reusable custom roles. Project-level
results do not establish permissions on individual accounts/services.
No API/resource/role/IAM/key/build/deployment/export/Credit change was made.
Next resolution is administrator-performed scoped setup or separately approved
exact caller audit/provisioning permissions, not broad IAM Admin/Owner/Editor.
The earlier API-DISABLED blocker below is resolved.

## Resumed read-only prerequisite audit — API still DISABLED

Following the owner's API authorization, the read-only Service Usage lookup
for `projects/850519041397/services/cloudresourcemanager.googleapis.com`
returned state **DISABLED**. Authorization is not proof of activation.
Stopped the dependent caller-permission/inherited-policy audit; no API, account,
role, IAM binding, key, image, service, deployment or export flag was changed.

Google's Cloud Run service-identity documentation supports attachment through
a custom role providing `iam.serviceAccounts.actAs`. Prefer an existing exact
actAs-only project custom role, bound on the new service account alone. A new
custom-role definition would be a separate project resource; determine whether
one is needed and obtain approval before creating it. No existing custom role
or deployer effective permission was claimed verified in this blocked audit.

Required action permissions, not grants applied or caller capabilities proven:
account creation needs iam.serviceAccounts.create on mhflow-jobix; worker grant
editing needs run.services.getIamPolicy/setIamPolicy on the worker; deployer
attachment needs iam.serviceAccounts.actAs on the dedicated account; editing
that account policy needs iam.serviceAccounts.getIamPolicy/setIamPolicy.
Custom-role reuse needs iam.roles.list/get for audit; definition creation, if
approved and necessary, needs iam.roles.create. No Token Creator, signing,
database, GCS or Secret Manager grant is required for the gateway identity.
First resolution remains activation of the already-authorized Resource Manager
API, then complete the read-only audit and report before any mutation.

## Scoped gateway identity prerequisite attempt — BLOCKED before mutations

The owner approved only the dedicated development account, worker-scoped Run
Invoker and narrowly scoped deployer attachment permission, with a stop on
unexpected/broader permissions or changes outside those resources.

Before mutations, queried the standard `roles/iam.serviceAccountUser` definition.
It contains actAs plus service-account/project metadata read permissions.
No role was granted; an actAs-only requirement must not be silently expanded.
The next project-scoped preflight request:
`POST https://cloudresourcemanager.googleapis.com/v1/projects/mhflow-jobix:testIamPermissions`
returned **403**, with Google ErrorInfo reason **SERVICE_DISABLED** and service
**cloudresourcemanager.googleapis.com**. This does not prove a missing IAM role.

Stopped before creating the account or changing any policy. Project/inherited
policy auditing, actual new-account actAs evaluation, key listing, resulting
policy verification and deployment readiness could not be completed. No new
gateway service/image/build/deployment, real Credit or flag change occurred.

The local Google operations helper now allows the approved project's Resource
Manager audit endpoint and read-only definitions of the two approved roles,
and reports safe ErrorInfo classification without provider bodies/credentials.
Smallest next resolution: separately authorize/administrator-enable the
Resource Manager API for the approved development project, then rerun the
pre-change audit; do not add a broad IAM role to solve SERVICE_DISABLED.

## Development bridge deployment-readiness check — identity prerequisite missing

Inspected the committed local bridge changes without rerunning the green suite.
Read-only checks under the existing credentials:
- Development local configuration matches the approved Supabase project and
  provides an already-existing public client key. Client exports are not enabled.
- Live Supabase `/auth/v1/user` verification rejected an invalid bearer with
  HTTP 403; no user session/account was created.
- Management API GET `/projects/lmouxhbjhtqdtiqijcee/secrets` and `/functions`
  both returned HTTP 200. Successful bodies were cancelled without inspecting
  secret values. The earlier 403 metadata-read blocker is resolved. Read access
  does not establish Edge deploy/write permission; neither endpoint is required
  for bridge runtime authentication or the Google bridge deployment itself.
- Worker revision remains `jobix-dev-pdf-export-00002-bpb`. IAM invocation checks
  are enabled; no allUsers/allAuthenticatedUsers bindings are present. Anonymous
  POST `/command` returned 403. No bridge-identity invocation binding exists.
- GET of `jobix-dev-export-gateway` returned 404.
- GET of dedicated runtime service account
  `jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com` returned 404.

Stopped: the dedicated runtime identity and its worker-scoped invocation grant
are absent, so attached-identity/actAs/effective-permission checks and hosted
integration cannot yet pass. Smallest next step is explicitly authorized
identity provisioning plus only worker-scoped Run Invoker, with narrowly scoped
deployer actAs if needed. Then reverify before requesting/applying deployment.
The new worker authorization code also needs its approved image/revision rollout
before the bridge can satisfy its startup checks; no image was built here.

Only the proposed bridge is intended to receive public invocation. No service,
identity, IAM, token scope, credential, secret, Auth setting, database role,
image, deployment or export flag was changed. No Credit/billable export ran.
Bridge deployment/live integration and overall Phase 3 remain incomplete.

## Thin bridge local diagnosis/fix — PASS; deployment remains unverified

The owner authorized only local diagnosis, a minimal fix and local verification.
Reproduced the original fixture directly: Gateway was constructed without its
canonicalizer; evaluating `this.canonicalizer.prepare` threw
`TypeError: Cannot read properties of undefined (reading 'prepare')` before
the awaited source/ownership lookup. Database authorization calls were **zero**.
The mock worker serialized the uncoded exception as `error: {}`; bridge
validation correctly rejected that unrecognized error as SERVICE_UNAVAILABLE.
This was an incomplete test dependency, not an Auth verification outage.

Checked the existing SQL contract: foreign profile ownership raises FORBIDDEN;
an application account not ACTIVE raises ACCOUNT_DELETING. The minimal fix
supplies the fixture's canonicalizer with a fail-if-called implementation.
Assertions prove the authoritative checks execute and canonicalization does not.
No production authentication, authorization, account-status or error mapping
was weakened or changed.

Added explicit mocked Auth network-outage/timeout and disabled-account cases;
401/403 verification failures retain AUTH_REQUIRED and genuine outages retain
SERVICE_UNAVAILABLE, without Google credential acquisition or worker calls.
Application-account ACCOUNT_DELETING retains the existing worker HTTP mapping
(503) and specific error code; Auth-level disabled account remains 403.

Executed in the requested order:
- Targeted original failing test: **1 passed, 0 failed, 38 excluded by pattern**.
- `node --test mobile/jobix/backend/pdf/test/*.test.mjs`:
  **75 passed, 0 failed, 0 skipped** (39 bridge tests and 36 existing regressions).

All verification uses local/disposable mocks or loopback HTTP. No cloud/API
administration, resource/IAM/secret/Auth configuration, image, deployment,
export flag, real Credit transaction or billable export was changed or run.
Bridge deployment and live gateway/worker integration remain unverified;
Phase 3 is not ready or complete. The previous local security failure below
is resolved.

## Approved thin bridge implementation — LOCAL SECURITY GATE FAILED

The owner authorized development-only implementation/configuration, with an
explicit stop on any implementation/security-test failure. Implemented locally:
independent Supabase Auth verification, actor/identity-header rejection, closed
export gating, native attached-service-account ID-token acquisition, Edge
forwarding without Google private keys, and bridge-only worker path restrictions.
Added a lightweight non-root bridge image definition without new dependencies.
These changes are not deployed.

Executed once:
`node --test mobile/jobix/backend/pdf/test/*.test.mjs`

Result: **72 tests; 71 passed; 1 failed**. Existing 36 regression tests passed;
35 new bridge/security tests passed. Failure:

`cross-account access and inactive app account fail through authoritative Gateway checks`

At `backend/pdf/test/bridge.test.mjs:124`, the assertion expected
`FORBIDDEN` but received `SERVICE_UNAVAILABLE`. This combined test did not
establish cross-account/inactive-account correctness. Do not claim the bridge
security gate passed. Stopped without fixing/rerunning or beginning cloud work.

No new service account, service, IAM binding, image build, deployment,
migration, export-flag change, real Credit transaction or billable export.
Existing deployed worker, Scheduler and private bucket were not modified.
Supabase signing configuration and native Flutter/Android code are unchanged.
Overall Phase 3 remains incomplete.

## Existing Scheduler resumed — PASS; gateway access checkpoint — BLOCKED

Following the administrator's Scheduler service-scoped Run Invoker correction,
resumed the existing `jobix-dev-pdf-export-recovery` job (no duplicate created)
and explicitly triggered its actual live invocation. Observed canonical RPC
status **0 / OK** at `2026-10-08T19:34:28.589778Z`. The job remains `ENABLED`,
every minute, using `jobix-scheduler-dev` OIDC and the exact private worker
service audience. Private IAM enforcement, backend identity and absence of
public service bindings passed read-only guards. No IAM grant was added.

The next gateway prerequisite check failed:
`GET https://api.supabase.com/v1/projects/lmouxhbjhtqdtiqijcee/secrets`
returned **HTTP 403** under the existing development management credential.
Stopped at that failure. The function inventory and database flag read in the
same guarded procedure were not reached. Remote gateway credentials/configuration
therefore remain unverified, not proven absent.

Local Edge source still has only the optional
`JOBIX_EXPORT_GATEWAY_IDENTITY_JSON` key-backed adapter; it has no implemented
keyless token transport. No key was created or requested, no deployer credential
was substituted, and no gateway deployment or export-flag change was performed.
Database flags were last verified disabled before this checkpoint and were
not changed here. No billable end-to-end tests, real Credit transaction or
production/staging changes. Overall Phase 3 remains incomplete.

Next prerequisites: administrator-authorized development management access to
the rejected metadata endpoint and an approved, verifiable keyless Edge-to-private
worker identity mechanism before enabling client exports. The earlier Scheduler
invocation failure below is resolved.

## Development worker activated — BLOCKED at Scheduler invocation

After the administrator's service-scoped backend Run Invoker correction:
- Genuine backend Google ID-token invocation of `/ready` returned HTTP 200.
  Secret resolution, verified TLS, `jobix_export_runtime` and required function
  privileges passed. Anonymous invocation returned HTTP 403.
- Activated the existing pinned image's actual `node server.mjs` entrypoint
  on private `jobix-dev-pdf-export` in `me-central1`. Ready revision:
  `jobix-dev-pdf-export-00002-bpb`. Existing backend identity, Secret version 1
  and CA binding were preserved. No IAM policy was changed.
- Runtime has two browser slots, maximum three instances, request concurrency
  two, 900-second request timeout, two CPUs / 2 GiB per instance and TCP startup
  probing. Authenticated invalid-action transport verification returned the
  expected HTTP 400 / `VALIDATION_FAILED`; anonymous invocation returned 403.
  This is worker transport verification, not successful PDF generation.
- Created development Scheduler job `jobix-dev-pdf-export-recovery` in
  `me-central1`, every minute, UTC, POST `/recover`, body `{}`, using
  `jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com` OIDC and the exact
  service URL as audience. The explicit live run failed with canonical RPC
  status **7 / PERMISSION_DENIED**. No service-level invocation binding for
  this identity was present. Paused the newly created job to prevent repeated
  failures; readback confirms `PAUSED`.

Stopped at the Scheduler failure. Gateway rollout, database export-flag
enabling and live billable end-to-end tests were not performed. Database flags
remain disabled. No real Credit transaction, new key, broader IAM permission
or production/staging change. Existing migrations and native code preserved.
Administrator action: authorize Scheduler `roles/run.invoker` on this private
service only; reverify actual Scheduler invocation before continuing. Overall
Phase 3 remains incomplete. The prior backend invocation blocker below is
resolved, not the current blocker.

## Actual development rollout attempt — BLOCKED on private invocation

The owner authorized actual development activation/integration and fail-fast.
The protected migration runner confirmed all six installed migration checksums
and skipped already-applied schema changes, including the explicitly requested
012–014. Live metadata confirms RLS on the checked export/Credit tables with
authenticated client INSERT/UPDATE/DELETE denied. Rollout flags remain false.

The actual backend identity lacks `run.routes.invoke` on
`projects/mhflow-jobix/locations/me-central1/services/jobix-dev-pdf-export`.
Live HTTP verification using a genuine Google-issued backend ID token, the
correct service audience and `/ready` returned **403**. This is a private-service
invocation failure, not a database credential/CA/image failure.

Stopped at that failure without adding IAM grants or changing identities.
The actual worker entrypoint was not activated; existing readiness-only service
remains unchanged. Scheduler/gateway enabling and live billable export journeys
were not attempted. No real Credit transaction or production/staging change.
Overall Phase 3 remains incomplete. Operator action requires explicitly scoped
backend invocation access on this service only, not project-wide/public access.

## Development runtime Secret/CA binding — READY, read-only

Configured only the development runtime `jobix-dev-pdf-export` in `me-central1`
using the existing immutable image and `jobix-backend-dev` account:
- `JOBIX_DEV_EXPORT_DATABASE_URL` references existing Secret
  `projects/850519041397/secrets/jobix-dev-export-database`, version `1`.
- `JOBIX_DEV_DATABASE_CA_FILE` points to
  `/opt/jobix/assets/certs/supabase-root-2021.crt`.
- Runtime command is read-only readiness verification, not the normal worker.
  Export/deletion processing flags are false; no scheduler was configured.

Actual hosted verification:
1. Cloud Run readback confirms the Secret reference; startup and authenticated
   `/ready` prove successful resolution.
2. Exact version 1 is accessible to the configured runtime identity.
3. The CA exists at the configured path and matches the approved fingerprint.
4. The real database socket is encrypted and certificate-authorized; the
   production database adapter enforces `rejectUnauthorized: true`.
5. The database session is `jobix_export_runtime`, with privileged flags false.
6. Read-only catalog queries verify all 19 gateway/worker function privileges.
   No mutating export function was invoked.

Cloud Run Ready/RoutesReady/ConfigurationsReady succeeded. Authenticated
readiness returned HTTP 200 with all six confirmations and
`exportProcessing:false`; anonymous access returned 403 and dispatch 503.
No credential rotation/new Secret, database migration, IAM-policy change,
real Credit transaction, production/staging change or production worker start.
Full Phase 3 export processing remains unactivated/unverified; this checkpoint
is runtime readiness only.

## Owner-approved scoped bucket IAM cleanup

**BUCKET SCOPE VERIFIED; signing correction pending; deployment still blocked.**

- Removed only `jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com` from
  obsolete bucket `roles/storage.objectUser` membership, as explicitly approved.
- Retained `projects/mhflow-jobix/roles/jobixExportObjectAccess` and every
  unrelated role/condition/principal. Used policy etag/metageneration guards;
  full policy readback matched only the intended change.
- Pure fixture tests passed unchanged input, other-principal/condition
  preservation, idempotency and required-custom-role guard.
- Actual backend permission readback returns exactly object create/get/list/
  delete. Update/restore/move are absent.
- No objects or lifecycle/retention settings changed. Signing remains pending
  administrator correction as confirmed by the owner. No worker/Edge/Scheduler
  deployment or export activation was performed.

## Managed image and restricted runtime credential checkpoint

**PARTIALLY VERIFIED; no worker/Edge/Scheduler deployment; exports disabled.**

- Managed build succeeded in `me-central1`; image pushed to existing
  `jobix-dev/pdf-worker`, pinned digest
  `sha256:670a21879bd42deae556d2208b83571e5c0d145c10a58c51423027956412347d`.
- Managed image verification passed actual AOT canonical generator and pinned
  Playwright/Chromium English/Arabic PDF generation/structural/text/font checks,
  plus invalid-PDF rejection. The first synthetic-fixture attempt failed on its
  invalid day-date; correcting to the logical month DTO passed without product
  changes. Host Chromium is not used as a production-engine substitute.
- Created only the approved restricted development LOGIN and encrypted secret
  version. Backend secret access and verified-TLS login passed. Membership is
  exactly export gateway/worker; privileged flags are false; direct export
  INSERT and user UPDATE are denied. No credential output/file or SA key.
- IAM still blocks deployment: custom bucket role exists, but obsolete
  backend `storage.objectUser` membership remains; signing still permits extra
  token/JWT/delegation powers. No IAM policy was changed without grant-removal
  consent. Existing principals must be preserved when correcting scope.
- Canonical/public build source remains retained for retry, no active export
  fixture objects remain, and no real Credit transaction or export activation
  occurred. Full private Edge→worker, Scheduler, and live export/deletion
  journeys remain unverified.

## Operator access update — private backend storage/signing verified

**PARTIALLY VERIFIED; deployment/activation remain blocked.**

- Actual backend-identity `GoogleStorage` adapter passed conditional upload,
  duplicate create rejection, generation-specific inspect/read, IAM self-signBlob,
  private signed download and signed-generation tamper rejection. Anonymous
  access was denied. Signed URL/token/signature were not printed or persisted.
- Only the freshly created synthetic protocol fixture was deleted by exact
  generation; the owned prefix and full active export prefix were verified empty.
  This is not an actual Chromium PDF, Cloud Run metadata identity, authenticated
  Edge export or Credit finalization test.
- Cloud Build inventory/default-builder reads succeeded. Actual submission
  failed on missing deployer actAs of
  `850519041397-compute@developer.gserviceaccount.com`.
- Runtime-secret resource project number was verified against the approved
  bucket. Both numeric/friendly path checks still deny required secret access.
  No runtime database credential/LOGIN was created, read out or substituted.
- Minimum IAM has not passed: observed backend objectUser grant permits
  update/restore/move in addition to approved CRUD. Effective signing permissions
  include token/JWT/delegation operations beyond signBlob. No IAM mutation was
  made; narrowing must preserve unrelated principals/bindings.
- Native/product code and dependency manifests/locks remain unchanged.
  Operational tool syntax and dependency checksum checks passed.

## Development migration and approved cleanup checkpoint

**PARTIALLY VERIFIED; exports disabled; worker deployment blocked by IAM/access.**

Completed against development only:
- Verified TLS with the supplied public Supabase Root 2021 CA; applied all six
  Phase 3 migrations (012–017) in one transaction. Re-running the protected
  runner passed checksum/idempotency checks. The development ledger has six
  entries; both export rollout flags remain false.
- Verified upload-flight RLS, denied client job INSERT/purge/ledger UPDATE and
  private-client table access. No production/staging connection was made.
- Read back private bucket IAM/uniform access; no public principal grants.
  Installed/read back only the approved Delete rule: age seven days, prefix
  `exports/`, suffix `.pdf`. Existing prefix inventory was empty.
- Live DB tests passed canonical preparation, atomic same-key replay, reserve
  two/release on freeze, client table denial, cross-actor status isolation,
  object-absence verification and export snapshot/related-data purge. All
  synthetic identities/data/Credit entries and temporary flag changes rolled
  back; no existing account/profile/completeness/allowance data was modified.
- Live private GCS conditional-create/conflict and anonymous denial tests
  passed with an explicitly synthetic storage-protocol fixture using deployer
  tooling. Its exact generation was deleted and no active export objects remain.
  This does not verify the runtime backend or real PDF/signed download path.
- Bundled the public CA for the managed runtime; uploaded only allowlisted
  source/fonts/licenses/public CA privately for a managed build retry. No
  developer config, credentials or user data is included. The build source is
  retained outside `exports/`; it is not deleted as a test fixture.

Actual blocks: managed build submission 403, custom-role creation 403,
`secretmanager.secrets.create` 403, and no tested storage or self-signBlob
permissions for the backend. No service-account keys, IAM grants, worker,
Scheduler jobs, Edge rollout or runtime credentials were created. No dependency,
Flutter product/signing, AI or billing changes. Full deployed end-to-end
verification and Phase 3 completion remain outstanding.

## Development implementation authorization — current build increment

The owner superseded the recording-only pause with complete Phase 3 DEVELOPMENT
implementation/deployment/live-test authorization. Production/staging, new
service-account keys, AI/billing, broader product changes and unjustified upgrades
remain excluded. Destructive/irreversible cloud operations require approval.

Implemented in this increment:
- Forward-only migration 017: private durable physical-upload flight tracking,
  one unresolved create per job, late-response settlement without Credit
  finalization, distributed quiescence checks, export-only transactional
  snapshot/job/receipt/reservation purge with absence verification.
- Existing account/profile DELETING transitions freeze exports automatically;
  physical deletion cannot cascade away export evidence before cleanup.
  No new Auth/account deletion API, slot policy or immutable-ledger mutation.
- Conditional upload metadata includes the unique fence; matching stored
  source/document/fence evidence reconciles a lost response. Unproved requests
  keep deletion pending. Prefix listing/removal covers orphan objects; absence
  is checked again before snapshot purge.
- Private recovery invokes deletion integration. PDF expiry still preserves
  snapshots/history/replay and never silently regenerates or charges.
- Managed-build Dockerfile and strict context allowlist, same Dart 3.8.0 AOT
  canonical source and locked Playwright engine; no local Docker or version upgrade.
- Guarded opt-in additive development migration runner, single transaction,
  checksum ledger, verified TLS and rollout flags unchanged.

Evidence: canonical AOT compiled successfully and actual AOT/Dart source → host
Chromium/Poppler → disposable PostgreSQL integration passed, including historical
security/credits/RLS tests and new freeze/ambiguous-flight/purge/physical-delete
guards. Production container/pinned browser and deployed end-to-end path are not
verified; no remote migration/deployment/live Credit transaction occurred.
All **36 backend contract/recovery/cleanup tests passed**. JavaScript syntax,
opt-out migration-runner guard, unchanged dependency-manifest/lock checksums and
diff checks passed. No Flutter product/test code changed in this increment;
the previously passing **208 regression + 16 export tests** were preserved.

Authenticated development checks found the approved repository/bucket, no
Cloud Run services/Scheduler jobs, usable backend actAs/impersonation, and
Supabase function-list access. Cloud Build list/Secret Manager list returned
403; backend bucket permission tests returned no granted permissions.
The administrative DB connection failed verified TLS without its trusted root
certificate. Public certificate download and management retrieval were denied;
TLS verification was not weakened. These are access/runtime blockers, not
reopened product decisions. No IAM/bucket/lifecycle/production changes were made.

## Phase 3 local PDF/Credits implementation — 2026-10-08

**Status: PARTIALLY VERIFIED; rollout remains blocked and disabled.**
No live migrations, deployment/IAM/Scheduler/Cloud Run changes, GCS writes/signing
or real Credit operations. Deletion/snapshot policy was not implemented in the
preceding local pass; its product contract is now approved as recorded below.
No signing/APK/build-environment changes or AI work.

### Approved deletion/retention decision — recording only

The exact owner-approved ten-point contract and current restrictions are recorded
in `backend/pdf/ADR-retention-deletion.md`. Product approval is not implementation,
deployment or live-test authorization. All remote gates remain closed.

PDF objects retain the approved seven-day logical lifetime; expiry/missing
downloads never silently regenerate or charge again. Expiry alone does not require
immediate snapshot/canonical-HTML deletion. Explicit Export Again uses current
profile data and costs two Credits. Profile/account deletion must freeze new
export work, invalidate leases, release pending reservations, prevent usable
late/stale objects, remove its export objects/snapshots/related export data and
verify no active export objects/snapshots remain before completion.

No additional retention period or change outside PDF/export deletion integration
is approved. No implementation or test behavior was changed for this record.
Existing fixtures intentionally describe the current incomplete purge path,
not satisfaction of the newly approved full-deletion contract. No tests/builds,
migrations, worker starts, live operations or deployments were run for this update.

### Additional authorized local pipeline/recovery step

**Implemented and fixture-verified; not approved for rollout.**

- Canonical preparation now checks normalized UTF-8 source size in a separate
  source-only pass before HTML/font rendering, using the same Dart generator.
  Snapshots archive exact embedded-font checksums, font-license text/checksums,
  bundle/model/template/config versions and immutable canonical HTML.
- Two additional **unapplied** forward migration files harden null/stale fences,
  active-profile guards, recovery eligibility after lock waits, asset metadata
  and private cleanup hooks. No historical migrations were edited.
- Independent heartbeat/hard-deadline cancellation covers stalled render,
  validation and storage adapters; late results cannot finalize a newer lease.
- Private freeze hooks consume an **already DELETING** account/profile state,
  invalidate job leases and release only pending reservations. They never modify
  Auth or mark account deletion complete. Object cleanup requires an explicit
  quiescence verifier and generation checks. In that local pass the snapshot
  policy was unapproved; purge remains unimplemented despite the subsequent ADR
  approval. Current instructions permit recording only.
- Seven-day expiry cleanup preserves completed charges, history and replay;
  verification markers prevent repeatedly scanning already-cleaned objects.
  Private recovery is wired to the approved PDF-only expiry cleanup hook.
- Client history/download/Export Again eligibility respects active profile and
  ownership; structural invalid URLs are reported rather than silently omitted.

Latest checks:
- **33 Node contract/recovery/cleanup tests passed**, including deterministic
  virtual-clock heartbeat, timeout, stale upload, ambiguous upload/completion,
  conditional-create adoption, asset tampering, pagination, expired objects and
  cleanup races.
- **208 Flutter regression tests passed** with default-off exports.
- **16 opt-in local Flutter checks passed**, including reopened frozen requests,
  explicit visibility/config versioning, paid Export Again, history pagination,
  insufficient-Credit retry, invalid included personal URLs and successful free
  download byte streaming to a mocked save channel without URL persistence.
- Historical + new migrations and SQL lifecycle/freeze tests passed in a
  disposable PostgreSQL cluster. Actual concurrent connections returned the
  same accepted receipt with one reservation. An injected failure between debit
  and job completion rolled back both. Duplicate callbacks debit/release once.
- End-to-end canonical Dart + actual existing local Chromium/Poppler passed:
  free repeat download, paid Export Again, exact-generation expiry cleanup, and
  a real canonical CV over twenty pages rejected before upload/debit.
- Analyzer: zero errors/warnings; two pre-existing standalone fixture import
  infos. Client secret/layout/token checks passed.
- Declared PDF dependencies restored at their existing exact versions into
  the isolated product directory, with its own frozen lockfile. Root manifests,
  root lock and Flutter manifest/lock hashes unchanged.

**Runtime blocker:** the downloaded Playwright-pinned headless browser does not
launch in this Nix/host libc environment. It initially lacked shared libraries;
reusing available libraries exposed incompatible glibc ABI requirements.
No browser substitution, system-library upgrade or cloud image build was done.
The CDP integration uses the explicitly identified existing host Chromium and
does not prove production Playwright runtime readiness. Browser child processes
now receive only approved non-secret environment fields.

Local checks passed:
- Standalone Dart EN/AR structural validity, unscored Volunteer, optional
  descriptions, explicit visibility and contact rules.
- Sixteen built-in Node contract checks: transport-idempotency, replay before
  mutable reads, pre-reservation conflicts, input rejection, free download,
  confirmed missing vs transient object failures, fenced worker/proof ordering,
  20-page overflow before upload, concurrency slots, text preservation and
  fail-closed private authentication/startup/TTL.
- Existing historical and new forward-only migrations applied successfully to
  disposable PostgreSQL. Synthetic tests cover default-off gates, immutable
  snapshots, exact replay after edits/old receipt pruning, owner isolation,
  no reservation on stale versions, stale leases, successful single debit,
  repeated completion, missing-file handling, expiry release, role restrictions
  and configuration/profile-version increments without completeness/AI change.
- Real disposable SQL + server canonical Dart HTML + actual local Chromium PDF
  with verified English/Arabic text + exactly one debit + free repeat downloads.
  Storage is explicitly an in-memory test adapter, **not GCS**.
- Existing print checker self-tests: 21 passed.
- All 16 canonical EN/AR print fixtures passed all 304 cohesion checks, text,
  embedded-font and A4 checks. No baseline was refreshed.
- Owner-authorized locked Flutter/Dart package restoration completed.
  `pubspec.yaml` and `pubspec.lock` hashes are unchanged; no upgrades.
- Full Flutter regression suite: **208 passed**, with export disabled by default.
- Opt-in local export-control suite: **9 passed**, using synthetic HTTP fixtures
  and disposable encrypted SQLCipher. Covers exact server Preview bytes, explicit
  visibility/structural evidence, English/Arabic phone-width layouts, cost
  confirmation without submission, ambiguous acceptance followed by reopening
  and same-key reconciliation, expired downloads without replacement, and
  explicit Preview review after confirmed version conflicts.
- Flutter analysis has **zero errors/warnings**. Run with
  `--no-fatal-infos`; two pre-existing informational relative-import notices in
  the standalone print-fixture tool remain. Client secret/layout/token checks pass.

Not verified: Android SAF/real-phone controls, production Playwright runtime packaging, deployed Edge/OIDC,
private GCS/IAM/runtime TLS and live reservation recovery under cloud failures.
The earlier missing-cache analyzer failure was resolved by owner-authorized
restoration, not by upgrading packages or weakening product validation.

See `backend/pdf/README.md` for reproducible local checks and closed readiness
gates. Source work is local only; this evidence is not rollout/device acceptance.

## Offline Resume print regression suite — 2026-10-08

**Status: PASSED.** This is synthetic canonical-renderer verification, not
Android/WebView/phone acceptance or a PDF export feature.

Run from the repository root:

```sh
python3 -m unittest discover -s mobile/jobix/tool -p test_resume_print.py -v
# Also run the existing visual-checker self-tests (no baseline refresh):
python3 -m unittest discover -s mobile/jobix/tool -p 'test_resume_print*.py' -v
python3 mobile/jobix/tool/check_resume_print.py
# Optional: retain synthetic HTML/manifest/DOM/PDF/text/screenshots/report in /tmp
python3 mobile/jobix/tool/check_resume_print.py --keep
```

Requirements are a POSIX host, Python 3.10+, the **existing** Dart SDK, Chromium,
`pdftotext` and `pdffonts` on PATH, and the packaged Inter/IBM Plex Arabic fonts.
The suite is Python
stdlib-only. It reports missing tools rather than installing them. Direct Dart
VM execution and relative imports of the existing pure-Dart canonical sources
avoid package restoration, CLI telemetry and the missing Flutter lint cache.
The existing comparison-fixture command remains available without
`--regression`. No dependency/configuration or analyzer-rule changes were made.

### Automated coverage and observed results

- **16 fixtures passed:** short, long, four varied page-boundary profiles,
  plus two populated credential/language profiles in each of English and Arabic.
  All repeatable fixture fields pass the current
  structural validator. Names, email and portfolio contacts include long cases.
- HTML uses `ResumeRender.html` directly, the packaged fonts and unchanged
  canonical CSS/CSP. The suite checks language/direction, model/template
  revisions, stable template IDs and profile metadata.
- Valid authored UL/LI grouping, plain/numbered paragraphs, blank paragraphs,
  per-record text/metadata preservation and ordered descriptions are checked
  against the input manifest. Paid Work and Volunteer remain separate.
  Skills remain one selectable compact paragraph with every skill in order.
- The four added fixtures populate Certifications, Achievements and Languages
  alongside the existing sections. They check each title, issuer, issue/expiry/
  achievement month, credential ID, authored description and safe HTTPS URL
  against the source manifest. Link text and DOM href must both match, including
  query-string punctuation. Expiry labels and all five proficiency labels
  (Basic, Conversational, Professional, Fluent, Native) must use the selected
  English/Arabic translation in the correct record.
- Minimal credentials/achievements have empty optional descriptions, dates,
  credential IDs and URLs; no phantom expiry label or link is allowed. Long
  issuer text, IDs, URLs and mixed-direction multiline descriptions remain
  within the actual field limits. Every language has a mixed-script SQL island.
  Missing/moved titles and unexpected extra records are rejected.
- PDF extraction preserves complete normalized visible characters, including
  punctuation and repeated text, rather than just checking a final sentinel.
  NFKC normalization and removal of whitespace/direction controls accommodate
  Arabic shaping/visual ordering without hiding lost punctuation or content.
  Unique Latin markers also prove each authored Work line survives exactly
  once; long fixtures exercise entries split across pages.
- All pages are A4; the canonical page rule must specify **18mm margins**.
  Extracted text boxes are checked for clipping/overflow. Vertical font-box
  tolerance is 5pt because Poppler's ascent/descent boxes are not painted ink
  (the 24pt Inter heading extends about 3pt above its CSS line box). Horizontal
  tolerance is 1.5pt. No arbitrary long-document page count is enforced.
- **304 heading/metadata cohesion checks passed**, using same-page first
  content, actual line positions and observed heading-font boxes. This avoids
  mistaking an Arabic section word repeated in metadata for a second heading.
- Both short fixtures are one page. Long fixtures were seven pages in English
  and five in Arabic; boundary fixtures were three pages in this toolchain.
  Expanded fixtures must exercise pagination, not match these exact counts.
  Added credential cases were three pages per language; their long variants
  were six pages. These observed counts are not assertions. The original short
  one-page contract remains unchanged.
- Both packaged font faces load; printed fonts are embedded with Unicode text
  extraction, with no unexpected fallback fonts or whole-entry page locks.
- **12 logical/print checker self-tests passed** (21 including the nine
  existing visual-checker self-tests), including intentionally missing/reordered
  text, missing skills/metadata/punctuation, wrong revisions/page geometry,
  malformed lists, font failure, overflow and orphaned headings.
  The new negative checks remove each credential/achievement field and all
  five proficiency labels independently from DOM and extracted PDF text, and
  reject untranslated labels, changed hrefs, spurious optional values, moved
  records and changed section order.

The original 12 fixture inputs, including all three selected visual-baseline
cases, are unchanged. This extension does not generate, approve or refresh any
visual baseline. The opt-in visual results below describe the earlier reviewed
run, not a new visual comparison for the added credential cases.

The browser uses a local DevTools pipe, not a listening server. HTTP(S) requests
are blocked and background browser networking is disabled. Tool subprocesses
receive only boot/environment settings, not application credentials. Files are
temporary and synthetic; successful evidence is deleted unless `--keep` is
requested, and failure evidence is retained for diagnosis.

No Flutter product source, Auth/Supabase/database/RLS, scoring/AI state,
architecture, Android signing/build configuration or dependency files changed.
No supporting services, live-data, AI or APK-build operations ran. Existing
APK/build artifacts are preserved.

## Opt-in offline Arabic/RTL visual guard — 2026-10-08

**Status: PASSED.** All 12 logical/print fixtures and all 17 checker self-tests
passed. Seven representative PDF pages matched the explicitly reviewed baseline
with zero changed pixels. Negative self-tests reject joining/mark-like ink loss
or addition, weight/position changes, dimension changes, altered candidates,
unreviewed baselines, engine/font/policy drift and missing page coverage.

Visual snapshots **complement all logical text, embedded-font, geometry and
heading-cohesion assertions above; they never replace them**. The same Dart
canonical renderer and local Chromium DevTools pipe produce the PDFs. Existing
`pdftoppm` rasterizes them at 96 DPI; no dependency installation, second product
renderer, HTTP server, app/API startup or live account/data is involved.

The representative set covers every PDF page of Arabic short, Arabic boundary-10
and English boundary-10 (currently seven pages). Arabic synthetic content adds
joined letters/lam-alef, tashkeel, punctuation, quotes and Latin SQL/C++/R&D/date
islands; existing contacts, mixed skills and long headers exercise bidi/wrapping.
PNG previews and RGB PPM comparison rasters are temporary/ignored only.

```sh
python3 -m unittest discover -s mobile/jobix/tool -p 'test_resume_print*.py' -v
# Candidate directory MUST be new. Generation does not approve anything.
python3 mobile/jobix/tool/check_resume_print.py \
  --visual-candidates mobile/jobix/.resume-visual-baselines/new-review
# OPEN EVERY generated PNG. Compare with prior approved PNGs if available.
# Check joining, diacritics, punctuation, Latin island order, contacts/dates,
# weight, spacing, header wrapping, alignment and page continuations.
python3 mobile/jobix/tool/resume_print_visual.py \
  --approve mobile/jobix/.resume-visual-baselines/new-review \
  --review-note "Describe which pages/features were visually checked and why accepted"
# Only an explicitly reviewed manifest can be compared:
python3 mobile/jobix/tool/check_resume_print.py \
  --visual-baselines mobile/jobix/.resume-visual-baselines/new-review --keep
```

The ignored `mobile/jobix/.resume-visual-baselines/current` set was explicitly
visually reviewed page-by-page for this change. Review found joined Arabic,
visible diacritics/punctuation, intact LTR contact/date/skill islands, wrapped
long headings and unclipped page continuations. This is an agent-reviewed host
baseline, **not owner design approval, native WebView or real-phone acceptance**.
Because evidence is intentionally not committed, a fresh checkout must obtain
the retained reviewed directory or generate **and deliberately review** new
candidates; a missing baseline is a failure, not an auto-update.

Recorded capture versions: Chromium **152.0.7977.64**, revision
`506c834ecceaa943c5f41e6cfe7f68acb5c45346`, JS **15.2.124.18**;
Poppler **26.06.0**, Linux x86_64. Font binary SHA-256 fingerprints (version
authority, including any internal font-name/version changes):

- Inter.ttf: `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031`
- IBMPlexSansArabic-Regular.ttf: `6f611412270a132bbac838da9259d4c68569b4175f3b3b8fa3fa36a30b56dab9`

Each manifest records these engine/font fingerprints, capture policy, source
hashes, image hashes and a separate explicit review note/time. Changing
Chromium, Poppler, fonts, platform, DPI/tolerances, fixture content or page
coverage fails closed. Generate a *separate* candidate set and inspect **all**
pages deliberately; do not automatically bless the new output or loosen
tolerances to hide regressions. Candidate generation cannot overwrite an
existing directory, and approval verifies PPM/PNG integrity before recording
review. Baseline PPM integrity is also checked during comparison.

Tolerance: ignore RGB channel changes <=24/255, allow at most **1.5% changed
pixels relative to ink** over the page, and at most **12%** within any 64x64
tile (minimum denominator 32 ink pixels). Ink means either image has a channel
below 245. This tolerates minor antialiasing, not page-sized white-space dilution
or broad font/position changes; local tiles catch small missing joins/marks.
Dimensions must match exactly; no image registration, cropping or blurring
hides shifts. This is not a guarantee of catching every subpixel defect.

On failure the suite retains current PDF/PNG/PPM evidence in `/tmp` and writes
a red changed-pixel `*-diff.ppm` where pixel comparison ran. Open that alongside
the approved PNG; `report.json`/`visual-manifest.json` on successful runs record
the results. Poppler may emit existing Type 3 glyph bounding-box warnings while
rasterizing bullets; these do not waive text/font checks or visual comparison.

## Phase 2 — Volunteer and targeted Resume refinements — 2026-10-08

**Status: implementation, local checks and authorized development rollout
verified; native acceptance remains BLOCKED / NOT VERIFIED.** Remote execution
occurred only after explicit owner approval and secure access provisioning.

### Implemented

- A first-class `volunteer` type and `volunteer_experiences` snapshot array;
  separately stored owner-scoped records through the additive
  `202610080011_volunteer_experience.sql` migration.
- Organization, Role/Title, optional Location, month range, current toggle and
  optional Description with the approved limits. Current roles clear stale
  end months; zero-year dates are rejected.
- Create/edit/delete entry points in Career Profile, builder Step 3 and Review,
  English/Arabic labels, unchanged six-step navigation and the accepted
  explicit-Save/discard/quality-warning policy.
- Generic encrypted drafts/outbox reuse, version/conflict handling, frozen
  unknown-Save replay and canonical profile cache. No local database schema or
  dependency version changes.
- Volunteer is distinct unpaid ATS/profile evidence and a separate Resume
  section. No new ATS/AI operation or paid-employment classification.
- Compact plain-text Skills and valid semantic lists for explicitly authored
  bullets, preserving prose, blank lines and ambiguous numbering.
- Centered personal header selected after current/centered EN/AR comparisons,
  including long names/contacts. It separates personal information from the
  body while retaining conventional text and mixed-script isolation.
- Shared canonical HTML/CSS retains A4/margins, embedded Inter/IBM Plex Arabic,
  escaping/CSP and existing template IDs. Renderer/model revision metadata is
  2; this is not a completeness algorithm revision. Metadata/header cohesion
  improved without whole-entry pagination locks or a second PDF renderer.

### Completeness and AI-state boundary

Volunteer never qualifies for percentage credit or a scored evidence count.
The existing Contact/Evidence/Skills/Summary/Languages/Target Role weights,
30 + 15 evidence qualification, algorithm/version and 50% latch are unchanged.
Volunteer mutations update only profile/item versions and timestamps; they
do not invoke completeness recomputation or update its trigger column.
The migration contains no scoring/AI-state backfill.

No product Auth or AI code, historical migration, Android signing/configuration,
supporting Node service, package/lockfile, staging or production resource was
changed. The disposable SQL fixture alone gained the role/schema shape needed
to execute the existing later-foundation tests; it must never run on Supabase.

### Passed checks

- `dart tool/check_foundation.dart config/dev.local.json`.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: **204 tests passed**, using real
  SQLCipher and packaged production fonts.
- EN/AR Volunteer widget Save/edit/discard/delete and quiet pre-Save/empty
  descriptions, generic Back regressions and Review return paths.
- Encrypted host database reopening with a lost Volunteer Save response,
  retained frozen key, no duplicate record and unchanged 45%/algorithm.
  This is not native Keystore/process-death proof.
- `bash tool/test_rls.sh`: existing foundation and later Resume/AI foundations,
  populated-database Volunteer migration, exact old acknowledgement replay,
  CRUD/idempotency/conflicts, malformed input, anonymous/cross-owner/direct-write
  denial and deleting/deleted-account guards.
- SQL non-regression at 0%, 45%, 50%, 55%, including a legacy above-threshold
  profile with no allowance row: Volunteer operations preserve profile scoring,
  AI rows, wallet and ledger. Normal paid evidence still contributes 30 then 15.
- Chromium static canonical fixtures: short EN/AR documents each print as one
  A4 page; long EN/AR documents print as seven/five A4 pages. All 96 authored
  test lines per language and final skill text are retained. Long names/links
  wrap without clipping. These are offline print fixtures, not PDF export.
- Reviewed host-native Career/builder captures and canonical EN/AR header
  comparisons. Only Career and builder Steps 3/6 golden references changed.
- Existing Phase 1 ARM64 APK retained with SHA-256
  `88e58035b912ddb43208ace1ee947e1ef3f89cf880851982c0a7074ec08315c5`.

Canonical comparisons are reproducible with
`dart tool/render_resume_fixtures.dart <output-directory>` from the native app
directory; only synthetic, explicitly labelled fixture data is used.

### Approval/readiness gates still open

**Development gate resolved:** the owner approved
`lmouxhbjhtqdtiqijcee` and supplied `JOBIX_DEV_DATABASE_URL` through the secure
form. No credential value was printed or committed.

- `python3 tool/apply_volunteer.py` passed read-only target, verify-full TLS and
  installed-contract checks. The pre-existing scoring, snapshot and mutation
  bodies matched the approved baseline.
- `python3 tool/apply_volunteer.py --apply-approved-dev` applied only the
  additive Volunteer migration. In-transaction exact comparisons proved that
  all existing profile, AI, wallet and idempotency rows were unchanged.
- The protected live transaction passed Volunteer CRUD/replay/conflicts,
  ownership and actual Supabase role/RLS checks, malformed-input rejection,
  legacy paid 30 + 15 qualification and Volunteer non-credit/latch/allowance
  invariants. Synthetic test Auth/app/credit rows were rolled back.
  No disposable local Auth schema or role fixture was applied to Supabase.
- Historical acknowledgement preservation was checked during migration;
  same-key replay was checked live. Replay of a pre-migration response lacking
  the Volunteer array was separately verified in the disposable local suite.
- `python3 tool/check_volunteer_http.py` confirmed anonymous HTTP Volunteer
  reads and mutations are denied with permission code `42501`. No rows were
  exposed or written. This is not authenticated SDK/phone journey proof.
- A subsequent read-only target/contract check passed against the installed
  Volunteer wrapper and unchanged previous implementations.
- Only the explicitly authorized development target was used. No staging,
  production, product Auth configuration, old migration or AI operation changed.

1. **Native acceptance/signing:** no Android device is attached and the
   previously used debug keystore is absent. No new key, signed APK or phone
   installation was generated. Recover the correct signing key or obtain
   explicit approval for an alternative test arrangement; do not uninstall
   or clear existing M31 data to bypass an update-signature conflict.
2. Actual Android WebView appearance, authenticated SDK/phone Save/edit/delete,
   phone restart and device-specific lifecycle behavior remain unverified until
   that gate is resolved. Host tests/Chromium/live SQL are not substitutes.

No later phase or supporting-service repair was started.

## Fresh Samsung M31 ARM64 development APK — 2026-10-08

After the native bug-fix phase, the owner explicitly approved installing the
missing Android build tools, accepting SDK licenses and recreating the ignored
development build settings. This removes the earlier APK-build setup blocker;
it does **not** establish real-phone runtime acceptance.

- Built the merged native bug-fix source at
  `12af109219041d7a667c2ca88aa382bf382c32ee`, without product code,
  Auth/Supabase/RLS, dependency-version or supporting-service changes.
- Installed Android command-line tools 12.0, platform 36, build tools 35.0.0,
  NDK 27.0.12077973 and CMake 3.22.1 into ignored workspace storage. Gradle
  also installed platform 34 for an existing plugin's build requirements.
- Restored locked Flutter/Dart packages and recreated only the ignored
  `config/dev.local.json` using the existing public development settings.
  `dart tool/check_foundation.dart config/dev.local.json` passed.
- Successful command, with workspace-local Android SDK and Gradle cache:

  ```sh
  flutter build apk --debug --target-platform android-arm64 --split-per-abi \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `deliverables/jobix-m31-native-bugfix/jobix-m31-arm64-dev.apk`.
  Size: **97,399,913 bytes**. Package: `com.mhflow.jobix`. Version: 1.0.0 (1).
  Minimum Android API: 24 (Android 7.0). Target/compile API: 36.
- Packaged native code is ARM64 only (`arm64-v8a`), including Flutter and
  SQLCipher. `apksigner verify` passed with APK Signature Scheme v2.
- APK SHA-256:
  `88e58035b912ddb43208ace1ee947e1ef3f89cf880851982c0a7074ec08315c5`.

### Signing continuity warning

No previous debug keystore existed in this workspace. The new build has a
new debug signing certificate:
`7c16b8b1283ed20a73b25ac595152ec5b9df55ed3de6db08aa467ecb9d2380be`.
It differs from the previously archived builder APK's certificate
`109e7d8f025f4999cd084c8a1841aca199344a515d9482b52fa192617f326f6b`.

If that earlier build is installed on the phone, Android will reject an
in-place update with this new certificate. **Do not uninstall Jobix or clear
its data to bypass the conflict.** Recover the original signing key, or obtain
separate approval for another safe testing arrangement. The earlier APKs and
archives remain unchanged.

The new APK has not been installed or launched on the Samsung M31 by the agent.
The original phone crash, physical/predictive Back and WebView behavior still
require actual phone testing. This is a development/debug APK, not a production
release or publication.

## Native bug-fix phase — 2026-10-08

**Status: BLOCKED / PARTIALLY VERIFIED.** The approved five-bug native changes
are implemented and host-verified. Real Android acceptance remains open. This
is not a claim that the reported opening-time phone crash has been reproduced
or fixed on Android.

### Reproduction and lifecycle evidence

- Flutter 3.32.0 host widget test, using an existing Arabic/NATIVE language
  fixture: open its Edit menu, change proficiency to FLUENT, Save, reopen the
  editor, then dismiss with system Back.
- Opening and the first Save did not fail in this reproduction. On dismissal,
  the original implementation produced `A TextEditingController was used after
  being disposed`, followed by an overflow and the reported
  `framework.dart:6161` / `_dependents.isEmpty` assertion. The complete pre-fix
  output is retained in `docs/verification/language-dismissal-before.txt`.
- The modal pop-result future completed before route unmount, while the
  caller immediately disposed the controller. The sheet now owns its state
  and disposes the controller at widget teardown. Assertions are not hidden
  or suppressed; dependency versions were not changed.
- The regression now passes for opening, proficiency selection, Save,
  reopening, dropdown dismissal, Stay/Discard, sheet Back and parent Back.
  The owner's original Android opening-time stack is still needed to confirm
  whether it has the same primary failure.

### Implemented boundaries

- Central modern Back handling provides meaningful parent destinations,
  keyboard/modal precedence, reentrancy protection and localized EN/AR root
  exit confirmation. Editor overrides cover loading/error branches and block
  leaving during an active Save. Resume preview Back closes preview state
  before returning to Career; its renderer/configuration is unchanged.
- New repeatable drafts remain editor-only. Back drains queued local writes
  before scoped discard; existing-record edits offer Stay/Discard and retain
  the saved baseline. Explicit Add can resume an interrupted editor-only
  draft without showing it as a saved parent-list record.
- Skill suggestion selection only edits the input. Explicit Add/submit commits
  a skill. Language edits use explicit Save; Back does not submit them.
- Unknown Save outcomes retain their exact frozen outbox request and explain
  that an already-sent Save cannot be undone by Back. Parent-list navigation
  does not automatically replay it; explicit Retry remains available.
- Empty/whitespace optional prose is quiet. Non-empty short prose receives
  quality guidance only after explicit Save activity or saved reopening.
  Existing field limits and completeness calculations remain unchanged.
- Only the Country/City leading icons were removed. Suggestions, clear
  controls, selection and existing field behavior remain in place.

### Completed local checks

- Locked Dart/Flutter packages restored with `dart pub get --enforce-lockfile`,
  after explicit owner approval. `pubspec.yaml` and `pubspec.lock` are unchanged.
- `flutter analyze`: **PASS, no issues**.
- Full `flutter test --reporter expanded`: **PASS, 195 tests**. Includes EN/AR
  narrow layouts, all seven existing repeatable editor patterns, delayed local
  write/discard, unresolved Save preservation, explicit skill submission,
  modal/dropdown/root Back, keyboard-first Back, error-state Back and busy Save.
- A final saved-empty-description check also passes in both the parent list
  and Review. Review's descriptive badge is separated from server completeness;
  its existing golden and edit-navigation checks still pass.
- `dart tool/check_foundation.dart`: **PASS**.
- `bash tool/test_rls.sh`: **PASS**, disposable local PostgreSQL only, not live
  Supabase. No migration, schema, Auth, RLS or remote configuration was changed.
- Three golden baselines were updated only for the requested Country/City
  icon removal and replacing the obsolete Save & Continue Later control with
  Back. The final full suite compares successfully against those baselines.

### Remaining native gate and preserved work

The current workspace lacks the Android SDK directory and the ignored native
development define file. An authorized Android device/emulator and required
development configuration were not supplied for this phase. No SDK/tooling was
installed, APK rebuilt/installed, live account used or Android launch performed.
Physical IME/gesture/predictive Back and the actual Android language-edit crash
remain unverified; Resume WebView native Back also needs device acceptance.

Earlier ARM64 build evidence below and existing distribution APK/ZIP files are
preserved as historical results, not builds of these changes. Supporting
Node/browser/API services, their dependencies, Auth flows, Supabase/database/RLS,
scoring, architecture and later feature phases remain outside this work.
No Git reset, rebase, force push or history rewrite was performed. Stop here;
no new or archived follow-up task is started.

## ARM64 review build and Android access check — 2026-10-07

- Recreated the ignored development-only `config/dev.local.json` from the
  approved public workspace settings. `dart tool/check_foundation.dart
  config/dev.local.json` passed. Staging and production remain unconfigured.
- Installed Google command-line tools 12.0, Android platform 36, build tools
  35.0.0, NDK 27.0.12077973 and CMake 3.22.1 under ignored workspace storage.
  Android licenses were accepted; Flutter reports the Android toolchain ready.
  Flutter's license check emitted a non-fatal SDK XML version warning.
- `flutter pub get` passed. From `mobile/jobix`, this ARM64 development build
  passed:

  ```sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug --target-platform android-arm64 --split-per-abi \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`
  (97,380,913 bytes), package `com.mhflow.jobix`, version 1.0.0 (1), minimum
  Android API 24, target/compile API 36. The packaged Flutter engine is ARM64.
  APK signature verification passed using APK Signature Scheme v2.
- SHA-256:
  `5b91498893ed9467c2b9c56c1c8b03ba9a58af3cf112f4d354c68099d155d2b7`
- **Physical-device acceptance remains blocked.** `adb devices -l` returned no
  Android devices and Flutter lists only the Linux host. No installation or
  Android launch occurred. Signup email delivery/callback, Keystore-backed
  persistence, Career Profile editing and Resume preview therefore remain
  unverified on a phone. An authorized Android device and, for signup, an
  owner-approved test inbox are still required. An APK build is not device
  verification.
- No product code, database, RLS, Auth settings, staging or production settings
  were changed.

## Real-flow development verification — 2026-10-05

### A. Verified live

- `tool/live_builder_flow_test.dart`: actual Flutter screens against development
  Supabase (no fake Auth/Profile/Core APIs). Confirmed test-account sign-in,
  real startup policy, one stable Profile #1 across repeated reads, six-step
  Continue/Back flow, personal/summary saves, saves in all seven entity sections,
  multiple experience entries, invalid-month Save rejection without a server
  mutation, confirmed experience deletion, Review → Edit → Save → Review, and
  Career using the same profile.
- A successful real mutation acknowledgement was deliberately dropped by the
  host transport. SQLCipher was closed/reopened, the app/providers/SDK recreated,
  and the session recovered. The persisted outbox replayed the original key:
  server version stayed unchanged and each created item appeared exactly once.
  This is host app reconstruction, not Android process-death verification.
- Temporary items were deleted and original personal information, Resume
  Language, summary and existing items restored. The first fake-clock harness
  run required restoration from prior server acknowledgements; the final
  real-time-binding pass completed and verified its own cleanup.
- `tool/live_dev_redesign_test.dart`: confirmed Auth, SDK recovery/startup policy
  and denied direct policy-table access passed.
- `tool/live_profile_sections_test.dart`: live replay, VERSION_CONFLICT,
  VALIDATION_FAILED, DUPLICATE_ITEM, owner B isolation and deletion passed;
  temporary items removed, completeness and Credits unchanged.
- Development Auth configuration was read from the Management API:
  email enabled, signup enabled, confirmation required, built-in mailer,
  two emails/hour and native callback allowlisted. No settings were changed.

### B. Verified with host tests/mocks only

- Full default Flutter suite: 145/145 passed; analyze clean; foundation
  client-secret/layout/token/config checks passed.
- English/Arabic invalid-month draft → Back → disk close/reopen → Edit
  regressions cover experience, education, certification, achievement and
  project drafts. Month labels preserve invalid/incomplete input without a crash.
- AR/EN/RTL layouts, empty states, stale-draft choices and exhaustive Review
  section navigation are covered by host tests, not a physical Android device.
- Live UI test session storage is memory-only. SQLCipher is real disk storage;
  Android Keystore and native App Links are not supplied by this host harness.

### C. Fixed during this verification

- Month formatting now checks the range before indexing localized month names.
  Invalid persisted drafts remain visible/editable; Save validation remains strict.
- Added the opt-in real-network Flutter UI/restart/fault-injection regression.
  It uses a real-time binding and private temporary restoration snapshots.
- No redesign, new features, architecture changes, RLS changes, auto-confirmation,
  external SMTP, AI/model evaluation, staging or production work.

### D. Still requires the Samsung and an authorized inbox

- No connected Android device, installed emulator or `/dev/kvm` is available.
  An APK build is not an installation/launch/runtime test.
- Fresh Sign Up → delivered confirmation email → confirmation callback →
  Sign In → first-registration Step 1 has NOT been verified end to end.
  Existing confirmed accounts work, but that is not proof of new-user delivery.
- Supabase's built-in mailer sends only to project-team addresses, at the current
  two-email/hour limit. The management credential cannot read organization/team
  membership (HTTP 403); no inbox integration is available. An owner-approved
  unused team-member email and owner access to its inbox are needed. Do not use
  an assumed plus alias, auto-confirm, disable confirmation or add external SMTP.
- On the Samsung: install/launch, fresh confirmation link, actual force-stop
  and relaunch, Keystore-backed recovery, offline/interrupted saves,
  native Back/keyboard/scrolling and Arabic RTL must still be checked.
- Official mailer restrictions:
  https://supabase.com/docs/guides/auth/auth-smtp

### Development APK

- Built ARM64 debug APK, package `com.mhflow.jobix`, version 1.0.0 (1),
  minimum Android API 24, target API 36; APK Signature Scheme v2 verified.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.
- Download: `build/verification/jobix-dev-arm64-debug.zip`. Extract first.
  Archive integrity passed. Raw APK exceeds the Library file-size limit.
- SHA-256:
  `545e012cff5ed3fe5ef9604a93a049045a947396a9405690bd8bef9a9d48fe67`.
- Exact command in this workspace:

  ```sh
  cd mobile/jobix
  source /tmp/jobix_env.sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug --target-platform android-arm64 \
    --split-per-abi --dart-define-from-file=config/dev.local.json
  ```

- Existing `config/dev.local.json`, Flutter/JDK/Android SDK and accepted licenses
  are present here. Outside this workspace, supply the genuine development
  configuration and equivalent build toolchain; never put privileged/test-user
  credentials in Dart defines.
- On the computer connected to the Samsung, after extracting the download:

  ```sh
  adb install -r app-arm64-v8a-debug.apk
  adb shell am force-stop com.mhflow.jobix
  adb shell monkey -p com.mhflow.jobix -c android.intent.category.LAUNCHER 1
  ```

  If installation reports a signing mismatch, do not uninstall or clear app
  storage without first preserving data and agreeing on that destructive step.

### E. Exact next recommended task

Samsung acceptance of this development APK, using a fresh Supabase-team-authorized
email: complete signup/confirmation/first entry, all six steps, Review editing,
force-stop/session recovery and offline-save recovery. Fix only observed native
issues. Volunteer Experience and other feature work remain subsequent tasks.

## Screenshot-inspired onboarding update — 2026-10-03

Only the three existing native Flutter introduction screens were revised using
the owner's newly supplied CV, AI-assistance and export/update screenshots.
Approved copy, Skip/Back/Continue behavior, persisted progress, language
switching and the four-question boundary are unchanged. Illustrations are
static, text-free and excluded from accessibility semantics; they do not
introduce AI/export actions, fictional CV facts or unsupported ATS claims.

- `flutter analyze --no-pub`: no issues.
- `dart tool/check_foundation.dart`: passed.
- Ordinary `flutter test --no-pub --reporter expanded`: **88 tests passed**,
  including normal golden comparisons after refreshing only onboarding
  baselines. Four added regressions exercise English/Arabic at 320×568 and
  800×1280 with 1.6 text scaling, reachable fixed Continue, and ordered entry
  into research. Existing auth/profile/draft tests remain passing.
- Actual Flutter English/Arabic renders were visually inspected. Contact
  sheets are `build/review/jobix-onboarding-en.png` and
  `build/review/jobix-onboarding-ar.png`, not physical-device screenshots.
- Development ARM debug APK rebuilt with genuine existing dev defines:
  `build/app/outputs/flutter-apk/app-debug.apk`, 166,618,451 bytes.
  SHA-256: `644df21326c6c011886fe10664798f1fab63340b01b70b07e6b6a4ea4b86a508`.
- APK v2 signature verification passed. Its signing certificate matches the
  previous delivered APK; no uninstall or deletion of local data is required.
- `build/review/jobix-onboarding-debug.zip` contains the unchanged
  `app-debug.apk`, 75,475,988 bytes compressed. ZIP integrity and extracted
  APK hash equality passed.
- No dependencies, localization copy, research/auth behavior, architecture,
  database, provider/policy settings, staging or production were changed.

Physical installation, device rendering and native lifecycle/security acceptance
remain unverified; prior separately recorded live-service evidence was not
rerun or replaced by these widget renders.

## Current delivery — original native redesign, 2026-10-03

The owner's resumed brief supersedes earlier blocked audit/HTML-matching status.
See [VISUAL_REDESIGN_REPORT.md](VISUAL_REDESIGN_REPORT.md) and
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Older sections below are historical
evidence, not current font/icon/policy status.

### Passed

- Final `flutter analyze --no-pub`: no issues.
- Final ordinary `flutter test --no-pub --reporter expanded`: **84 tests passed**,
  including normal comparisons against refreshed visual baselines. Actual
  SQLCipher is used for persistence tests.
- `dart tool/check_foundation.dart`: credential, directional-layout and shared
  design-value checks pass; `git diff --check` has no whitespace errors.
- Real isolated-dev smoke test: **1 live test passed**. Public Auth settings
  Google=true; signed-out startup performs no policy request; confirmed real
  password sign-in, SDK memory-adapter persistence/recovery and authenticated
  startup pass. Authenticated policy RPC returns owner-approved dev
  1.0.0 / 1.0.0 / 1; direct policy-table read remains denied.
- Development-only policy configuration uses the existing protected psql
  mechanism and certificate/hostname-verified TLS. No schema, RLS, production,
  staging or Auth-provider settings were changed.
- English/Arabic 320×568 and 800×1280 research, at 1.6 text scale, retain reachable
  final rows and all four ordered questions. 402×874 renders cover all current
  redesigned flows; a simulated 300px IME inset retains reachable Auth submit.
  Language switching, empty fields, validation, semantic error relocalization,
  App/Resume independence, draft preservation and navigation guards pass.
- ARM debug APK rebuild succeeds with true dev defines, package
  `com.mhflow.jobix`, version `1.0.0+1`, min SDK 24, target/compile SDK 36.
- APK signature verifies (v2); signing certificate matches the prior review
  APK, so no destructive uninstall is requested.
- APK contains approved unchanged brand masters, real Inter and four Noto Sans
  Arabic weights/glyphs plus OFL license. Android/iOS launcher resources use the
  approved icon, replacing Flutter defaults.
- Packaged Flutter engines are ARMv7/ARM64. Other plugin libraries include
  x86/x86_64, but no Flutter engine for those ABIs is packaged; **emulator/x86
  execution is not claimed**.
- Review ZIP integrity passes and the extracted APK hash equals the output APK:
  `3da0dc7ed03916797f9ba2849c1200dc88a5502628f201261d5a05295e32468b`.
- Output APK: `build/app/outputs/flutter-apk/app-debug.apk`
  (166,593,924 bytes). Compressed unchanged package:
  `build/review/jobix-dev-debug.zip` (below the delivery size limit).
- **31 full-size redesigned-flow widget renders** and labelled contact sheets
  delivered in `build/review/`; actual rendered PNGs were visually inspected.

### Explicitly not passed / release dependencies

`adb devices` has no connected device. The owner supplied Galaxy M31 /
M315F/DSN / Android 12 and older problem captures, but no new physical evidence
for this rebuilt APK. Physical installation, Samsung keyboard/system splash,
touch feel, process-death recovery and Keystore acceptance remain unverified.
No simulated capture or debug build is described as physical-device acceptance.

Real Google browser OAuth, email confirmation/recovery delivery and external
deep-link/device lifecycle are not verified by settings flags or test fakes.
Native iOS/Xcode/Keychain verification is unavailable. No confirmation, guard,
session or RLS bypass was introduced.

Terms/Privacy URLs and operational production policy require approved pre-launch
configuration. These were not implementation blockers for this explicitly
authorized development redesign. No next feature slice was started.

## Physical-device visual review — access check, 2026-10-03

**Subsequent owner evidence:** Ten physical-device screenshots were supplied.
They show native launch/initialization, all three English introductions, English
and Arabic Q1, Auth gateway, a signup error and startup failure. The owner later
identified Galaxy M31 / M315F/DSN / Android 12. Q2–Q4, selected states, keyboard
behavior and Personal Information were not established by those old captures.
The owner changed visual strategy to an original
Flutter design system; see [VISUAL_REDESIGN_AUDIT.md](VISUAL_REDESIGN_AUDIT.md).
At audit time, read-only dev checks confirmed Auth health/settings HTTP 200,
email/Google enabled, email autoconfirm disabled and zero operational `mobile`
policy rows. The later explicit dev-only configuration above resolves that gap.
Missing policy is a confirmed authenticated-startup blocker; without device
logs the precise captured exception is not established. No remote changes,
guard bypass, UI implementation or device rerun occurred during this audit.
Review/redesign remains incomplete pending brand/legal inputs and policy
remediation authorization. The initial access check below predates the captures.

**Owner clarification:** Approved logo/icon masters are now supplied but not
integrated. The review device is Samsung M315F/DSN (Galaxy M31), Android 12.
Terms/Privacy URLs remain a documented pre-launch dependency. The owner requires
stopping at missing policy values, with no database/policy/migration changes.
The absent `mobile` policy lacks required `minimum_supported_version` and
`policy_version`; `recommended_version` is optional. No values were invented,
no guard was bypassed, and no new implementation or device rerun is claimed.

- `adb devices -l` returned an empty device list. No physical Android device
  is accessible from this workspace, and no owner-provided device captures or
  observations have been supplied for this review.
- The existing review ZIP and original APK are present at the paths below.
  No installation, native launch or interactive visual inspection was performed.
- The previously documented absent operational `mobile` policy and unverified
  email/Google provider setup remain review limitations; their live state was
  not rechecked or changed. Startup/authentication guards were not bypassed.
- Review is **blocked, not complete**. Physical-device evidence is needed for
  introduction, Q1–Q4, authentication and reachable Personal Information,
  English/Arabic direction, independent App/Resume Language, initial empty
  fields, touch targets, keyboard, scrolling and navigation. An observed issue
  must precede a minimal authorized UI fix and a device rerun.
- No UI/product, architecture, database, provider/policy, staging or production
  change was made. Build/signature/widget evidence is not device acceptance.

## Physical-Android review APK — 2026-10-03

Development/debug build only, explicitly authorized for visual review.

- Installed Android SDK/build components and accepted their licenses. Flutter
  doctor reports a healthy Android toolchain. No emulator or replacement
  Expo/React Native/Linux application was created.
- Restored ignored dev configuration from existing workspace public settings.
  `dart tool/check_foundation.dart config/dev.local.json` passed. No new
  credentials or staging/production configuration was created.
- The first default debug build requested an unavailable legacy x86 profile
  engine artifact. The successful build explicitly targets physical-device
  ARM CPUs. Pinned Android NDK 27.0.12077973 to satisfy the existing native
  plugins instead of the older wrapped-Flutter default.
- Successful command, from `mobile/jobix`, with the workspace-local Gradle cache:

  ```sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug \
    --target-platform android-arm,android-arm64 \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-debug.apk`
- Download archive: `mobile/jobix/build/review/jobix-dev-debug.zip` (73,958,679
  bytes), containing the unchanged `app-debug.apk`. ZIP integrity checked.
  The raw APK exceeds the Library's 100 MiB upload limit.
- Size: 143,700,892 bytes. SHA-256:
  `700ce05a9443b41b10ed6c400d4ee53852ab3fc5c9042a5417d6652ebf967fc7`
- `apksigner verify --verbose`: passed, APK Signature Scheme v2.
- Package `com.mhflow.jobix`, version 1.0.0 (1), debuggable, minimum API 24,
  target/compile API 36. Flutter engines are present for ARMv7 and ARM64;
  other ABI plugin libraries do not imply x86 emulator support.
- No product flow/UI, architecture, schema, migration or remote database changes.
  The standard three-environment build script is unchanged and was not used
  for this specifically authorized development-only review build.

**Not verified:** installation/launch on a physical device, native keyboard,
Keystore/session restore and the full interactive Auth/Profile journey.
The documented operational-policy/provider prerequisites are not bypassed or
changed by producing an APK. No production/staging build or release acceptance
is claimed. Earlier missing-toolchain/build statements below are historical;
remaining native-device acceptance gates still apply.

## HTML/product correction — 2026-10-03

Completed only the requested first-slice revision. No next feature, server
migration, live database write, environment/configuration change or original
HTML edit was made.

- `flutter gen-l10n`, `dart format lib test`, `flutter analyze`: passed;
  analyzer reported **no issues**.
- `dart tool/check_foundation.dart`: public-client secret, directional-layout
  and token checks passed. `git diff --check`: passed.
- Final `flutter test` without `--update-goldens`: **68 tests passed**.
  This includes 20 first-slice contract tests and 15 widget tests, plus the
  existing Foundation tests.
- New regressions cover every incomplete first-time stage and direct Auth,
  Login, confirmation/reset URLs; Skip remains introduction-only.
- Rendered-content assertions cover all three English introduction pages,
  research, empty Personal and mixed-language Personal; they reject fictional
  identities/location/contact claims and the named unsupported ATS/marketing
  claims. The approved ATS-friendly headline remains.
- Empty Personal controllers/server snapshots are asserted for all eight
  fields. Displaying the EG suggestion and saving Resume Language alone sends
  no Country or other personal values. Accepting Egypt explicitly creates only
  a draft until another explicit Save.
- Resume changes preserve content/App Language. App Language changes preserve
  Resume Language, CV labels and user content.
- Disposable local PostgreSQL Foundation/slice RLS/RPC/bootstrap checks passed.
  The empty-bootstrap assertion now covers **all eight** personal fields,
  plus null Profile name and Resume Language. No live checks were repeated.
- Regenerated and visually inspected native-widget goldens: all three
  onboarding pages; all four English research pages; Arabic research;
  empty English Personal (a tall all-section test render); mixed English
  App/Arabic Resume Personal. Existing Auth/Home baselines also still pass.
  A 320px phone/1.6x text check passes. These are test renders, not device captures.

Exact source adaptations and remaining HTML differences are recorded in
[FIRST_SLICE.md](FIRST_SLICE.md#deliberate-differences-from-the-original-html).
The provider configuration, operational policy, native build/device/security
and full location-catalog gates below remain unverified/unchanged.

## First vertical slice — 2026-10-03 (pre-correction evidence)

This is the separately authorized feature slice; it supersedes the historical
Foundation-only scope below, not the remaining native acceptance gates.
See [FIRST_SLICE.md](FIRST_SLICE.md) for source authority, implemented
contracts, minimal Architecture V2 patches and visual handoff limitations.

### Passed in the current checkout

- Flutter localization/Drift generation and dependency resolution.
- `flutter analyze`: **no issues**.
- `flutter test`: **65 tests passed**, including the 19 new contract and
  13 new native-widget journey tests. That run compared goldens normally,
  without `--update-goldens`; no screenshot mismatch or layout error.
- Actual SQLCipher encrypted v1→v2 migration, settings preservation, repeated
  singleton onboarding writes, restart/readback, account-scoped drafts,
  offline retention and offline acknowledged-cache use.
- Atomic research ownership/command writes reject a stale snapshot, a
  switched account or signed-out caller. Context cannot be assigned to a
  different account during a delayed response.
- Three-screen order/Skip, ordered four-question research retention and Q4's
  maximum, confirmation guards, Google/reset boundary calls, returning Home,
  new-registration Personal entry, Save & Continue Later and safe Discard.
- Sign-out explains that local unsaved work is removed but acknowledged
  server data remains; cancelling it preserves the draft.
- Unknown-outcome retries use the same frozen command after further edits;
  version conflicts do not silently overwrite, and non-network failures never
  fall back to an old acknowledged Profile.
- Mixed English App/Arabic Resume labels and direction without content
  translation; optional custom city/history selection; 320px phone and
  1.6× text navigation; native goldens for onboarding, research, auth, Home
  and Personal Information.
- `dart tool/check_foundation.dart`: public-client secret, directional-layout
  and token checks passed. `git diff --check` passed.
- Disposable local PostgreSQL Foundation + slice checks: Auth-trigger
  bootstrap, exactly one empty Profile/slot/personal record per new account,
  no Resume-language default, duplicate prevention, anonymous denial, owner
  isolation, lifecycle exclusion, partial saves, idempotent replay,
  payload-mismatch rejection, version conflicts and first-entry claim isolation.

### Live isolated-development SQL

Applied the two source migrations, in order, using the server-only protected
session-pooler credential, the uploaded public CA and verified TLS:

- `202610030002_first_vertical_slice.sql`
- `202610030003_registration_entry.sql`

The target was checked against the already authorized isolated development
project. Staging/production were not contacted or changed. The existing
Foundation schema was required, not replaced.

The real Supabase PostgreSQL roles and `auth.uid()` passed the slice bootstrap,
RLS and save/retry checks. First-entry routing is server-authoritative:
new identities can claim first entry once; returning identities cannot be
misclassified solely by choosing a Signup or Login button. Anonymous callers,
other owners and inactive accounts cannot claim another user's state.
SQL fixtures were inserted only inside a rollback transaction and removed
by rollback; no new persistent Auth account or profile test data remains.
No operational app-policy version was seeded.

These are **live SQL** results, not real Google/email provider round trips,
native deep-link, Keystore/Keychain or new PostgREST/SDK journey results.
Historical Foundation live HTTP/session evidence below remains separate.

### Still unverified / unavailable

- The previously supplied, ignored public dev client config file is absent
  in this checkout and must be restored from genuine settings.
- Staging/production public settings remain NOT_CONFIGURED. The three-project
  native build gate is preserved; no APK/IPA or release build pass is claimed.
- Supabase Google provider configuration, confirmation enforcement/mail
  delivery, reset emails and native redirect allowlisting/round trips.
  The required redirect is `com.mhflow.jobix://auth/callback`.
- Foundation recorded the operational `mobile` policy as absent; no slice
  migration creates it. Authenticated startup remains fail-closed without
  an administrator-approved policy.
- Physical Android/iOS device storage, process death, backups/device transfer,
  native RTL/locale/deep-link behavior and macOS/Xcode/CocoaPods.
- Full approved location autocomplete catalog; only account history/custom
  input is implemented. No dataset was invented or downloaded.
- Final separate visual frames for confirmation/recovery/conflicts;
  these use minimum structural UI with the accepted shared styling.
  Research HTML frames exist and are used by the correction above.

The source-tested slice is implemented; the unavailable native/provider gates
are not certified. Do not interpret this as production readiness.

## Final disposition — 2026-10-03

The user accepted the successful live Supabase verification and authorized
closing this verification task with the remaining unavailable prerequisites
recorded as **environment blockers**. This closes the authorized work, not the
unverified native acceptance gates. No native build or device pass is claimed.

### Exact environment blockers and unverified checks

| Environment blocker | Checks that remain unverified |
| --- | --- |
| Genuine staging and production public Supabase configuration is unavailable; both remain `NOT_CONFIGURED`. | The existing three-distinct-project build gate stops Android before compilation. No Android APK build is verified. |
| No macOS runner with Xcode and CocoaPods is available. | iOS dependency installation, Xcode validation, compilation and native integration are unverified. |
| No physical Android device is available. | Android Keystore-backed session persistence across process death, immediate sign-out after real cold-start restore, native SQLCipher wrong/missing-key behavior, backup/device-transfer exclusion, locale restoration, RTL and native startup guards are unverified. |
| No physical iOS device is available. | iOS Keychain-backed session persistence across process death, immediate sign-out after real cold-start restore, native SQLCipher wrong/missing-key behavior, backup/device-transfer exclusion, locale restoration, RTL and native startup guards are unverified. |

Do not create or invent staging/production projects or credentials to satisfy
these gates. Staging/production configuration remains unchanged. Do not bypass
the build gate or substitute fake credentials, simulated native verification,
browser results or in-memory SDK results for genuine native evidence.
Further verification requires the actual missing prerequisites and separate
authorization; no feature, UI or architecture work is authorized.

### Persistent migration and data disposition

- The authorized Foundation migration remains applied to isolated **dev**:
  `public.users`, `public.app_policies`, their RLS/grants and
  `public.read_app_policy(text)`. It was not reverted or reapplied.
- SQL test rows were rolled back. Temporary live-verification Foundation user
  and policy rows were removed, and their absence was confirmed during the
  successful run. No operational minimum-version policy remains seeded.
- The user-supplied disposable Auth accounts remain; setup/test sessions were
  revoked. The harness did not create or delete those Auth accounts.
- No staging/production migration or data change occurred.
- `supabase/tests/local_auth_fixture.sql` was never deployed to Supabase.

Finalization changes documentation only. Earlier successful results below are
retained without repeating live writes or claiming unavailable native checks.

### Files changed during this verification work

Source/documentation/configuration inventory, excluding generated Flutter
outputs and installed SDK/cache files:

- `mobile/jobix/README.md`
- `mobile/jobix/VERIFICATION.md`
- `mobile/jobix/tool/live_supabase_test.dart`
- `mobile/jobix/tool/verify_live_supabase.py`
- `mobile/jobix/android/app/build.gradle.kts`
- `mobile/jobix/android/app/src/main/kotlin/com/example/jobix/MainActivity.kt`
  (removed during the approved package relocation)
- `mobile/jobix/android/app/src/main/kotlin/com/mhflow/jobix/MainActivity.kt`
  (approved package relocation)
- `mobile/jobix/ios/Flutter/AppFrameworkInfo.plist`
- `mobile/jobix/ios/Podfile`
- `mobile/jobix/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/jobix/config/dev.local.json` (ignored public dev configuration)
- `.replit` (authorized tooling setup)
- `attached_assets/0_prod-ca-2021_1791007607421.crt` (uploaded public CA)
- `.agents/memory/MEMORY.md`
- `.agents/memory/database-network-access.md`
- `.agents/memory/native-tooling.md`
- `.agents/memory/policy-rpc-compatibility.md`
- `.agents/memory/jobix-authority.md`

This finalization changes only `mobile/jobix/VERIFICATION.md` and
`.agents/memory/jobix-authority.md`. The existing migration source and local
auth fixture are unchanged; staging/production configuration is unchanged.

## Local verification — 2026-10-02

Executed from the Linux workspace:

```sh
JOBIX_SQLCIPHER_LIBRARY=/nix/store/j6vh2fybrzqqac8fkhwdd2dzvk539ql2-sqlcipher-4.6.1/lib/libsqlcipher.so \
  bash mobile/jobix/tool/verify.sh
```

Result: exit status 0.

- Dependency resolution, localization and Drift generation passed.
- Public-client secret, directional-layout and design-token checks passed.
- Flutter analysis reported no issues.
- All 33 Flutter tests passed.
- SQLCipher 4.6.1 exercised encrypted database creation/reopening, wrong-key
  rejection, missing-key rejection and locale persistence on Linux.
- The real Supabase SDK restoration/sign-out test passed with synthetic session
  data, in-memory secure-storage replacement and fixture HTTP transport.
- Disposable local PostgreSQL checks passed for anonymous denial, owner
  isolation, deleted-account exclusion, authenticated policy RPC access,
  direct policy-table denial and client mutation denial.

These results do **not** verify Android Keystore, iOS Keychain, device backups,
device transfer or live Supabase Auth/PostgREST. Expected SQLCipher
wrong-key diagnostic errors were emitted during the passing negative test.

## Saved configuration checks

After the workspace configuration was supplied:

- `dart tool/check_foundation.dart config/dev.local.json` passed. The ignored
  dev file contains only public client configuration.
- Static checks confirmed the Android namespace/activity/application ID,
  compile/minimum/target API levels, all three iOS app and test bundle IDs,
  all project deployment targets, Podfile and Flutter framework minimum OS,
  and package version agree with the approved values.
- `git diff --check` passed.

These checks do not claim native compilation. No staging/production local
configuration was generated from the `NOT_CONFIGURED` markers.

## Remaining acceptance gates

| Requirement | Current evidence / blocker |
| --- | --- |
| Approved application identifiers, OS targets and build version | Supplied through workspace configuration: `com.mhflow.jobix` on both platforms, Android minimum API 24 / target API 36, iOS 13.0, version 1.0.0. Applied to native build settings; native compilation remains unverified. |
| Public dev/staging/prod Supabase configuration | Public dev configuration supplied. Staging and production explicitly marked `NOT_CONFIGURED`. Three distinct project hosts are still required by the build gate. |
| Android SDK and APK build | SDK platform 36, build tools 34/35, NDK 26.3.11579264, CMake 3.22.1 and command-line tools 16.0 installed. Build command stopped at missing staging configuration before compilation. No APK verified. |
| iOS validation/build | User confirms no macOS runner is available. No iOS build verified. |
| Native session persistence and immediate cold-start sign-out | Fixture and live real-session SDK restart/sign-out checks pass with in-memory storage. Native devices are still required to verify Keystore/Keychain and actual process restarts. |
| Native SQLCipher wrong/missing-key behavior | Linux tests pass; native library/storage integration remains unverified. |
| Backup and device-transfer exclusion | Platform configuration exists; actual backup/transfer behavior remains unverified. |
| Native locale restoration, RTL and startup guards | Local tests pass; native device execution remains unverified. |
| Live Supabase migration and isolation/RPC checks | Passed: authorized migration, real-role SQL RLS tests, anonymous HTTP denial and authenticated PostgREST isolation/safe RPC checks with two real Auth accounts. |
| Live minimum-version enforcement and session restoration/sign-out | Passed against live dev Auth/RPC with the Foundation startup guard and in-memory session adapter. Temporary policy removed; native startup/storage remains unverified. |

## Safety boundary

Full Foundation/native verification requires evidence for every remaining gate.
The user-authorized task closure above does not certify those blocked gates.
Do not substitute a browser/desktop result for native verification.
Never deploy `supabase/tests/local_auth_fixture.sql` to Supabase.
Only `supabase/migrations/202610030001_foundation.sql` is the application
migration, and applying it requires explicit authorization for the isolated
development project. Flutter accepts only public publishable/anon client keys;
never put service-role/admin credentials into client configuration.

No later feature slice is authorized by this verification work.

## Authorized setup and live connectivity — 2026-10-03

- User authorized Android SDK license acceptance and installation.
- User confirmed the configured dev project is isolated and authorized the
  existing Foundation migration only.
- User stated that no macOS runner or Android/iOS physical devices are
  currently available. `adb devices` also reported no attached devices.
- Public-key requests to the configured dev project returned:
  - `/auth/v1/health`: HTTP 200.
  - `/rest/v1/users?select=id&limit=1`: HTTP 404, `PGRST205`.
  - `/rest/v1/rpc/read_app_policy`: HTTP 404, `PGRST202`.

The latter responses report missing API resources, not proof of database
schema absence or successful RLS enforcement. Administrative schema inspection
is required before applying the migration. No remote SQL, user creation or
policy writes were performed by these connectivity probes.

## Android setup result — 2026-10-03

The workspace package installer supplied `android-tools` and the standalone
SDK manager after rejecting the nested Nix Android SDK package attribute.
SDK packages were downloaded from Google's repository. The install was moved
to ignored workspace toolchain storage after home-directory quota exhaustion;
the incomplete NDK install was replaced and its package metadata checked.

- Flutter detected platform 36 and build tools 35.0.0.
- SDK manager 16.0 runs successfully.
- Build-tools `aapt2 version` runs successfully.
- NDK package metadata and CMake executable are present.
- Authorized `android-sdk-license` acceptance was recorded for installed
  packages. Six unrelated SDK license agreements remain unaccepted; Flutter
  reports this warning.
- Latest command-line tools 23.0 now use Android CLI in place of SDK manager.
  They were removed from the active SDK so Flutter 3.32.0 uses tools 16.0.
- `bash mobile/jobix/tool/build_android.sh dev` failed at
  `config/staging.local.json` because staging/production are not configured.
  No native compilation occurred. The build gate was intentionally retained.

SDK discovery and executable checks are not an APK build or device test.

## Dev database connection check — 2026-10-03

The server-only database URL was supplied through workspace Secrets. Its
connection target matched the authorized isolated dev project and public dev
configuration. Neither its value nor password was displayed or embedded in
Flutter.

Read-only connection attempts failed before database authentication. Network
diagnostics confirmed the direct endpoint resolves only to IPv6, and TCP
connection failed with `EAFNOSUPPORT` in this workspace. Administrative schema
inspection, migration application and live SQL/RLS verification were therefore
unexecuted at this stage. A session-pooler connection URL on port 5432 was
required. The password had not yet been validated, because no database
connection was established. Subsequent pooler and verified-CA checks below
resolved this blocker.

## Replacement session-pooler check — 2026-10-03

The replacement secret passed the authorized-project and port checks. TCP
reachability and PostgreSQL authentication succeeded using `sslmode=require`.
Read-only schema inspection confirmed:

- Existing Supabase `auth.users`: present.
- Foundation `public.users`: absent.
- Foundation `public.app_policies`: absent.
- Foundation `read_app_policy(text)` RPC: absent.

The backend `pg_stat_ssl` flag was false; through a pooler, this describes the
pooler-to-database connection, not the TLS client-to-pooler connection.
`sslmode=require` does not validate the server certificate or hostname.

A separate certificate-validating client handshake failed with
`CERTIFICATE_VERIFY_FAILED` (self-signed certificate in chain). Administrative
writes were paused before reading/applying migration SQL. The public Supabase
server root/CA certificate from the authorized project's dashboard is required
to verify this connection. No migration, test inserts or policy writes occurred
before the CA was supplied and verification succeeded, as recorded below.

## Authorized migration and live RLS — 2026-10-03

The public CA certificate supplied from the isolated dev project enabled
client-to-pooler certificate and hostname validation with TLS 1.3.
PostgreSQL administrative calls used `sslmode=verify-full` with that CA.

The existing `202610030001_foundation.sql` migration was applied to the
authorized isolated development project after checking that Supabase Auth
exists and that the Foundation objects do not already exist. The migration
transaction included a precondition guard and transaction-level advisory lock
to prevent accidental reapplication or overwriting an existing schema.

`supabase/tests/rls.sql` then passed against the real Supabase roles and
`auth.uid()` function. Only rollback-only test rows were inserted; the local
auth schema/role fixture was never read, applied or deployed to Supabase.

Passing checks:

- Anonymous SQL cannot read users or invoke the policy RPC.
- Authenticated owners see only their own non-deleted user row.
- Deleted accounts are excluded.
- Authenticated policy RPC access succeeds; raw policy access fails.
- Client user/policy mutations are denied.
- Both Foundation tables have RLS enabled.
- The RPC is security-definer with an empty search path and does not project
  private `configuration`.
- Follow-up queries confirmed no Foundation user rows, policy rows or temporary
  auth test rows remained after the test transaction rolled back.
- Anonymous PostgREST user query: HTTP 200, empty result.
- Anonymous direct policy query and RPC: HTTP 401, `42501`.

These are live SQL/RLS and anonymous HTTP checks, not proof of authenticated
HTTP behavior, real Auth session restoration, minimum-version startup guards,
or native secure storage. The live Auth/HTTP gates were subsequently checked
below; native acceptance gates remain open.

## Live Auth, authenticated API and SDK verification — 2026-10-03

Two distinct, disposable, email-confirmed dev Auth accounts were supplied
through workspace Secrets. Both password sign-ins succeeded. The opt-in
`tool/verify_live_supabase.py` harness then created temporary Foundation user
rows and a test-only `mobile` minimum-version policy, refusing to overwrite
existing rows. Administrative calls used the verified dev session pooler;
Flutter received no database/admin credential.

Passing live checks:

- Each real JWT can read exactly its own Foundation user row, and cannot read
  the other account's row through PostgREST.
- Direct policy-table access is denied; client user insert/update/delete and
  policy update requests are denied with PostgreSQL permission errors.
- Authenticated RPC returns exactly the four public policy/version fields,
  never the private test configuration.
- The real Foundation startup orchestration blocks approved build version
  `1.0.0` against temporary live minimum `2.0.0`. A test caller at version
  `2.0.0` is permitted; this does not change the approved package version.
- A missing live policy fails closed. The installed SDK can surface HTTP 406
  for an empty RPC `maybeSingle` result rather than returning null; either
  explicit failure prevents startup.
- A genuine Auth session is persisted through `SecureSessionStorage`, then
  refreshed against live Auth and restored after SDK disposal/reinitialization.
- With implicit recovery deferred, explicitly awaited restoration completes
  before sign-out. Immediate sign-out clears current/persisted session state
  and receives successful live server logout.
- The revoked refresh token is rejected by live Auth; no delayed recovery
  resurrects the session.
- A later SDK restart remains signed out, and the signed-out startup guard
  makes no policy request.
- Temporary Foundation user/policy rows were removed and their absence
  confirmed. Setup/test sessions were revoked; supplied Auth accounts remain.

The harness uses a memory-only `SecretStore` across SDK instances. This is not
process-death persistence or Android/iOS secure-storage proof. Database opening
is a test port here, not native SQLCipher verification. Native cold starts,
backup/transfer exclusion, encrypted storage, locale/RTL and device startup
still require the unavailable native runners/devices. No staging/production
resource, product feature, or operational policy was created.