> Preserved historical plan, not current implementation authority. Original workspace path: .local/tasks/jobix-first-vertical-slice.md. Planned criteria are not completion evidence. See ../05_TASK_HISTORY.md.

# First Jobix Vertical Slice

## What & Why
Implement only Onboarding → four Research Questions → Supabase Auth → automatic empty Career Profile #1 → Personal Information, using the existing Flutter Foundation. This is an approval draft, not implementation authorization. Unresolved gates below must be resolved before affected implementation starts; do not silently choose product or architecture behavior.

Authority: current slice brief; approved Product Design for behavior/copy; Architecture V2 for technical contracts; Constitution for non-negotiables; approved Figma/prototype for visuals and DESIGN.md for provisional guidance. Preserve Flutter, Riverpod, Drift/SQLCipher, secure Supabase storage, startup policy checks and environment separation. No web/Expo replacement. Foundation verification was closed with accepted environment blockers, not native acceptance.

## Done looks like
- Exactly three onboarding screens and four ordered research questions, using approved copy/options; Q4 accepts no more than three selections. Questions are context, not CV facts, and cannot gate feature eligibility.
- A small Arabic/English switch persists through the existing locale controller; no separate language screen, content translation, or CV-language coupling.
- New registration automatically creates exactly one empty first Profile server-side, including an unlocked slot 1. After an authenticated session and the existing policy guard succeed, registration opens Personal Information, never Home. Pending email confirmation is not treated as an authenticated session.
- Personal Information supports Full Name, Phone, Email, optional Country, City, LinkedIn, GitHub and Portfolio, with approved bilingual validation. Fields required for export are not mandatory for entering/leaving this slice or retaining incomplete drafts.
- Country offers an editable device/region suggestion when reasonably available; City supports approved autocomplete and custom values. A displayed suggestion must not populate the initially empty server Profile.
- Local edits survive normal navigation, app restart, and lost connectivity. Leaving with unsynced work offers Save & Continue Later / Discard; acknowledged server data is never deleted by Discard.
- Retries do not duplicate Profiles or apply a mutation twice; owner isolation and version conflicts are tested.
- Existing Foundation checks stay green. Native acceptance, staging/prod infrastructure and other features are not claimed.

## Out of scope
All builder sections beyond Personal Information; application-wide reusable personal-data UI; Home implementation; Profile slot purchases/management; AI, ATS, Credits, Daily Reward, export/templates/PDF, Cover Letter, Professional Email, translation, analytics, billing; general-purpose sync expansion; staging/prod provisioning; native device verification. Do not implement those features as stubs to satisfy schema dependencies.

## Steps
1. Resolve the scoped design, localization, auth configuration, validation and staged-schema gates; freeze their approved decisions without rewriting authority documents. Stop and report any unresolved conflict instead of guessing.
2. Add additive server schema, owner-read RLS and tightly scoped command functions, plus registration-trigger provisioning of the user, free slot 1 and empty first Profile. Use transactions and uniqueness to prevent duplicates; never copy research answers or Auth metadata into CV fields.
3. Add the encrypted Drift v1→v2 migration for anonymous onboarding state, account-owned Personal Information cache/drafts, the minimal durable mutation queue and conflict snapshots. Preserve existing metadata, locale, keys, encryption and backup settings.
4. Implement the three approved onboarding screens and four context questions with persisted progress and the existing language switch. Keep questions skippable/nonblocking according to the approved interaction decision and cap help selections at three.
5. Implement approved Supabase sign-up/sign-in, pending verification, redirect and recovery states using the existing session/PKCE adapters. Resume context transfer after authentication and retain it until server acknowledgement.
6. Extend route guards for onboarding progress, authenticated policy checks, registration provisioning and Personal Information; preserve boot, failure and update-required states. Returning users must not create new Profiles or be forced through registration again.
7. Implement Personal Information editing, local-first persistence, explicit save/exit choices and narrowly scoped retry/conflict handling. Leaving the editor remains possible without completing mandatory export fields.
8. Add unit, widget, bilingual golden, migration, encryption, local replay, server transaction and RLS tests; run existing Foundation checks and separately authorized isolated-dev checks. Report unavailable evidence honestly and stop at the slice boundary.

## 1. Exact files/modules
All paths below are proposed inventory; no implementation files have been created.

### Add
Paths relative to mobile/jobix:
- lib/features/onboarding/onboarding_page.dart
- lib/features/onboarding/research_page.dart
- lib/features/onboarding/research_context.dart
- lib/features/onboarding/onboarding_controller.dart
- lib/features/onboarding/onboarding_repository.dart
- lib/features/auth/auth_page.dart
- lib/features/auth/auth_controller.dart
- lib/features/auth/auth_repository.dart
- lib/features/auth/auth_redirect_handler.dart (only for approved verification/OAuth/recovery flows)
- lib/features/career_profile/career_profile.dart
- lib/features/career_profile/career_profile_repository.dart
- lib/features/personal_information/personal_information_page.dart
- lib/features/personal_information/personal_information_controller.dart
- lib/features/personal_information/personal_information_validator.dart
- lib/features/drafts/draft_repository.dart
- lib/features/drafts/leave_editor_dialog.dart
- lib/features/profile_sync/slice_sync_coordinator.dart
- lib/core/database/tables/slice_tables.dart
- lib/core/database/daos/slice_dao.dart
- lib/core/network/command_result.dart
- supabase/migrations/202610030002_first_vertical_slice.sql (proposed additive migration name)
- supabase/tests/first_vertical_slice.sql
- test/onboarding_test.dart
- test/auth_flow_test.dart
- test/slice_navigation_test.dart
- test/personal_information_test.dart
- test/draft_sync_test.dart
- test/slice_database_migration_test.dart
- test/goldens/{onboarding,research,auth,personal_information,leave_dialog}_{en,ar}.png
- tool/test_slice_rls.sh

### Change
- lib/core/database/database.dart and regenerated database.g.dart: schema v2 and registered tables/DAO.
- lib/core/navigation/router.dart: preserve Foundation startup guards, allow scoped nested destinations instead of redirecting every route to one placeholder.
- lib/core/providers.dart: add slice providers and integrate auth transitions without replacing awaited secure restoration.
- lib/l10n/app_en.arb, app_ar.arb and generated localization output: approved screen labels/copy/errors/accessibility text.
- test/shell_test.dart: update integration expectations while retaining Foundation state assertions.
- tool/test_rls.sh and tool/verify.sh: preserve Foundation coverage and include new migrations/tests.
- README.md and VERIFICATION.md: document this slice and distinguish test fixtures/live checks/native blockers.
- lib/core/design/tokens.dart only for approved Figma reconciliation; no invented font, typography, radii or asset values.
- AndroidManifest.xml and Info.plist only if approved Auth redirects require platform declarations.
- pubspec.yaml/pubspec.lock only for genuinely required, reviewed dependencies; reuse the installed stack first. Phone validation/reference data/provider-specific needs require decisions, not automatic additions.

No expected replacement of encryption, local-store, secure-session/PKCE, configuration, minimum-version orchestration, application IDs, OS targets or the original applied migration. No Node/API-server changes are required.

## 2. Tables and migrations
### PostgreSQL
- Existing users/app_policies: reuse, do not recreate or alter existing migration history. New registration creates the users row through a privileged registration trigger. Policy reads remain authenticated-only and deployment/admin writes remain restricted.
- onboarding_context: user_id PK/FK, nullable career_stage/career_goal/desired_work_location, help_areas array, version, server timestamps. Validate approved option IDs and max three distinct help values. Context is never CV content. Save uses expected context version and replay-safe command identity.
- profile_slots: user ownership, unique (user_id, slot_number), unlock state/timestamps. Only slot 1 is initialized unlocked; do not implement slots 2/3 unlocking or Credits. Resolve the V2 credit_transactions FK staging issue before DDL.
- career_profiles: UUID, user_id, slot_number, name, ACTIVE lifecycle, profile_version starting at 1, zero initial completeness, approved completeness_algorithm_version, first_profile_candidate, timestamps/deleted_at and active-slot uniqueness. Name, algorithm version and candidate policy must come from approved contracts, not fabricated defaults.
- profile_personal_data: UUID, profile_id ownership FK, scoped single Personal Information record, nullable full_name/email/phone/country/city/link fields, approved ordering/timestamps; one record per Profile. Create an all-empty row or return an empty projection consistently with the approved child-row contract. No research, account name/email or locale prefill into this initial Profile.
- idempotency_records: use the V2 schema: id UUID, user_id FK, operation_type, idempotency_key UUID, payload_hash, nullable operation_id, response_state JSONB, server-created created_at and expires_at. Unique (user_id, operation_type, idempotency_key), expiry index and retention at least 30 days. Retry returns the original result; different payload reuse fails.
- resume_configurations and application_personal_data are NOT silently added as unused business placeholders. V2 Profile creation requires configuration children; obtain approval for deferring Resume rows until approved template/language defaults exist, or a precisely approved minimal schema/initialization contract. Do not invent CV defaults or create export/translation behavior.

Use a new additive transactional migration and registration-trigger function, with restricted EXECUTE privileges and fixed search_path. On auth.users insertion, provision the account, slot and first empty Profile atomically; failure must not leave partially initialized application data. The trigger runs only for new identities; migration must not backfill or overwrite existing accounts without explicit authorization. Auth/OAuth retries and bootstrap reads must reconcile existing data, not recreate deleted or existing Profiles.

Commands: implement only onboarding.save, owner profile reads and profile.mutate for personal_information using V2 envelopes, ownership, expected version, validation and replay rules. Do not change read-only app.bootstrap into a mutating bootstrap. Personal Information saves lock the Profile, update section data, return authoritative state and increment version once; resolve required completeness recomputation before declaring server mutations ready.

### Drift v1→v2
Add only local_onboarding (anonymous progress, four nullable answers, merge state), local_profiles (user/environment ownership, server ID, base version/revision), normalized local_profile_personal_data, local_drafts, local_outbox and local_conflicts for the scoped context/personal-information commands. Add local_catalogs only if required by approved countries/Egyptian governorates/autocomplete reference source. Each authenticated row is account-scoped; never expose one account’s drafts to another.

The outbox stores mutation ID, operation, owner/profile binding, expected version, frozen payload, attempts, retry time and state. Context commands need context version and do not pretend to be Profile mutations. Snapshot payloads may use the approved local JSON model; primary server editable data remains normalized, not a generic JSON profile blob. Migrate transactionally from v1 without losing locale/settings or changing the database key; use the identical v2 schema for fresh creation.

## 3. RLS/security
Owner-only SELECT on context, Profiles and slot rows; child ownership through a live owned parent. No direct client business-table writes. Grant only approved authenticated command execution, revoke PUBLIC/anon/internal function execution, qualify objects and use an empty/fixed function search_path. Definer functions still check auth.uid(), ACTIVE account, parent ownership and expected version inside the transaction. Reject forged owners, cross-user Profile IDs, cross-user replay keys and different-payload key reuse, and operations against deleting/deleted accounts/Profiles; valid same-payload retries return their stored result.

Trigger authority comes from server-controlled auth.users insertion; neither client metadata nor research choices grant ownership, slot rights or eligibility. Use server-generated timestamps and approved field limits after Unicode normalization; sanitize/localize errors. Never log passwords, session tokens, answers or Personal Information payloads.

Reuse SQLCipher and device-only secure storage. Clear authenticated caches/drafts/queued work/conflicts on logout according to V2, preserve non-account settings, and prevent late auth/network callbacks from writing under a different session. Auth callback allowlists, confirmation policy, recovery behavior and provider settings must be approved; no disabling verification or weakening the minimum-version gate to make tests pass.

## 4. Navigation/state flow
Boot → existing configuration/database/session/policy checks. Signed-out first-run → onboarding 1/2/3 → research career stage/goal/location/help → Auth. The four question steps are always exactly those four; a nonblocking skip/continue contract needs approval, not mandatory CV-like validation. Suggested scoped routes: /onboarding, /research/:step, /auth, /auth/pending-verification, /auth/callback, /profile/:profileId/personal-information, retaining /boot, /signed-in, /update-required and /startup-failed. Pending/callback routes are conditional on approved auth methods.

New registration with no session → pending verification; authenticated registration → policy check → reconcile server-created Profile and context merge → Personal Information. Profile provisioning failure exposes retry/error, not a fabricated local Profile. A context network failure preserves pending local context for retry without filling CV data. Questions are not an eligibility gate. Existing sign-in restores the account and any owned draft; never auto-creates another first Profile. After a voluntary editor exit, use only the existing signed-in placeholder as the scoped boundary unless another destination is approved; no Home implementation.

Do not rebuild/reset the route tree on ordinary form edits or token refresh. Guard redirects must preserve onboarding progress, pending callbacks and account-bound drafts and reject unauthenticated/foreign Profile access. App language switching changes labels/direction only; email, phone and mixed-script content use tested direction handling.

## 5. Local drafts
Persist onboarding before transitions; keep anonymous answers through failed/cancelled Auth. After authenticated merge, clear only acknowledged pending context and keep completion state; resolve how newly entered context interacts with existing returning-account context rather than silently overwriting it.

Write meaningful Personal Information edits locally before navigation, lifecycle transitions or queueing saves. Normal restarts recover the encrypted local revision; keystrokes do not trigger server synchronization. Preserve incomplete drafts even if format validation prevents server save.

Leaving unsynced data opens Save & Continue Later / Discard. Save first persists the draft and stable command identity locally, attempts/queues sync and permits exit; offline or failed sync remains visibly pending, never falsely marked server-saved. Discard explicitly warns of unrecoverable deletion, cancels unsent scoped mutations, deletes selected local draft/conflict work and returns to acknowledged base state. It does not delete the Profile, research answers or unrelated saved data.

Serialize discard/exit with active flushes: reconcile unknown server outcomes before promising unsynced data was discarded, and do not retry discarded work later. Acknowledgements clear only the acknowledged local revision; edits made during a request remain dirty.

Flush only these slice operations on Save/Next, foreground or observed network restoration. Use stable UUID/payload across retries and restart, bounded backoff for retryable errors, user correction for validation failures and explicit auth/resource-deleted handling. A conflict preserves authoritative server and local snapshots, with Keep Server, Reapply Local and Discard; reapply uses a new key against the latest version. Review Differences is only included if practical/approved. No silent last-write-wins or unapproved automatic draft expiry.

## 6. Test plan
- Unit: exact onboarding/question copy and option sets, nullable/skip contract, max three distinct helps, locale switching, validation, auth outcomes including no-session sign-up and sign-out/recovery race regression.
- Widget/router: complete new-user flow, back/skip decisions, pending confirmation/callback, no Home after registration, missing provisioning/policy errors, existing login/no duplicate Profile, leave dialog and nonmandatory completeness.
- English/Arabic goldens for onboarding, four question states, auth, Personal Information and leave choices; RTL/LTR, mixed text, larger text and accessibility labels. Retain approved test-only font strategy; these are not production-font approval.
- Drift: fresh v2 and encrypted v1→v2 retain Foundation metadata/locale, drafts and account scoping; corrupt/wrong keys still fail. Restart restores progression and pending work.
- Draft/outbox: offline save, reconnect, repeated taps, timeout-after-commit/restart replay, edits during request, conflict/reapply, discard cancellation and in-flight outcomes, validation errors, logout wipe and account switching.
- SQL/RLS: trigger-created empty Profile/slot, atomic failure, unique first Profile, anonymous denial, owner reads, A/B isolation across every new table/RPC, direct-write denial, forged ownership, deleted states, malicious option values, idempotency/hash mismatch and stale versions. Test fixture auth schema remains local-only.
- Authorized live isolated-dev integration: new signup/confirmation, real context/profile reads and mutations, replay/version conflict, redirect/security and secure-adapter restoration. Existing test Secrets are only accessed through approved environment tooling; no PII or raw errors in logs. Obtain authorization for new test accounts/fixtures and migration application; clean up test data without touching real accounts.
- Verification: run existing verify script with real SQLCipher plus slice SQL tests; analyzer zero issues; record unavailable native/Figma/provider evidence separately. No reruns or environment mutations are performed during planning.

## 7. Acceptance criteria
All Done looks like items, plus: exact ordered three-screen/four-question flow; approved copy/options in both languages; max-three help enforced client/server; no optional-context eligibility gating; exactly one server-created empty first Profile after registration without client inserts; no forced export fields/completion or unwanted Auth metadata prefill; restart/offline local durability; truthful pending vs synced status; irreversible scoped discard without future replay; exactly-once mutation results; explicit conflict handling; owner-RLS isolation; no credentials/PII logs; retained Foundation encryption/backup/session/min-version/environment rules; zero analyzer issues and all relevant tests passing. No off-slice feature, undocumented schema workaround or fake native pass.

## 8. Blockers/unresolved decisions
1. Visual handoff: the uploaded Stitch archive contains only zero-byte directories, no screen code/images/assets. Actual approved Figma frames/prototype/assets for onboarding, questions, auth, Personal Information, leave choices and error states are missing. Fonts/typography/ranged radii remain unresolved. Do not invent final screens.
2. Localization: approved English titles/descriptions and question options exist; approved Arabic equivalents, Auth copy and new dialogs/errors are not supplied. Obtain copy approval; use the already-approved Jobix spelling in new strings without changing the message or renaming technical identifiers.
3. Auth: DESIGN.md prefers Google plus email/password and forgot password, but it is visual guidance, not a complete provider/verification/recovery specification. Confirm actual in-slice methods, configured dev providers, email confirmation, redirect URLs and recovery UX; do not assume Apple/OTP or disable verification.
4. Interaction: questions must not prevent use, but exact skip/back/completion/returning-user presentation is not specified. Confirm skip affordances and whether incoming preauth answers replace or merge existing context. Confirm exit destination and resume entry, using the existing placeholder only as a proposed scoped boundary.
5. Validation/location: required-for-export vs optional fields are defined; numeric field limits, normalized professional-link forms, phone-validation contract/library and approved all-country/Egyptian-governorate/city-autocomplete source are missing. Do not invent caps, download an unapproved dataset or replace autocomplete with plain custom-only input.
6. V2 schema dependencies: slot rows reference credit_transactions; Profile creation initializes Resume configuration requiring unapproved CV language/template defaults; career_profiles requires name/completeness version and mutation recomputation. Approve explicit staged-schema deferrals and the scoped contact-completeness contract without implementing Credits, rendering, translation or other builder sections. No fake versions/defaults/placeholder tables.
7. Operations: authenticated startup still requires an admin-approved mobile app policy; prior live tests used temporary policy and cleaned it up. Verify whether a genuine dev policy now exists and get authorized operational value if absent, without treating the temporary fixture as production policy. Live SQL migration/Auth-provider changes require separate authorized execution.
8. Not blockers to this planning request: staging/prod NOT_CONFIGURED, Android build gate, no macOS/physical devices. They remain accepted Foundation limitations and are explicitly out of this slice; do not reopen or work around them.

## Relevant files
- `attached_assets/Pasted-Create-an-implementation-plan-for-the-first-Jobix-verti_1791009610623.txt`
- `attached_assets/JobiX_Product_Design_1790975900645.md`
- `attached_assets/JobiX_Architecture_V2_1790975874316.md`
- `attached_assets/Jobix_Constitution_1790975874315.md`
- `attached_assets/DESIGN_1790975900644.md`
- `attached_assets/Pasted-We-are-now-closing-the-Product-Architecture-Finalizatio_1790979006737.txt`
- `mobile/jobix/README.md`
- `mobile/jobix/VERIFICATION.md`
- `mobile/jobix/pubspec.yaml`
- `mobile/jobix/lib/app.dart`
- `mobile/jobix/lib/core/providers.dart`
- `mobile/jobix/lib/core/navigation/router.dart`
- `mobile/jobix/lib/core/database/database.dart`
- `mobile/jobix/lib/core/database/database.g.dart`
- `mobile/jobix/lib/core/database/local_store.dart`
- `mobile/jobix/lib/core/database/encryption.dart`
- `mobile/jobix/lib/core/design/tokens.dart`
- `mobile/jobix/lib/core/localization/direction.dart`
- `mobile/jobix/lib/features/auth/secure_session_storage.dart`
- `mobile/jobix/lib/features/boot/startup.dart`
- `mobile/jobix/lib/l10n/app_en.arb`
- `mobile/jobix/lib/l10n/app_ar.arb`
- `mobile/jobix/supabase/migrations/202610030001_foundation.sql`
- `mobile/jobix/supabase/tests/rls.sql`
- `mobile/jobix/supabase/tests/local_auth_fixture.sql`
- `mobile/jobix/test/shell_test.dart`
- `mobile/jobix/test/database_test.dart`
- `mobile/jobix/test/supabase_restore_test.dart`
- `mobile/jobix/tool/verify.sh`
- `mobile/jobix/tool/test_rls.sh`
- `mobile/jobix/tool/check_foundation.dart`
- `mobile/jobix/tool/verify_live_supabase.py`
- `mobile/jobix/android/app/src/main/AndroidManifest.xml`
- `mobile/jobix/ios/Runner/Info.plist`
