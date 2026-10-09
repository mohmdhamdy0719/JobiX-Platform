# Development export authentication bridge

Local implementation only. Deployment is blocked by the first security run:
71/72 tests passed; the cross-account/inactive-account check expected FORBIDDEN
but returned SERVICE_UNAVAILABLE. The owner requires stopping at test failure.
No cloud service, service account, IAM binding or image was created.

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
