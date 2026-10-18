# Production release gates

**Decision: NO-GO.** Production state, permissions, migration ledger, feature gates, service revisions, billing attribution and store signing have not been verified. Development Export was last reported enabled by the owner; that is not Production authorization or readiness evidence.

| Gate | Current evidence | Required before Production |
|---|---|---|
| Auth/account recovery | Source and tests; earlier owner sign-in report | Fresh device verification of registration, login, confirmation, recovery, logout/account switch, callback and key-loss behavior. |
| Profile persistence/isolation | Versioned RPCs, encrypted local drafts, repository tests | Two-account tests for all profile/extras/section paths and account deletion; verify current RLS/policies. |
| Local Preview | Local snapshot/renderer, tests; separate POC physically tested | On-device integrated flow with all fields, links, order/visibility, unsaved confirmation, Arabic RTL and no implicit save. |
| Export generation | Server validation, Worker, reservation/recovery code; prior one success | Resolve current download issue first; one separately approved staging/Development run with authoritative snapshot/hash/version, valid private object, exact one 2-Credit debit and recovery evidence. |
| Download/save/open | Prior owner-confirmed success, later repeated Android failures | Obtain sanitized diagnostic, prove Storage GET, bytes/hash, SAF save and PDF opening on supported physical devices; test cancel/low storage/provider failures and free re-download. |
| DB migrations | Checked-in 001–022; owner previously confirmed 021 on Dev | Read-only ledger/checksum verification on every target. Migration 022 is explicitly local-only in its header; apply only with separate approved procedure and validated rollback/recovery. |
| Edge/Gateway/Worker | Historical Dev revisions and images reported ready/private | Fresh read-only target identity, digest/revision/Ready, config comparisons, JWT and Invoker checks, Worker privacy, probes, IAM, secrets names only; rollback plan. |
| Export gates/costs | Owner reported Dev enabled using estimates; no fresh remote inspection | Keep Production closed until rates, residual costs, accounting readiness and operating controls are evidence-backed/approved. Do not claim $10 hard cap. |
| GCS/data retention | Historical bucket config and source | Verify private access, location, retention/soft-delete, lifecycle, egress, deletion verification, backups and privacy retention disclosures. |
| Security/privacy | Source review only | Independent threat review, current RLS/IDOR tests, dependency/SAST audit, privacy and data-deletion validation; none is claimed complete here. |
| AI | `generation_enabled=false`, no generator found | Product/provider/privacy/cost decision, implement, test and disclose before advertising. |
| Store/release | Debug APK exists; Gradle release currently uses debug signing config | Create owner-controlled release signing, secure CI, version strategy and verified AAB. Review current Play Console account-specific testing/policy, target API, data safety, privacy, permissions, ads/IAP declarations. No account-specific policy is verified here. |
| Operations | Limited attribution; no fresh monitoring review | Alerts for failed jobs/downloads, reservations, stuck flights, reconciliation, recovery, error budgets, backups, incident/rollback rehearsal. |

## Mandatory approval sequence

1. Resolve and verify Development download/save behavior on existing completed documents, with no extra export.
2. Verify current Dev schema/gates/deployment and migration 022; complete focused regression tests.
3. Complete account isolation, security/privacy, recovery, Arabic, accessibility and device matrix in a controlled non-production environment.
4. Assemble evidence-backed costs and provider usage; owner approves rates/budget and accepts residual-cost limits. Keep accounting and feature gates closed until this passes.
5. Prepare Production configuration and release only after separate explicit approval, exact target verification, backup/rollback plan, release signing and store review.

No item here authorizes a deployment, migration, live export, gate change or Google Play submission.
