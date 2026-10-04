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
model `gemini-3.8-flash`.

**Why:** The owner explicitly selected these non-secret identities, repository
creation and model in the development-settings form.

**How to apply:** Do not substitute identities/models, move infrastructure out
of `me-central1`, or broaden IAM grants without approval. Vertex model selection
does not authorize a different processing location: verify its supported
locations and obtain approval if inference cannot remain in the selected region.

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