# Development rollout access — operator action required

All resources below are **development only** in `mhflow-jobix`. Do not grant
Owner/Editor, create service-account keys, alter production/staging, or reuse
the deployment/admin database credential in the application.

## Current runtime checkpoint

**Latest Gateway rollout preflight: BLOCKED.** The private worker has the
expected gateway `roles/run.invoker` member. The account-scoped deployer
effective-permission test returned no actAs/get/getIamPolicy/key-list
permissions; account and account-policy reads are denied. The supplied
`jobixGatewayAttach` role definition is not readable with the current deployer,
so its exact binding cannot be verified. Cloud Build/Run project permissions,
worker update/IAM-policy permissions, worker-runtime/builder actAs, Artifact
Registry access, and build-source bucket create/get passed the checks.

The actual worker currently reports both `JOBIX_EXPORT_ENABLED=true` and
`JOBIX_EXPORT_DELETION_POLICY_APPROVED=true`. These were not changed; this
conflicts with the deployment requirement to keep export gates disabled.
Stop deployment until the account-scoped role binding is effective and the
worker flags are disabled. No cloud changes were made by this audit.

**Latest: gateway worker invocation binding verified; deployer actAs missing.**
The worker policy now contains unconditional Run Invoker for the exact gateway
member and remains IAM-private without public bindings. Direct account-scoped
permission testing confirms deployer actAs is absent. Deployer metadata/policy
reads also fail with 403 for iam.serviceAccounts.get/getIamPolicy on the new
account. Its metadata email/status and full account policy remain unverified,
although the worker-binding member string matches exactly. Missing attachment/
audit permissions belong only to the deployer on that account, not to gateway
runtime/project-wide access. No grants/roles/keys/builds/deployments/flags changed.
The owner's creation report and verified invocation binding supersede earlier
absent-account/create-denied checkpoints below.

**Latest actual setup blocker: account creation denied.** Lookup found no
`jobix-export-gateway-dev`. The explicitly authorized creation request under
the existing deployer returned HTTP 403 / IAM_PERMISSION_DENIED for
`iam.serviceAccounts.create` on `mhflow-jobix`. No account, key, grant or other
cloud mutation succeeded. This is now the concrete provisioning blocker;
resulting policies/attachment permissions remain unverified. Administrator
execution of the already-approved resource-specific setup avoids broadening
the deployer with Owner/Editor/IAM Admin.

**Latest audit: Resource Manager is ENABLED; caller IAM now blocks the audit.**
Project-scoped permission testing succeeded but returned no permissions from
the tested provisioning/audit set for `jobix-deployer-dev`. Account creation
and project IAM-policy read were not granted at project scope; actual project
`getIamPolicy` returned 403. Worker edit permission, account-scoped attachment
and reusable custom-role audit were not reached. No mutations were applied.
Use administrator-scoped setup or explicitly approved exact audit/provisioning
permissions; do not broaden to Owner/Editor/IAM Admin. Earlier API-DISABLED
observations below are historical and resolved.

**Latest read-only recheck:** the owner authorized Resource Manager API, but
Service Usage still reports `cloudresourcemanager.googleapis.com` as DISABLED
in the approved development project. No API activation or other mutation was
performed. Dependent caller-permission/project-policy auditing remains blocked.
Cloud Run documents that a custom role granting actAs can attach the identity;
an existing exact role must be audited before reuse. Creating a new custom-role
definition is a separate resource/approval question, not an implicit standard
Service Account User grant. Report the completed audit before making changes.

**Latest provisioning blocker: pre-change audit API is disabled.** Before any
account/IAM mutation, project-scoped Resource Manager `testIamPermissions`
returned HTTP 403 / Google reason `SERVICE_DISABLED` for
`cloudresourcemanager.googleapis.com`. No account or binding was created.
API activation is outside the owner's account/grant-only approval and was not
performed. Administrator/separate approval for development API activation is
the smallest next step, then recheck inherited policies and scoped capabilities.
Do not infer IAM_PERMISSION_DENIED or grant broader roles from this response.
The existing `roles/iam.serviceAccountUser` definition includes metadata reads
as well as actAs; no role was applied and no extra permission was assumed
approved. New-account effective attachment permission remains unverified.

**Latest readiness blocker: missing dedicated bridge identity and invocation
grant.** Read-only lookup of `jobix-export-gateway-dev` returned 404; the private
worker has no Run Invoker binding for it. The planned bridge service is also
absent (404). Provision only the approved dedicated identity and worker-scoped
invocation grant after explicit cloud-change approval; verify deployer actAs
and effective runtime permissions before deployment. No resource/grant/build/
deployment was applied during this check.

The earlier Supabase Management metadata-read blocker is now resolved: both
development `/secrets` and `/functions` reads return 200 with the existing
credential. Successful response bodies were cancelled without secret inspection.
No credential/scope was changed. Those reads do not establish Edge write/deploy
access and do not block Cloud Run bridge runtime/deployment. An existing local
public client key is available and the Auth endpoint rejects invalid tokens.
Worker IAM remains private and anonymous invocation is denied with 403.

**Latest checkpoint: local bridge security suite passes; cloud work not resumed.**
The owner authorized a local-only correction. The failing fixture omitted the
canonicalizer and threw before database authorization; its uncoded error was
correctly mapped to SERVICE_UNAVAILABLE. Supplying that test dependency and
adding explicit denial/outage assertions resolves the original failure.
Targeted test passed, then the complete suite passed **75/75**. No production
authorization/error mapping changed. These are local/mock checks, not live
deployment/integration proof.
No bridge service/account/IAM binding/build/deployment exists from this work.
Existing runtime resources are unchanged; export/client flags were not enabled.
Deployment/live integration remains unverified. The readiness checkpoint above
supersedes the old metadata-access failure below. Local security success does
not authorize cloud configuration or deployment without the requested approval.

**Current actual rollout blocker: development gateway metadata access HTTP 403.**
Backend invocation passes and the actual pinned worker is active on ready
revision `jobix-dev-pdf-export-00002-bpb`, preserving backend identity, Secret
version 1, CA and private invocation enforcement.

After the administrator's Scheduler correction, resumed the existing
`jobix-dev-pdf-export-recovery` job and verified its actual invocation:
canonical RPC **0 / OK**, `2026-10-08T19:34:28.589778Z`. The existing job is
`ENABLED`, every minute, with Scheduler OIDC and exact service audience.
No duplicate was created and no IAM grant was added.

Next, `GET /v1/projects/lmouxhbjhtqdtiqijcee/secrets` at the Supabase
Management API returned **403** under the existing development credential.
Stopped; function inventory/database flag read were not reached. Remote gateway
identity configuration could not be verified. Local Edge source contains only
an optional key-backed adapter, not an implemented keyless transport.

Administrator/owner action: authorize scoped access to the rejected development
metadata endpoint and establish an approved, verifiable keyless gateway-to-private
worker identity mechanism. Do not create keys, reuse deployer credentials,
substitute end-user JWTs as Google service authority, add project-wide/public
invocation or disable the IAM check. Gateway deployment, export enabling and
billable end-to-end verification remain unperformed. No agent IAM change or
real Credit transaction occurred.

The earlier requested runtime binding was verified **READY in read-only mode** on
private service `jobix-dev-pdf-export`, `me-central1`. Secret version 1 and the
bundled verified CA are resolved inside the actual hosted runtime. Its
authenticated readiness response confirms restricted database authentication
and all required function privileges; unauthenticated calls are denied and
dispatch is disabled. No IAM grant, credential rotation, Secret creation or
migration was performed for this configuration step.

The administrator's signing correction has since passed actual backend
effective-permission checks: signBlob alone, with deployer impersonation
preserved. The earlier access denials/excess grants below are historical.
Normal worker/export activation and subsequent rollout are not part of this
read-only configuration authorization.

## Observed blockers

After the operator's access update:

- Build submission and builder actAs now succeed. The managed image was built
  and pushed to the approved repository, pinned at
  `sha256:670a21879bd42deae556d2208b83571e5c0d145c10a58c51423027956412347d`.
  An isolated managed-image check passed English/Arabic canonical generation,
  pinned Chromium PDF/text/font validation and invalid-PDF rejection. A first
  fixture-only attempt used a day-date instead of the logical YYYY-MM month;
  correcting the fixture and rerunning passed without changing product code.
- Deployer secret metadata-get/version-add and backend version-access now pass.
  The previously empty secret holds a newly provisioned restricted development
  LOGIN. Actual backend secret retrieval and verified-TLS connection passed;
  membership is exactly gateway/worker, no superuser/create-db/create-role/
  replication/RLS-bypass, no direct export INSERT or user UPDATE.
- Remaining blockers below supersede the earlier build/secret access denials:
- Backend object create/get/list/delete and self-signBlob are effective. Actual
  backend-identity production-adapter tests passed conditional create/read,
  self-signing/private signed download, signed-generation tamper rejection and
  exact-generation fixture cleanup. Cloud Run metadata identity and actual
  worker PDF generation remain unverified.
- Earlier Cloud Build inventory/default-builder lookup succeeded, but submission
  was denied because the deployer could not act as the selected builder:
  `850519041397-compute@developer.gserviceaccount.com` (reported account unique
  ID `112247149794458910320`). Grant only `iam.serviceAccounts.actAs` to
  `jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com` on this builder
  account, or configure an existing approved least-privileged builder.
- Supplied resource `projects/850519041397/secrets/jobix-dev-export-database`
  is confirmed to reference the approved project number. Earlier neither friendly nor
  numeric resource addressing gives the deployer tested metadata-get/version-add
  permissions or the backend version-access permission; actual backend latest
  version access returned 403. These access denials are now resolved as above.
- Bucket scope is now corrected: the owner-approved removal deleted only the
  backend's obsolete `roles/storage.objectUser` membership. The custom role and
  every unrelated binding/condition/principal were preserved with concurrency
  guards and full policy readback. Effective bucket tests return exactly
  create/get/list/delete; update/restore/move are absent.
- Overall least-privilege scope has **not** passed: signing tests permit signJwt,
  getAccessToken/getOpenIdToken/implicitDelegation. Replace these broad backend
  grants with the exact four storage permissions and single signBlob permission
  specified below, preserving unrelated principals/bindings.

The only agent IAM mutation is the explicitly approved obsolete bucket
membership removal above. Earlier
custom-role/secret creation attempts were denied. The new runtime LOGIN/secret
is approved secure provisioning, not an administrator credential fallback.

The retained bucket role is `jobixExportObjectAccess`; the owner-approved
obsolete backend membership was removed successfully. No objects, retention
rules or other principals were changed. Backend service-account policy read
is still denied; an administrator must narrow signing/token/delegation access.
The owner confirms that signing correction is pending. Do not deploy or activate
the worker while that scope is unresolved.

These require an authorized GCP operator; approval in chat alone cannot change
the existing credential's effective permissions.

## Minimum targeted configuration

1. **Build submitter:** existing
   `jobix-deployer-dev@mhflow-jobix.iam.gserviceaccount.com` needs development
   Cloud Build submit/read access (`cloudbuild.builds.create`,
   `cloudbuild.builds.get`, and listing only if operational inventory is needed).
   Reuse the existing/default managed builder. Verify its image-write access on
   `me-central1/jobix-dev` and source-read access limited to `phase3-builds/`
   objects in `mhflow-jobix-dev-pdfs`; do not give it CV/export-object access.
   Deployer repository upload permission is already verified.

2. **PDF runtime storage:** define/reuse a custom role containing **only**
   `storage.objects.create`, `storage.objects.get`, `storage.objects.list`,
   `storage.objects.delete`. Bind
   `jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com` on bucket
   `mhflow-jobix-dev-pdfs` only. Do not substitute Storage Admin or object roles
   granting unnecessary ACL/update/restore permissions. The attempted role ID
   was `jobixDevPdfObjects`; creation was rejected, so no role/grant was added.

3. **PDF URL signing:** define/reuse a role containing only
   `iam.serviceAccounts.signBlob` and grant it to the backend **on that backend
   service account only**. Do not give the runtime general service-account
   token/key administration or reuse the deployer key.

4. **Runtime database secret:** provision an empty development secret such as
   `projects/mhflow-jobix/secrets/jobix-dev-export-database`, or identify an
   existing approved equivalent to avoid duplication. Grant the deployer only
   necessary metadata-get/secret-version-add access on that secret, and the
   backend only version-access there. The agent can then create/provision a
   restricted database LOGIN with only `jobix_export_gateway` /
   `jobix_export_worker` membership and store its connection securely.
   Do not put an administrator DSN in this secret. Alternatively, an operator
   may securely provision that restricted LOGIN and secret directly; share
   only the non-secret resource ID, never the secret value in chat.

## Subsequent runtime evidence

Cloud Run deployment/invoker, existing Scheduler identity, supported keyless
Edge→private-worker identity transport, runtime CA/secret injection and actual
private worker PDF/signed-download/deletion tests remain to be configured or
verified. Existing actAs/impersonation on the backend and Artifact Registry
access do not prove these separate capabilities.

The source-only private build archive is retained for retry; it contains no
credentials, developer config or user data. Export activation stays off until
the complete development path passes. All supplied public-CA and cleanup
approvals remain in force; no product decision is reopened here.
