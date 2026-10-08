---
name: Jobix scope and authority
description: User-specified product authority and implementation boundaries
---
## Current authorization: complete Phase 3 development implementation and deployment

The owner explicitly authorized the complete PDF Export + Credits vertical slice,
development migrations, private worker/storage/recovery, approved deletion
integration, least-privilege security/IAM and isolated development live tests.
Use the approved plan and Architecture V2. Reuse approved resources; no
unnecessary resources, new service-account keys, AI, billing, changed product
behavior or unjustified dependency upgrades.

**Why:** The owner superseded the recording-only pause with "START BUILDING
PHASE 3 NOW" and development-only implementation/deployment authorization.

**How to apply:** Preserve existing regression/security tests and canonical
immutable-snapshot rendering. Never touch production/staging. Ask before
destructive or irreversible cloud operations. Credential availability is not
permission/readiness proof; use verified TLS and restricted runtime identities,
never administrator/deployer runtime shortcuts or newly created keys.

## Earlier authorization: Phase 3 deletion/retention decision recording only

The owner approved the exact deletion/retention contract recorded in
[the Phase 3 ADR](../../mobile/jobix/backend/pdf/ADR-retention-deletion.md).
PDF expiry alone does not require immediate snapshot/HTML deletion;
profile/account deletion must remove its export objects/snapshots/related data
and verify no active export objects/snapshots remain, including late/stale-worker
protection. No additional retention period or changes outside PDF/export deletion
integration are approved.

**Why:** The owner explicitly approved this product decision but said
"Do not implement or deploy yet."

**How to apply:** Record documentation and only necessary local test/contract
updates, then stop. Do not implement purge or alter implementation guards.
Do not run remote migrations, deploy, modify IAM/GCS/Scheduler/Cloud Run/Supabase/
live Credits, start the production worker, or touch production/staging.
The policy is settled; implementation/runtime/remote gates are not.

## Earlier authorization: Phase 3 local implementation and tests only

The owner now specifies PDF Resume Export + server-authoritative Credits before
the AI operation/history/acceptance milestone. Phase 1/2 are accepted from the
implementation/testing perspective, not proof of physical-device acceptance.
Android APK/device verification will happen after this next major milestone;
do not include it as a Phase 3 implementation gate or change signing.

**Why:** After approving the product decisions and secure read-only access setup,
the owner selected “Local implementation and tests” while remote gates stay closed.

**How to apply:** Local native/backend source, forward-only migration files and
disposable tests are authorized. Keep exports disabled by default. No live
migrations, deployments, IAM changes, Cloud Run starts, GCS writes or real Credit
operations. Do not implement deletion policy without separate authorization or
start AI work. The subsequently approved ADR/current recording-only scope above
supersedes the earlier unresolved-policy status.
Surface missing dependencies/configuration; don't repair unrelated supporting
services. Past Volunteer rollout approval does not authorize PDF rollout.

The owner also authorized remaining Phase 3 local pipeline, lifecycle, Credit
fixtures, recovery/client flows and deletion/retention integration tests.
Do not interpret this as approval for a new snapshot purge period or Auth
deletion flow; consume existing DELETING states and keep deletion incomplete
until the existing policy and late-write barrier are verified.

**Why:** The owner explicitly requested local integration without changing the
approved deletion policy, and kept all remote gates closed.

**How to apply:** Use disposable fixtures only; preserve snapshot/history/dedupe
while unresolved, and report runtime/policy blockers rather than substituting
engines, weakening verification or proceeding remotely.

### Accepted Phase 3 product decisions
The owner accepted the technical direction but explicitly said not to start
Build. Use the existing pure-Dart generator with server-frozen authoritative
HTML shared by Preview/PDF; no second renderer. Export validity is structural,
not percentage or descriptive-quality scoring. Valid Volunteer can satisfy
meaningful career evidence; optional empty/short descriptions do not
automatically block export. Invalid included sections require explicit fix/hide.

Do not implement CANCELLED/export.cancel. Preserve the existing wallet/ledger,
add job-aware reservation fencing, and keep the bounded 30-minute deadline.
Exclude photos, preserve template IDs/default output, and add only minimum
configuration metadata for parity/concurrency. Validate approved 200KB normalized
text before rendering and final 20-page maximum before completion/charge.

Downloads use short-lived generation-bound URLs issued after authentication,
never persisted. Valid download costs zero; missing/expired files never
silently regenerate; Export Again costs two. Keep seven-day PDFs and history
metadata after expiry; do not invent snapshot/deletion retention periods.
Use development-only least-privilege identities, no secrets in Git/Flutter,
client Credit mutation or public objects. AI remains excluded.

**Why:** The owner explicitly confirmed these twelve product decisions and
requested only their recording, a short remaining-decision checklist and a
read-only readiness report.

**How to apply:** Do not reopen settled decisions or infer Build permission.
Flag PDF/account/profile deletion-policy integration for separate owner
implementation authorization, audit dev access only when separately authorized,
report missing prerequisites and stop. The policy itself is now approved above.

The owner authorized secure development-access setup and read-only access
verification. This does not authorize IAM/resource changes, migrations,
deployment or starting Cloud Run.

**Why:** The owner explicitly selected “Authorize secure access setup” after
these limits were stated.

**How to apply:** Collect existing development credentials only through secure
tooling, verify the approved targets read-only, and stop at missing permissions
or the remaining implementation/runtime approvals. Never request secret values in chat.

## Earlier authorization: bounded Phase 2 scope

The owner accepted Phase 1 and approved the Phase 2 plan for Volunteer
Experience and targeted Resume Preview refinements, with an explicit decision
that Volunteer must not affect Profile Completeness or existing AI states.
Volunteer remains a dedicated unpaid section inside the existing six-step
builder; the professional resume is to be refined, not redesigned.

**Why:** The owner approved everything else in Phase 2, required no Volunteer
percentage/scoring changes, and required a scope/decision update before starting.

**How to apply:** Treat Phase 1 as accepted. Execute only the explicitly assigned
Phase 2 scope; the no-scoring rule is settled, not awaiting another approval
(see `completeness-authority.md`). Task assignment does not authorize remote
migration execution, new signing identities, AI/PDF/later phases or archived
follow-ups. Retain the development-rollout and safe native-installation gates.

## Earlier Phase 1 native bug-fix authorization

The approval-first audit is complete and Phase 1 has a Build-mode assignment:
only the five reported native bugs are authorized. Later feature phases are
not authorized. Do not resume archived follow-ups or repair supporting
Node/browser/API services as native Jobix work.

**Why:** The owner explicitly stopped unauthorized supporting-service work and
then supplied a planning-only brief before approving the native bug-fix phase.

**How to apply:** Implement only language editing, Back handling, draft discard,
warning timing and Country/City icon removal. Report missing prerequisites
before installing or configuring them. The later proposed sequence is Volunteer
Experience/resume refinements,
server AI operations/history/acceptance, real AI UI enablement, then private PDF
export. Preserve the native stack, six-step builder and existing security rules.

Restoring the existing locked Flutter/Dart package cache is authorized for this
native bug-fix phase; package upgrades are not authorized.

**Why:** The owner explicitly approved "Restore locked packages and continue"
after the missing cache prevented the regression test from compiling.

**How to apply:** Enforce the existing lockfile; ask before any additional
toolchain/configuration installation and do not repair supporting services.

The owner subsequently approved installing the missing Android SDK/NDK,
accepting required SDK licenses and recreating ignored development settings
to build a fresh ARM64 development APK for the Samsung M31.

**Why:** The owner explicitly approved the native build setup after requesting
an APK containing the completed bug fixes.

**How to apply:** Limit this approval to native build preparation and APK
delivery. It does not authorize product/backend changes, supporting-service
repairs, later feature phases or a claim of real-phone acceptance.

The new product rules supersede earlier unsaved-item continuation behavior:
opening/editing a repeatable record is not Save; explicit Back discards
unsubmitted edits, with appropriate existing-record confirmation, and does not
silently save. Root Back requires a localized exit confirmation. Empty optional
descriptions must not immediately show Needs attention; non-empty short prose
gets post-Save quality guidance without becoming required. Volunteer Experience
is requested as its own repeatable section, distinct from Education and paid
employment, without adding a seventh builder step.

**Why:** These are explicit requirements in the owner's next-stage brief,
following real Android bug reports, not behavior inferred from old tests.

**How to apply:** Keep restart recovery and already-submitted ambiguous Save
reconciliation safe while changing intentional exit behavior. Do not silently
alter completeness weights or volunteer scoring; later feature phases still
require approval.

## Current builder-polish and Resume foundation authorization

The owner confirmed signup, confirmation email, return-to-app and authenticated
entry work in development. Preserve that flow. The current brief authorizes
builder UX/lifecycle fixes, IBM Plex Sans Arabic, private optional photos/custom
links, AI proposal UI and authoritative allowance foundation, server Credits
reservations, and Career-Profile-backed canonical HTML Resume configuration/preview.
PDF export may proceed only where safely implementable. No Cover Letter,
Professional Email, Subscription/Billing or advanced paid features.

**Why:** The owner explicitly moved beyond verification to the two-phase
builder-polish and Resume-building foundation milestone.

**How to apply:** Follow the latest 817-line brief, retain the native stack and
screenshot authority, never fake provider output or quotas, and report backend
gaps separately from real Android-device acceptance.

## Earlier verification milestone boundary (superseded by the above)

The owner now requests real Android end-to-end verification and necessary fixes
only, before any new feature set. Exercise genuine development Auth, Profile #1,
the six-step builder, Review/Edit and persistence wherever the environment allows.
Do not redesign, change Architecture V2, run additional model evaluations, or
start AI, ATS, Credits, Daily Reward, Subscription, Cover Letter, Professional
Email, PDF Export or a separate Volunteer Experience implementation.

**Why:** The owner explicitly supplied this verification-only milestone after
the builder implementation, distinguishing live evidence from mocks and devices.

**How to apply:** Use the approved development Supabase setup without external
SMTP/Resend, disabled confirmation or weakened RLS. Build Android when possible;
never call a host widget render or APK build real-device verification. Report
what requires the owner's Samsung and the exact build/setup prerequisites.

## Earlier core-MVP authorization

The owner now authorizes the complete post-authentication career-building MVP
as one coherent product journey, not a collection of isolated form slices, including profile sections/editing/sync,
completeness, Gemini proposals, Home/Career/Settings, server-authoritative
Credits/rewards, canonical resume preview and PDF export. Earlier
foundation-only, first-slice-only and visual-only restrictions below describe
prior phases, not the current authorized scope.

**Why:** The owner explicitly supplied a new core-MVP implementation brief.

**How to apply:** Preserve the approved native stack and Architecture V2.
The newly supplied screen images are the primary visual reference, with small
corrections allowed for misleading claims or product inconsistencies; they are
not permission to invent user data, scores, entitlements or backend results.
Before continuing, verify development startup policy read-only. Stop at missing
contracts, migrations, configuration or unclear behavior and ask rather than
guessing. Never substitute mock Credits, AI, rewarded-ad verification or exports
for real server-authoritative operations. Ask related independent dependency
questions together. Do not create staging/production infrastructure or weaken
security to unblock implementation.

## Guided builder and screenshot-led implementation

New users must enter a continuous Career Profile builder with clear step
progress, Continue as the primary action, back/edit support and safely retained
drafts, then Review → Preview → Export. Dedicated section editors belong to
post-creation Career management, not the primary creation journey. Career opens
the last-used Profile. Reuse the screenshot-led Jobix design across all screens;
do not substitute generic Material forms. Inter and bundled Noto Sans Arabic
remain the UI fonts. Never expose database/API/migration/research-sync details
in product copy. Authentication is a dedicated experience, without unrelated
application navigation; Create Account must not show Forgot Password.

**Why:** The owner explicitly corrected the technically working text slice's
UX and requested the complete coherent Career Profile → Resume MVP rather than
another isolated slice.

**How to apply:** Inspect real code, Architecture V2 and the approved screenshots
before large changes. Confirm unclear screenshot authority and materially
unclear product/infrastructure decisions before implementation. Preserve
existing drafts, RLS, server authority, versions, idempotency and conflicts.
No invented services, scores, AI facts, entitlements or exports; stop and name
the exact setup needed for genuinely unconfigured external services.

The owner subsequently fixed the main builder at six steps: Personal
Information; Summary; Work Experience; Education & Credentials; Skills,
Projects & Languages; Review. Main screens use Continue (Step 5: Review
Profile; Step 6: Preview & Export). Nested record forms use Save and return
to their parent. Step 1 has no bottom Back action; its top exit returns Home.

Uploaded Jobix screenshots and resume images are visual/UX references, not
pixel-perfect targets. Do not copy their sample people, scores, metrics,
verified badges or commercial claims. Infer missing screens from approved
interaction patterns rather than requiring a screenshot for every screen.
The owner permits an original restrained ATS-first resume layout informed by
the references; do not copy decorative graphics or prioritize them over parsing.

**Why:** The owner explicitly clarified the six-step flow, nested-record actions
and interpretation of the newly uploaded screen and resume references.

**How to apply:** Preserve the current authentication design except for the
requested header removal, real signup repair and unchecked-by-default required
Terms/Privacy consent with configurable placeholder destinations. Do not invent
legal URLs or legal claims. Verify signup against real development Auth, including
confirmation and subsequent sign-in; existing test-account login is not proof.

## Earlier authorizations and standing constraints

Use “Jobix” for new user-facing copy. Do not blindly rename historical technical identifiers.

Preserve Flutter, Riverpod, Drift/SQLite, Supabase Auth/PostgreSQL/RLS/Edge Functions, Cloud Run, private GCS, Vertex AI, AdMob SSV, and canonical HTML/CSS rendered through WebView and Playwright/Chromium. The starter web scaffold is not permission to substitute a web or Expo stack.

**Why:** The user's implementation brief explicitly prohibits unapproved architecture changes and requires an initial readiness audit before implementation.

**How to apply:** Obtain approval before beginning implementation after the audit. Build incremental vertical slices. Product Design controls behavior; Architecture V2 controls technical contracts, V1 is historical; Constitution protects non-negotiables; approved Figma/prototype controls visuals and DESIGN.md guides implementation. Escalate meaningful conflicts instead of silently deciding them. Do not invent a replacement visual identity.

Implementation authorization is slice-specific. Foundation approval does not authorize onboarding, authentication UI, career-document features, analytics or subsequent feature slices.

**Why:** The user explicitly required stopping at the end of Foundation and not continuing into features.

**How to apply:** Finish and verify the authorized slice, report remaining gates honestly, and wait for separate feature-slice permission. Do not choose unresolved visual values without an approved source.

The owner separately authorized the first vertical slice: three skippable
onboarding screens, four non-skippable-as-a-group context questions, confirmed
email/password and Google Auth, one empty Profile #1, Personal Information,
Home-first returning navigation and local drafts. No AI, ATS, Credits, export,
rendering, translation, sync/outbox, analytics or premium billing in this slice.

**Why:** The owner's resolved decisions explicitly authorize this scope and
prohibit re-planning or reopening them. Accepted HTML files are the visual
source of truth, including structure and typography, not just shared colors.
Later-screen references do not authorize their features.

**How to apply:** Resume implementation within this scope without seeking
Foundation-only approval again. Required-for-export fields never block partial
saves or leaving. Keep App Language independent of explicitly selected Resume
Language; do not translate content or invent Resume defaults/location catalogs.

Do not create or invent staging/production Supabase projects or credentials
just to satisfy Jobix verification gates. Record unavailable native tooling,
physical devices and genuine environment configuration as blockers; do not
substitute simulated native evidence.

**Why:** The user explicitly required this boundary when accepting live
Supabase results and closing verification with documented environment blockers.

**How to apply:** Obtain genuine prerequisites and authorization before
resuming blocked checks. Task closure with accepted blockers is not proof that
native build, Keystore/Keychain or device acceptance passed.

Use the actual supplied HTML when revising this slice, never an approximation
from memory. Fictional CV examples, scores, verification badges and unsupported
marketing in those files are not authorized product data or claims. First-time
users must finish Q1–Q4 before any Auth/login entry; Skip is introduction-only.

**Why:** The user explicitly corrected visual/product drift and required
removing unsupported examples and shortcuts before any next feature slice.

**How to apply:** Preserve approved behavior and bilingual independence while
matching source layouts. Replace prohibited demonstration content with the
smallest neutral static illustration. Report deliberate HTML differences and
stop after the authorized revision; do not infer next-slice permission.

The user accepted the first-slice revision for now and requires an iterative
visual review of the existing real Flutter application: run, inspect, identify
an issue, make the smallest UI/UX fix, run again and inspect again. Keep supplied
HTML as the visual source of truth. No new product functionality, flow changes,
invented screens or behavior; no tables/migrations except when required to fix
an existing implementation bug. Do not start the next feature slice until the
user explicitly approves the current visual implementation.

**Why:** The user explicitly limited the next work to Design-mode visual
validation and interactive review, not feature implementation.

**How to apply:** Check actual runtime/configuration availability before
promising an interactive Flutter preview. Review layout, typography, components,
navigation, direction/language independence, input/keyboard/scroll behavior,
states and responsiveness. Fix only identified UI/UX issues and keep native
acceptance limitations distinct from test renders or mockups.

For physical-Android design review, the user explicitly authorizes installing
only required Android SDK/build tools, accepting their licenses, restoring the
existing development configuration, and building a development/debug APK.
Do not configure/build staging or production, request new/service-role
credentials, alter databases, or substitute Expo/React Native/Linux. If a
required Android build prerequisite cannot be provided here, stop and report
the exact prerequisite rather than changing architecture.

**Why:** The user repeated these boundaries to distinguish native build setup
from product changes.

**How to apply:** Use genuine existing dev settings for the review APK. Keep
the standard multi-environment build checks unchanged and report the exact APK
path only after a successful build; a build is not physical-device validation.

The owner replaced HTML/Stitch/Figma visual imitation with an original Jobix
mobile design system on 2026-10-03. Earlier HTML visual-source rules above are
historical for this redesign; product requirements, UX flows, functional
behavior, architecture, terminology and brand remain fixed.

**Why:** The owner explicitly said the previous approximation looked poor and
assigned visual design responsibility to the agent.

**How to apply:** Audit first, report components/tokens/fonts/assets and startup
cause, then resolve truly blocking inputs before implementation. Limit this
phase to polished foundation, splash, three introductions, four research
questions and authentication. Use production Inter and Noto Sans Arabic.
Do not invent/recolor a logo or app-icon mark: request missing approved variants
and the existing icon master. Keep App/Resume Language independent, put only
one compact language control in introduction headers, and do not build full
Settings, Home dashboard, Career Profile Builder, AI, ATS, billing or export.
Resume selectable-text/RTL/font requirements constrain future work, not scope.

Use only the owner's approved dark/primary logo and app-icon master, preserving
proportions, colors, shape and clear space. Do not redraw, restyle, recolor,
simplify or generate alternatives. Terms/Privacy have no approved public URLs;
they are a pre-launch dependency, not permission to invent destinations.

**Why:** The owner explicitly supplied approved assets and restricted their use.

**How to apply:** Package the supplied masters without cropping/recoloring;
platform sizing and safe-area padding are allowed. Missing production values
never authorize invented production policy or bypassing startup/auth guards.

The owner's resumed redesign instruction explicitly authorizes development-only
mobile policy values: minimum 1.0.0, recommended 1.0.0, policy version 1.
Terms/Privacy URLs and undecided production policy are not implementation blockers.
Original, typography-led native Flutter visuals replace old screenshot imitation.

The owner subsequently supplied three onboarding screenshots and authorized
recreating those screens with a similar or improved presentation. This is an
onboarding-only visual reference update, not new feature or flow permission.

**Why:** The owner explicitly requested recreation from the CV, AI-assistance
and export/update images.

**How to apply:** Preserve the existing approved onboarding copy, navigation,
language switch and research boundary. Use neutral decorative illustrations
instead of fictional CV details, invented metrics or unsupported ATS claims.
Other screens retain their independently approved design direction.

**Why:** The owner explicitly resolved the previously missing inputs and allowed
this exact configuration to unblock authenticated development startup.

**How to apply:** Use the existing protected isolated-development configuration
mechanism; never weaken RLS, use client server credentials, or touch production.
Document mandatory pre-production review. Preserve architecture and all product
behavior; physical-device acceptance remains separate from widget/live-service
checks. Do not build any next feature slice.