# Known issues and unknowns

Priorities are operational, not a substitute for issue tracking. No live service was queried for this handover.

| ID | Priority / severity | Status | Evidence / reproduction | Next diagnostic / exit condition |
|---|---|---|---|---|
| JX-01 | P0 / High | BROKEN, root cause UNKNOWN | Owner reports existing completed History PDFs fail on Android. Generic message says Android could not confirm complete save. Two supplied records completed, 154,591 bytes, no DB error; Storage GET query had no rows. | On the latest Development debug APK, use one existing completed job and copy sanitized `JOBIX_PDF_DOWNLOAD` data. Correlate Edge/Gateway/Worker/Storage only for that job. One local successful save/open required before close. |
| JX-02 | P1 / High | UNKNOWN live rollout | Migration 022 introduces `save_resume_layout`; header says local-only/separate approval. No live ledger read in this task. | Owner-approved read-only Development check for version/checksum/function/grant; if absent, do not assume layout-order save works. |
| JX-03 | P1 / High | UNVERIFIED | Last owner-reported Dev PDF enablement/revisions are historical; no current gate or configuration query. | Verify target identity, effective Edge/db gates, accounting policy, service images/config/private IAM before operations. |
| JX-04 | P1 / High | NOT READY | Production gates/schema/revisions/IAM/secrets/billing not verified. Development reports do not transfer to Production. | Keep Production closed until all `PRODUCTION_READINESS.md` gates have evidence and explicit approval. |
| JX-05 | P2 / Medium | PARTIAL | AI allowance exists but migration returns `generation_enabled=false`; no provider generation path found. | Treat AI generation as unavailable until separately designed/implemented and privacy/cost tested. |
| JX-06 | P2 / Medium | NOT_IMPLEMENTED | No ad SDK or in-app payment/subscription implementation found. | Do not advertise top-up, ad reward, or subscriptions; require product/payment approval. |
| JX-07 | P2 / Medium | UNVERIFIED | Current PDF cost inputs are engineering estimates, not per-export measured provider charges; rounded $0.00 usage and project-wide CSV cannot attribute costs. | Reconcile seven-day aggregate GCP/Supabase usage; document uncertainty; do not claim admission policy caps invoice. |
| JX-08 | P2 / Medium | UNVERIFIED | Physical Arabic output, Android save provider variability, process death, low storage and repeated downloads not verified by mocked channel tests. | Focused test matrix after JX-01; Arabic test data and device reports. |
| JX-09 | P2 / Medium | UNVERIFIED | `localPreview` package suffix differs from auth repository callback scheme. | Test link-based auth on Local Preview; use standard Development package for current integrated export tests unless config is intentionally aligned. |
| JX-10 | P3 / Low | UNKNOWN | Checkout is 66 commits ahead of origin; exact remote branch/LFS payload parity not checked in this handover. | Preserve local history; before handoff, compare commit graph and LFS objects with owner-approved remote; do not push/rewrite automatically. |

No source inspection here established a separate confirmed exploitable security vulnerability. The table distinguishes reported product failure, missing verification, and absent feature.
