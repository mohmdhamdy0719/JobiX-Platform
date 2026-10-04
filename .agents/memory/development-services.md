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