---
name: Development service boundary
description: Owner-provided development infrastructure scope and unverified provisioning claims
---

The owner identifies Google Cloud project `mhflow-jobix`, region `me-central1`,
private PDF bucket `mhflow-jobix-dev-pdfs`, and Artifact Registry `jobix-dev`
as the Jobix development resources. The owner reports Vertex enabled,
backend and Cloud Scheduler service accounts provisioned, and AdMob app/rewarded
unit provisioned. Cloud Run deployment and final Scheduler configuration were
reported pending. These are owner reports, not proof of usable deployment access.

**Why:** The owner supplied these non-secret resources for the complete native
Jobix MVP and explicitly retained Architecture V2 and development-only safeguards.

**How to apply:** Verify real authenticated access and actual resource settings
before deployment or claiming service readiness. Keep deployment identity
separate from runtime backend/Scheduler identities; never assume their roles
authorize deploying. No credentials, fabricated service success, client-granted
Credits or fake rewarded-ad verification. Do not substitute unrelated storage
or AI providers, deploy into another project, or create staging/production
resources to bypass missing access.

## Owner-selected development configuration

The owner approved the Phase 2 Volunteer migration and isolated live checks
on the existing Jobix development Supabase project `lmouxhbjhtqdtiqijcee`.

**Why:** The owner selected "Approve development migration and isolated live
checks" for that explicitly identified development target.

**How to apply:** Verify the installed baseline and use certificate-validated
secure administrative access before applying only the additive Volunteer
migration. Preserve existing profile, completeness and AI states. Keep live
fixtures isolated and reversible; never apply disposable local Auth/role
fixtures to Supabase, replay older migrations, change Auth configuration or
touch staging/production to bypass missing access.

“Development only. Use Supabase's built-in email service for now. Do not
configure an external SMTP/Resend provider yet. Production email delivery will
be configured later with a verified Jobix domain.”

**Why:** The owner explicitly overrode the external-SMTP recommendation for the
development phase.

**How to apply:** Keep email confirmation required and unverified sign-in
disabled. Do not request or configure external email-provider credentials to
unblock development. Built-in-mailer testing needs an owner-approved recipient
authorized by the project team; do not present it as unrestricted public signup
readiness, auto-confirm accounts, or weaken verification.

The owner supplies backend runtime account
`jobix-backend-dev@mhflow-jobix.iam.gserviceaccount.com` and Scheduler account
`jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com`, approves creating the
development Docker repository `jobix-dev` in `me-central1`, and selects Vertex
default model `gemini-3.5-flash`, intentionally accepting higher cost for better
Arabic quality. The owner approves the global inference
endpoint; the worker and PDF storage remain in `me-central1`.

**Why:** The owner explicitly selected these non-secret identities, repository
creation and subsequently replaced the model preference and approved global
inference. See [AI model selection](ai-model-selection.md) for the hard requirements.

**How to apply:** Do not substitute identities/models, move infrastructure out
of `me-central1`, or broaden IAM grants without approval. Global approval applies
to model inference, not moving the worker/storage or other infrastructure.

The owner scopes the deployer account's Service Account User grant specifically
to `jobix-scheduler-dev@mhflow-jobix.iam.gserviceaccount.com`, providing
`iam.serviceAccounts.actAs` on that account.

**Why:** The owner resolved Scheduler readiness with a resource-specific grant,
not a broad project-level Service Account User role.

**How to apply:** Preserve this grant's account-level scope. Report a specific
missing permission before requesting additional IAM access; do not broaden the
Scheduler grant to unblock unrelated deployment requirements.

## Vertex evaluation identity and IAM boundary

Use the existing backend runtime identity for Vertex evaluations, not duplicate
Vertex grants to the deployment identity. The owner reports that the backend
already has `roles/aiplatform.user`; verify actual inference rather than treating
that report as proof of access.

**Why:** The owner explicitly requires the existing backend identity and minimum
necessary permissions, with no broad Owner, Editor or unrelated project grants.

**How to apply:** Before any IAM change, tell the owner the exact caller/prediction
identity, exact proposed role, resource scope and whether it is temporary/removable.
Try existing backend access first. If access fails, report the exact principal and
missing permission before requesting another role. Keep credential-minting access
distinct from Vertex prediction access; do not change unrelated infrastructure.

Supabase management credentials may have endpoint-specific scopes. Successful
project metadata access does not prove access to Auth configuration, Auth logs
or Edge Functions. Check the actual endpoints before declaring access ready,
and request only the missing scopes rather than unrestricted account access.

**Why:** A valid development credential passed the project guard but the
protected endpoints rejected it for missing `auth_config_read`,
`analytics_logs_read` and `functions_read` scopes.

**How to apply:** Auth diagnosis requires Auth configuration/log reads; Edge
deployment additionally requires function read/write authorization. Do not
replace tokens unnecessarily or bypass the restriction through client credentials.
For Google Cloud, distinguish `SERVICE_DISABLED` from
`IAM_PERMISSION_DENIED`; project metadata inspection is not itself a runtime
deployment requirement. Do not request broader IAM roles just to list
service-account identities when the owner can supply their non-secret names.

Positive runtime permission checks are not sufficient to approve least-privilege
IAM. Also check unwanted permissions and actual resource-level role bindings.
Keep managed builder, deployer and runtime identities separate.

**Why:** Development upload/signing checks passed while predefined grants also
permitted unnecessary object mutation/restoration and token/JWT delegation.

**How to apply:** Verify the approved permission set and absence of excess
permissions under the actual runtime identity. Report scope corrections;
preserve unrelated bindings and do not substitute a runtime identity for a
builder just to bypass a missing actAs grant.

Backend invocation access does not prove Scheduler invocation access. Verify
the recovery job with its own OIDC identity and exact service audience, and
capture failed execution status before pausing a newly created failing job.

**Why:** Backend live access passed while Scheduler returned PERMISSION_DENIED;
pausing then replaced the job's observable status code with -1, so a later
metadata read did not preserve the original execution failure.

**How to apply:** Keep invocation grants service-scoped and identities separate.
Record execution evidence before pausing; do not interpret the paused status
as a successful run or broaden IAM to bypass failed recovery.

Supabase's older `logs.all` API is retired. Current programmatic log reads use
`/analytics/endpoints/logs`, the unified `logs` table, ClickHouse SQL and
`log_attributes` rather than the old separate tables/BigQuery metadata format.
Use explicitly bounded UTC windows under 24 hours and inspect query errors.

**Why:** The retired endpoint returned HTTP 410 after valid log authorization;
the replacement successfully returned Auth records. Twelve-hour windows with
second-precision UTC `Z` timestamps worked for the development project.

**How to apply:** Consult the current Management API schema before retrying old
examples. Process sensitive records inside a protected runtime; expose only
error codes, counts and non-personal structural flags. Never persist raw Auth
log records in memory or deliverables.