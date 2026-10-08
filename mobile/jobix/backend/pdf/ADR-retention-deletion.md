# ADR — Phase 3 PDF/export deletion and retention

**Status:** Product decision approved; documentation only.
**Recorded:** 2026-10-08.
**Authority:** Explicit owner approval. This supersedes earlier documentation
that described the deletion/snapshot policy as unresolved.

## Approved contract — recorded exactly

1. Generated PDF objects have a 7-day logical retention period.
2. After PDF expiry, download must fail as expired/missing and MUST NOT silently regenerate or charge again.
3. PDF expiry does NOT by itself require immediate deletion of the immutable export snapshot/canonical HTML.
4. Export Again always creates a new export from current profile data and costs 2 Credits.
5. Profile/account deletion must freeze new export mutations and prevent new work from being created.
6. During deletion:
   - invalidate active export leases,
   - release pending export Credit reservations,
   - prevent late/stale workers from creating or preserving usable objects,
   - remove export-related GCS objects,
   - remove export snapshots and related export data belonging to the deleted profile/account,
   - verify that no active export objects/snapshots remain before deletion is considered complete.
7. Do not introduce any additional retention period beyond the approved 7-day PDF retention unless explicitly approved later.
8. Do not change the existing account/profile deletion contract outside the PDF/export integration.
9. No automatic regeneration after expiry.
10. No production/staging changes.

## Current authorization — recorded exactly

For now:
- Record this decision in the Phase 3 documentation/ADR.
- Update local tests/contracts only if necessary to reflect this exact decision.
- Do NOT run migrations remotely.
- Do NOT deploy.
- Do NOT modify IAM, GCS, Scheduler, Cloud Run, Supabase or live Credits.
- Do NOT start the production worker.

Do not implement or deploy yet.

## Implementation and verification status

Approval settles the product decision, not implementation or rollout readiness.
No implementation, migration, worker start, cloud change or Credit transaction
accompanies this record.

Existing local tests exercise expiry without regeneration/charge, explicit paid
Export Again, reservation release, lease invalidation and generation-aware
cleanup. Existing cleanup fixtures deliberately stop at DELETION_PENDING:
snapshot/related-data purge and its final verification are not implemented.
The current code's `snapshot_policy: APPROVAL_REQUIRED` is an unchanged legacy
placeholder, not a statement that the product decision remains unapproved.
Do not change that code or its fixture expectations under this recording-only
authorization.

Future authorized implementation must distinguish PDF expiry from profile/account
deletion: expiry alone does not require immediate snapshot/HTML deletion;
profile/account deletion must remove its export objects, snapshots and related
export data and verify no active export objects/snapshots remain. It must also
prevent late/stale work from creating or preserving usable objects. No additional
snapshot/history retention period is selected or implied here.

Compatible pinned-browser runtime verification and all separate remote access,
migration, deployment, live-test and rollout gates remain outstanding and closed.
