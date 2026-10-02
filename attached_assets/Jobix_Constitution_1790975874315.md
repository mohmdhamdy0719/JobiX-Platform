# JobiX Constitution V2

**Version:** 2.0  
**Date:** September 19, 2026  
**Status:** Implementation-ready review draft for product-manager and engineering approval  
**Project:** JobiX  
**Scope:** MVP and its implementation process

> This draft consolidates the Constitution with all sixteen resolved architecture decisions. It does not replace the active Constitution until approved and synchronized with Architecture V2, Product Design, DESIGN.md, and the implementation specifications.

## Purpose and Authority

JobiX helps people create, improve, maintain, and export professional career documents while keeping the user's own information as the source of truth.

The governing order is:

1. This Constitution
2. Product Design
3. Architecture V2
4. DESIGN.md
5. Specifications and implementation details

Product Design defines user-visible behavior and business rules. Architecture defines system boundaries and technical structure. Specifications define executable API, database, and state-machine contracts. If a conflict is found, do not resolve it silently in code; document and approve the change.

## Article I — Mission and Priority

When requirements conflict, use this priority order:

1. User safety and data integrity
2. Security and privacy
3. Product correctness
4. Reliability and recoverability
5. Cost sustainability
6. Performance
7. Convenience

No shortcut may violate a higher-priority principle to optimize a lower-priority one.

## Article II — Product Truth and User Ownership

1. User-provided professional information is the source of truth.
2. JobiX must never invent, fabricate, exaggerate, or silently assume achievements, metrics, responsibilities, tools, employers, titles, dates, qualifications, skills, or other personal facts.
3. AI may improve wording, clarity, organization, conciseness, repetition, and professional tone only within the facts provided by the user.
4. Original user content must remain recoverable.
5. AI output is a proposal until explicitly accepted.
6. Product logic must not silently replace user data with AI output.
7. Copy Profile copies accepted current content only. It does not copy AI history, rejected proposals, unused allowance, or generation history.

## Article III — Explicit AI, Quota, and Human Approval

### AI generation quota

The AI generation allowance applies to an explicit action that generates or transforms user-facing content. One logical user action equals one generation, regardless of how many internal model calls are needed.

The following consume one generation when explicitly invoked:

- Improve with JobiX for Summary, Work Experience, or Projects.
- AI-assisted Skills suggestions when they invoke an AI generation.
- Optimize My CV when Premium entitlement exists.
- Professional Email generation.
- Cover Letter draft generation.
- Explicit user-requested translation of Profile content.

A failed request that produces no valid generation must not consume an allowance unit. A retry of the same logical action must reuse the same idempotency key and return or resume the original operation.

Every successful generation preserves source input, output, operation metadata, model/provider metadata, and approval state. Applying, rejecting, or selecting a proposal must be explicit and idempotent.

### ATS is separate

ATS Readiness is a profile-level assessment, not an ordinary AI writing generation.

ATS evaluation:

- may use deterministic checks and AI semantic evaluation;
- does not consume ordinary AI-writing allowance units;
- runs only after an explicit user action or a controlled, documented profile-analysis event;
- must not run on every keystroke, ordinary save, screen open, or background event;
- never blocks Export solely because the score is low;
- stores trigger, Profile version, rubric version, model/prompt version, timestamp, and freshness state.

### Allowance values

- First Profile-building phase: 6 total generations across the entire first Profile journey.
- The first-profile allowance ends when Profile Completeness reaches 50% or higher, using a server-authoritative monotonic transition.
- Unused first-profile generations do not stack with the later daily allowance.
- Free after that phase: 3 generations per user per day.
- Premium: 10 generations per user per day only when a valid server entitlement exists.
- Daily allowance is shared across all Profiles.

### Premium in MVP

Premium billing, purchases, renewals, trials, payment processing, restore flows, and billing UI are outside the MVP. The server may retain a future-ready entitlement model, but MVP users cannot obtain Premium through Credits, onboarding answers, local state, or an invented purchase flow. Premium-only controls must remain unavailable unless a valid entitlement source is added through an approved Product Decision.

## Article IV — Server Authority

The mobile client is never authoritative for security-sensitive or financial-like state.

The server owns:

- authenticated identity and account ownership;
- Credits, credit balance, reservations, and transactions;
- AI allowance, usage, and first-profile transition;
- Premium entitlements;
- Daily Reward eligibility and claim;
- Profile slot entitlements;
- export jobs, history, and generated-file metadata;
- onboarding context after authentication;
- account deletion and app policy/version.

The client must never grant itself Credits, AI generations, rewards, Profile slots, or successful exports.

## Article V — Credit Integrity and Service Rules

Credit rules are server-authoritative, transactional, and idempotent.

| Operation | Credit effect |
|---|---:|
| Initial signup | +5 |
| New Resume PDF export | -2 |
| Cover Letter new PDF export | -1 |
| Professional Email service | -1 |
| Profile 2 unlock | -10 once |
| Profile 3 unlock | -20 once |
| Verified Daily Reward | +2 |
| Existing valid PDF download | 0 |

`credit_transactions` is an append-only immutable ledger during the account lifetime. `credit_reservations` is separate and represents temporary holds, not completed events.

Every credit-consuming operation must define:

- idempotency key;
- reservation creation and expiry;
- successful-charge point;
- definitive failure and release behavior;
- concurrency and negative-balance protection;
- compensating correction behavior while the account exists.

Cover Letter drafting consumes one AI generation and no Credits. A new Cover Letter PDF costs 1 Credit. A valid existing Cover Letter PDF downloads for free.

Professional Email is an MVP service. An explicit generation consumes one AI-generation unit and follows the 1-Credit service rule. Architecture V2 proposes editable text output with the Credit consumed only after valid output is persisted; any additional PDF or history behavior requires Product Design approval. A failed or ambiguous operation does not double-charge, and an idempotent retry returns the original operation.

Resume Export Again is a new export from the current Profile and Resume configuration and costs the normal 2 Credits. The previous export remains an immutable historical snapshot.

### Account-deletion exception

Authorized account deletion removes the user's credit transactions, reservations, rewards, entitlement records, and other account-associated application data. This is the explicit lifecycle exception to retention of the account's ledger rows. Provider backups may temporarily contain deleted data according to documented retention policies; JobiX must not claim immediate physical erasure from immutable backups.

## Article VI — Daily Reward Integrity

1. Daily Reward is +2 Credits.
2. The calendar is fixed to the server's `Africa/Cairo` date for MVP.
3. At first App Open for a date, the server atomically materializes eligibility.
4. Finalized balance below 9 Credits means eligible; reservations do not count.
5. Eligibility is frozen for that date.
6. A user may claim at most once per Cairo calendar day.
7. Rewarded ads require official AdMob Server-Side Verification.
8. Signature, app, ad unit, user, reward, and transaction data must be validated before granting Credits.
9. Duplicate callbacks must be harmless through transaction and idempotency constraints.
10. Offline clients cannot grant or finalize rewards.

## Article VII — ATS Readiness Must Judge, Not Block

JobiX distinguishes Profile Completeness from ATS Readiness. ATS Readiness is not a job-match score, hiring probability, or guarantee of ATS acceptance.

The scoring pipeline uses deterministic checks where possible and AI only for semantic judgment. Students, fresh graduates, and career changers must be evaluated using context-appropriate evidence rather than years of experience alone. Insufficient information should produce an honest unavailable/insufficient state instead of invented confidence.

## Article VIII — Export Correctness and Reliability

Export follows:

```text
Validate
→ Snapshot Profile and Resume configuration
→ Reserve Credits
→ Create durable export job
→ Claim job
→ Generate
→ Store private object
→ Verify and finalize
```

A failed export releases its reservation and does not permanently charge the user. A client disconnect must not cancel a durable job. Retryable commands use stable idempotency keys.

Every export is an immutable snapshot of the Profile content, Resume/service configuration, language, template, section visibility/order, renderer/assets/fonts version, and request identifiers at acceptance time. Later Profile edits cannot change that export.

The export lifecycle must distinguish queued, claimed, generating, retryable failure, failed, completed, expired, deletion-pending, and deleted states as applicable. Workers require safe claiming, leases or fencing, bounded retries, stale-job recovery, and protection against late finalizers.

Completed PDF objects remain private and are retained for seven days. History metadata remains after expiry. Export Again creates a new export from current content and applies the relevant credit charge.

## Article IX — Canonical Resume Rendering

JobiX uses one canonical render representation:

```text
Career Profile + Resume configuration
→ versioned HTML/CSS/assets
→ WebView Preview
→ Playwright/Chromium PDF
```

Preview and PDF must share content, order, visibility, language, direction, template identity, and render data. User text is untrusted input and must be escaped and sanitized. Generated documents must use approved fonts and controlled assets with no unsafe external resource loading.

Arabic, English, mixed-language text, RTL/LTR behavior, selectable text, page breaks, long content, fonts, and WebView/Chromium differences require release validation.

Changing Resume language changes presentation, labels, and direction. It must not silently translate or rewrite user-entered content. Explicit translation is an AI generation requiring approval and normal quota rules.

## Article X — Offline Safety, Onboarding Context, and Data Ownership

Profile editing must remain useful offline. Drift + SQLite stores local working state, drafts, outbox entries, and conflict snapshots. Credits, Rewards, AI allowance, entitlements, and server export state are never local authority.

The client must provide Save & Continue Later and Discard. Discard intentionally deletes the selected unsynced local data and must not happen silently. Logout and account deletion must define local cache/outbox wipe behavior.

The four onboarding answers are persisted as lightweight context/preferences after authentication:

- career stage;
- career goal;
- desired work location;
- areas where the user wants help.

They are not Career Profile facts, must not populate CV fields, must not directly determine ATS score, and must not grant or revoke feature eligibility. They may support future personalization and product analytics. They require ownership, RLS, timestamps, update behavior, and deletion coverage.

## Article XI — Sync and Concurrency

MVP synchronization uses Career Profile-level optimistic concurrency:

```text
update(profile_id, expected_profile_version, changes, mutation_id)
```

A matching version applies transactionally and increments the Profile version. A stale version is rejected; the server remains authoritative and the local conflicting snapshot is preserved.

Sync must be retry-safe, outbox-based where needed, and must handle deletes, logout, app restart, network recovery, and multi-device conflicts. MVP does not require CRDTs or a cloud conflict-history system.

## Article XII — Security and Privacy

1. All user-owned backend data uses PostgreSQL RLS.
2. Ownership derives from authenticated identity, never a trusted client-supplied user ID.
3. Service-role, GCP, Vertex, signing, and storage credentials never ship in Flutter.
4. Cloud Run, Scheduler, and Edge Functions use least-privilege identities and managed secrets.
5. Local SQLite PII uses platform-protected encryption where supported and is excluded from unintended backups.
6. PDFs and generated files remain private.
7. Signed URLs are short-lived and issued only after ownership checks.
8. Full CV text, personal data, secrets, and signed URLs are excluded from ordinary logs.
9. User text, HTML, URLs, and AI input/output are untrusted and schema-validated.
10. AI/provider retention, sensitive-data handling, and abuse controls must be documented.
11. Account deletion is authorized, auditable, idempotent, and retry-safe.

## Article XIII — Localization and Accessibility of Meaning

App language and Resume language are separate. Arabic and English are first-class application languages. RTL/LTR behavior follows the relevant language. Changing App Language must not translate Profile content. Changing Resume language must not silently rewrite Profile content.

User-facing validation, loading, empty, error, unavailable, and confirmation states must remain understandable in both languages. Accessibility must not rely on color alone and must support readable contrast, touch targets, and increased text size.

## Article XIV — Cost Discipline

1. AI is an explicit, controlled resource.
2. Deterministic checks are preferred where AI adds no meaningful value.
3. AI quotas and rate limits are server-side and configurable.
4. Preview must not require unnecessary PDF generation.
5. PDFs are temporary and retained for seven days.
6. Avoid infrastructure without a measured need.
7. Do not introduce Kubernetes, Kafka/Pub/Sub, Redis, CRDTs, or feature-per-service microservices without architecture review and evidence.

## Article XV — Simplicity and Architecture Boundaries

The default boundary is:

```text
Flutter
→ Supabase/PostgreSQL/RLS
→ Cloud Run for heavy work and recovery
→ private GCS for temporary files
→ Vertex AI for explicit AI operations
→ AdMob SSV for verified rewards
```

Supabase handles application backend concerns and lightweight orchestration. Cloud Run handles heavy or infrastructure-specific work. Durable database jobs may provide MVP dispatch; a larger queue is not required without measured need.

## Article XVI — MVP Scope and Future Boundaries

MVP includes Resume building/export, Cover Letter, Professional Email, Credits, Daily Reward, Profile slots, AI writing actions, ATS assessment, Arabic/English presentation, offline drafts, account deletion, and export history.

Premium monetization is outside MVP. Future subscriptions, additional Resume variants, job matching, richer career tools, and other document types may extend the entitlement and service models later without adding MVP infrastructure prematurely.

## Article XVII — Change Control and Governance

A change is architectural if it affects authority boundaries, data ownership, security/RLS, credit accounting, AI allowance, synchronization, export lifecycle, storage/privacy, infrastructure boundaries, or canonical rendering.

Architectural changes require written rationale, impact analysis, Constitution review, updated Architecture, affected specifications, and a migration/backward-compatibility plan where applicable.

Product behavior and business-rule changes require Product Design approval. Implementation tools and coding agents must not invent product behavior, weaken security, change charging semantics, or add infrastructure without approval.

## Article XVIII — Database and Migration Discipline

All schema changes use documented migrations. Prefer additive changes, compatible deployment, backfill, read/write cutover, and delayed removal. Destructive migrations require an explicit compatibility plan. Financial-like data must not be rewritten during the account lifetime; corrections use compensating transactions until authorized deletion.

## Article XIX — Testing and Quality Gates

Required tests include, where applicable:

- unit and validation tests;
- RLS and ownership isolation;
- credit concurrency, reservation expiry, and slot unlock races;
- idempotency and retry tests;
- AI allowance, timeout, anti-fabrication, stale-proposal, and approval tests;
- ATS explicit-trigger and version tests;
- export worker, snapshot, expiry, recovery, late-finalization, and charging tests;
- Cover Letter and Professional Email service tests;
- Daily Reward Cairo-date, SSV replay, and multi-device race tests;
- offline, sync conflict, discard, logout, and deletion tests;
- Arabic, English, mixed-language, RTL, font, WebView/Chromium, and multi-page rendering tests;
- account deletion and post-deletion access tests.

Unresolved security vulnerabilities, RLS bypasses, credit double-spends, duplicate rewards, duplicate export charges, silent data loss, AI fabrication, broken ownership isolation, unrecoverable jobs, destructive migration risk, or severe Arabic/RTL regressions block release.

## Article XX — Definition of Done

A feature is Done only when Product Design behavior matches, Architecture boundaries are respected, server authority is preserved, security/RLS is tested, retry/failure/offline behavior is defined, idempotency exists where needed, user-facing states are handled, observability exists, no secrets are exposed, and documentation/specifications are updated.

## Article XXI — Required Implementation Contracts Before Build

Before implementation is considered ready, the project must document:

1. API/RPC request and response schemas, error codes, limits, and ownership checks.
2. AI operation state machine, allowance reservation, timeout reconciliation, and idempotency retention.
3. ATS trigger, freshness, rubric/model version, and persistence contract.
4. Credit reservation and successful-charge timing for every billable service.
5. Export job, immutable snapshot, worker lease, recovery, expiry, and signed-download contract.
6. Onboarding-context schema and RLS policy.
7. Account-deletion workflow, stale-worker suppression, local wipe, and backup-retention statement.
8. Profile-level sync, outbox, conflict, and local snapshot policy.
9. Local SQLite encryption, cache retention, and backup behavior.
10. Template, renderer, font, and asset versioning policy.
11. Launch SLO, capacity, backup/restore, RPO, and RTO values.

## Article XXII — Forbidden Shortcuts

Unless approved through change control, JobiX must not use client-authoritative Credits, client reward grants, client AI allowance, RLS bypasses, shipped service credentials, public PDF objects, permanent signed URLs, unsafe pre-charge behavior, silent AI application, invented user facts, timestamp-only conflict authority, separate Preview/PDF layout systems, automatic AI on every keystroke, ATS-only export blocking, or unreviewed distributed infrastructure.

## Final Constitutional Statement

JobiX must remain:

- user-owned;
- truth-preserving;
- human-controlled;
- server-authoritative;
- secure;
- recoverable;
- cost-conscious;
- simple;
- Arabic/English capable;
- ATS-helpful without false hiring claims.

This draft is ready for product-manager review. It becomes the active Constitution only after approval and synchronization with Product Design, Architecture, DESIGN.md, and the implementation specifications.

## Article XXIII — Architecture V2 integration

The Constitution requires the implementation contracts defined by **JobiX Architecture V2**. Architecture V2 is the companion technical specification for:

- API/RPC envelopes, authorization, error codes, idempotency, rate limits, and pagination;
- PostgreSQL tables, constraints, indexes, RLS, ownership, and delete behavior;
- AI, ATS, Credit Reservation, Daily Reward, Export, Account Deletion, and Profile Sync state machines;
- service identities, least-privilege IAM, Secret Manager, private GCS, signed URLs, and AdMob SSV verification;
- Drift/SQLite persistence, outbox replay, Profile-level optimistic concurrency, conflicts, local encryption, and wipe behavior;
- canonical HTML/CSS rendering, WebView/Chromium parity, template/font/assets versions, sanitization, and PDF lifecycle;
- backup/recovery, operational limits, observability, alerts, testing, and launch evidence.

The following invariants are mandatory:

1. A client retry of a logical billable operation reuses its idempotency key and cannot create a second charge, reward, generation, or export.
2. A worker with a stale lease or fencing token cannot finalize an export, consume a reservation, recreate deleted data, or publish a reward.
3. An ambiguous Vertex outcome is reconciled under the original operation; the client cannot create a new generation by changing the key.
4. Export files are immutable snapshots. Export Again creates a new charged snapshot from current content.
5. Resume language changes presentation and direction only. Translation requires an explicit AI action and approval.
6. ATS evaluation is separate from ordinary AI-generation quota and never blocks Export solely because of score.
7. Premium billing is outside MVP. Premium behavior is unavailable unless a future server entitlement exists.
8. Cover Letter and Professional Email are MVP services and must have explicit charging, failure, deletion, and test contracts.
9. Onboarding answers are persisted context/preferences and never hidden Career Profile, ATS, or eligibility inputs.
10. Authorized account deletion removes active account data, including Credits, Rewards, entitlements, exports, AI records, and private files; provider backups follow their documented retention lifecycle.

A direct conflict between this Constitution, Product Design, Architecture V2, or an approved specification requires an explicit change decision. Implementation must not silently reinterpret a product rule or weaken a security/reliability invariant.

## Article XXIV — V2 readiness disposition

This Constitution V2 is ready for product-manager review. It is not active until the Architecture V2 readiness checklist, migrations, contract tests, security/RLS tests, rendering validation, backup/restore evidence, and launch requirements are approved. Remaining technical decisions must be recorded in the Architecture V2 **Remaining Decisions Before Implementation** section before production launch.





