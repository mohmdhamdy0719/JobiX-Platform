# Development export authentication bridge

## Actual development rollout checkpoint

Real-user path work now has local authenticated read-only routing for document
preview/history/status while exports remain off. Mutation/signing paths still
fail closed. Local full suite passes 90/90, including two mocked verified
identities and profile/job isolation. This is not deployed/live two-user proof.
Private Gateway IAM currently prevents Edge's Supabase bearer from reaching
the handler, and the Edge function is absent in the development inventory.
The proposal is public invocation only on this independently authenticating
Gateway, never the Worker; await scoped cloud approval before applying it.

Gateway revision `00003-whw` is now Ready after one controlled Gateway-only
deployment of the hostname fix. Authenticated private `/ready` returned 200
and verifies native Gateway-to-Worker authentication plus worker-only path
denials. Eight recorded live checks passed, including invalid application token,
actor overrides and anonymous Worker rejection. Both services remain private,
exports are disabled, deletion-policy approval is preserved and no Credit/PDF
operation was executed. The worker was not rebuilt or redeployed.

Full valid-Supabase-user ingress and two-active-user ownership lookups remain
untested live; actor-override checks do not prove those journeys. The valid
88/88 local suite was reused, not rerun. Earlier failed/local-only checkpoints
below are historical.

The actual configuration failure is now proven: the deployed worker hostname
ends in `.a.run.app`, which the old worker URL regex rejected before metadata
authentication. Worker/gateway URL validators are fixed locally to accept that
explicit managed-host label, retaining all existing safety restrictions.
Focused tests pass 49/49; full tests pass 88/88. No further revision was deployed.
Earlier unknown-cause notes below are superseded; live integration is still
unverified until deployment of this verified fix.

One separately approved private diagnostic revision (`00002-cf9`) is now
deployed from a gateway-only build. It still fails closed at startup; no ready
or public gateway exists. Obtain this new revision's structured stage/code
event using administrator log access, not the old generic log. The worker
was not rebuilt or redeployed by this diagnostic step. No further diagnostic
deployment is authorized by the single-revision approval.

Uploaded logs establish a startup abort but omit its cause because the deployed
catch handler discarded the error. Local code now provides allowlisted
stage/code/status diagnostics while preserving every startup security check
and fail-closed exit. Full suite passes 84/84. This diagnostic fix is NOT
deployed, and the actual runtime startup cause is still unproven. Do not
redeploy without root-cause evidence or explicit diagnostic-only authorization.

The managed gateway image is built and pushed. Cloud Run gateway service exists,
but its first revision failed startup probes; no public invocation was granted.
The new private worker revision is ready with export processing disabled and
approved deletion/retention cleanup preserved. Local suite passes 78/78.
Hosted gateway/worker integration is not verified. Sanitized startup logs are
needed; do not enable exports or blindly redeploy. Historical local-only notes
below do not describe the current cloud resource inventory.

Local implementation only. The original failed security fixture omitted its
canonicalizer and threw before the ownership lookup. Its uncoded exception
was correctly mapped to SERVICE_UNAVAILABLE. The fixture dependency is fixed,
with assertions that authorization runs and unauthorized content never renders.
Targeted test passed, then the full suite passed 75/75, including explicit
invalid-token, cross-account, inactive-account and verification-outage cases.
No production error mapping or authorization was changed. No cloud service,
service account, IAM binding or image was created. Deployment and live
integration remain unverified; local test success is not rollout readiness.

The bridge independently validates users through the fixed development
Supabase Auth endpoint. Parsed JWT claims are rejection checks only; a verified
Auth response must match before an actor is established. Caller actor fields
and identity headers are rejected. Application account state and ownership
remain authoritative in the existing restricted worker/database functions.

The attached Google identity is `jobix-export-gateway-dev`; runtime credentials
come only from Cloud Run metadata. No downloaded Google key, deployer JSON,
database credential, GCS access or Secret Manager access is used by the bridge.
Only the private worker's `/command` path is used. Worker authorization rejects
this identity on recovery, dispatch, cleanup and all other worker-only paths.

The approved deployment must leave both bridge export gates false.
`/ready` describes read-only startup verification: history for an absent actor
must fail as ACCOUNT_DELETING and privileged worker paths must fail as FORBIDDEN.
It does not claim a real authenticated-user or billable export journey passed.

Edge forwards the original user token and exact input body to this bridge,
without generating an actor or changing request/idempotency identifiers.
Timeouts never generate a new logical operation; retries preserve the input.

Proposed resources remain uncreated:
- `jobix-dev-export-gateway`, `mhflow-jobix`, `me-central1`.
- `jobix-export-gateway-dev@mhflow-jobix.iam.gserviceaccount.com`.
- Bridge identity: Run Invoker only on the private PDF worker.
- Public Run Invoker only on the bridge, never on the PDF worker.

No migration, Credit/idempotency, canonical rendering, database role/RLS,
retention/deletion policy, GCS or Scheduler changes belong to this component.
