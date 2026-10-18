# Prioritized continuation plan

No dates are assigned. Every live operation remains separately approval-gated.

## Phase 0 — Preserve baseline

**Entry:** before any change. **Tasks:** capture branch/status and latest commit; preserve user files; read this handover and current diffs; verify dependencies with lockfile. **Evidence:** source commit, clean/dirty state, hashes where needed. **Exit:** no unknown changes overwritten; no untracked attachment deleted.

## Phase 1 — Resolve existing PDF download incident

**Entry:** latest diagnostic build available and one completed export exists. **Tasks:** download one existing item once; copy safe diagnostic; correlate Edge invocation, Gateway/Worker and Storage GET logs; read operation/Credit state narrowly; fix only the proven failing stage. **Tests:** focused Dart/native save tests plus regression for `download` never invoking `create` or mutating Credits; Android physical PDF save/open and free re-download. **Exit:** saved bytes validated and opened on device; job remains completed; exactly one prior debit; no extra export/charge.

## Phase 2 — Authorization, database and service audit

**Entry:** incident not masking a broader auth issue; owner-approved non-production access. **Tasks:** current checksums/ledger, RLS, grants, two-account ownership, deletion/quiescence, signed URL scope, private Worker IAM, service identity and gates. Verify migration 022 before layout save use. **Tests:** local disposable PostgreSQL + approved Development tests with explicit scope. **Exit:** no cross-user access; service privacy/gates confirmed; no ambiguous holds; evidence timestamped.

## Phase 3 — UI, persistence, navigation and localization

**Entry:** Phase 1 stable. **Tasks:** inspect every route in `UI_UX_AUDIT.md`; verify dirty-state messaging, offline/retry, Arabic RTL, keyboard, semantics, back handling, screen sizes. **Tests:** focused widget/golden, integration and physical device. **Exit:** route matrix completed; no major defects or silent data loss.

## Phase 4 — AI implementation decision

**Entry:** product owner approves provider, use cases, privacy and budget. **Tasks:** design server-side generation, safe prompts/output schema, consent/review, quotas/reservations, retries and telemetry. **Tests:** abuse, prompt injection, timeout/duplicate, no automatic profile overwrite, cost limits. **Exit:** provider and privacy evidence accepted; generation flag only opened under approved rollout.

## Phase 5 — Monetization and advertising

**Entry:** product decision on actual Credit purchase/ads. **Tasks:** platform billing verification/refunds/restore, ad consent/privacy and test-mode setup if chosen. **Tests:** interrupted purchase, duplicate callbacks, refunds, cross-account restore and regional disclosures. **Exit:** server ledger reconciles with provider; no mocked purchase represented as real payment.

## Phase 6 — Integration, reliability, security and operations

**Entry:** core user journeys implemented. **Tasks:** network loss, retries, timeouts, stale app, load/concurrency, deletion, storage, crash/ANR, alert, rollback and incident drills; independent threat review. **Tests:** full relevant local suite once after coherent changes, disposable backend, physical device matrix. **Exit:** critical scenarios pass; rollback and alerting rehearsed.

## Phase 7 — Production and Google Play

**Entry:** all earlier exits documented; separate explicit owner approval. **Tasks:** verify Production target and parity, migration plans, secrets/IAM, data disclosures, release signing, app bundle, Play Console requirements and staged rollout. **Tests:** signed release artifact metadata, Play internal testing and production smoke with approved data. **Exit:** owner accepts risks and approves release. Never infer testing-policy requirements; inspect the actual Play Console account.

### Immediate next action

Collect the safe diagnostic JSON from a single failed download of an already-completed Development PDF on the newest diagnostic APK. Do not trigger a new export. This is the smallest action that distinguishes network/object delivery from Android picker/write/save failure.
