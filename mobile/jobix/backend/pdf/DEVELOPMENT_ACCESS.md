# Development rollout access — operator action required

All resources below are **development only** in `mhflow-jobix`. Do not grant
Owner/Editor, create service-account keys, alter production/staging, or reuse
the deployment/admin database credential in the application.

## Observed blockers

- Managed Cloud Build submission: HTTP 403.
- Custom storage-role creation: HTTP 403.
- Runtime-secret creation: HTTP 403, `secretmanager.secrets.create`.
- Backend bucket permission test: none of create/get/list/delete.
- Backend self-signing permission test: no `iam.serviceAccounts.signBlob`.
- Deployer has no tested `iam.serviceAccounts.setIamPolicy` on the backend.

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
