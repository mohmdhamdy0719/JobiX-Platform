> Preserved historical plan, not current implementation authority. Original workspace path: .local/tasks/career-profile-builder-review.md. Planned criteria are not completion evidence. See ../05_TASK_HISTORY.md.

# Career Profile Builder and Review

## What & Why
Build the full Jobix Career Profile experience end to end in the native app. A real user signs up or signs in, lands in Profile #1, and works through a six-step guided builder: Personal Info, Summary, Work Experience, Education & Credentials, Skills/Projects/Languages, and Review. From Review they can edit any section, save, and come back to Review. Everything persists through the existing Architecture V2 draft and server pipeline, so the same profile is still there after the app is closed and reopened. That profile becomes the single dataset a future Resume Preview and PDF Export will read. Career, Home, and Settings are restyled to the supplied screenshots using only real data. The real cause of the generic authentication failure is diagnosed and fixed.

## Done looks like
- Signup goes through confirmation when required, then an authenticated session, then the existing Profile #1 (no duplicate is created), then Step 1 of the builder. If an auth failure happens, the user sees the specific actionable reason, and that underlying cause is fixed.
- Every builder step shows "Step N of 6", a progress indicator, Continue, and Back (Step 1 has no Back). Users can move backward freely, and earlier sections stay editable.
- Step 1 (Personal Info and links) and Step 2 (Summary with character counter, validation, and expandable writing hints) are the existing editors, reworked into builder steps.
- Step 3 lists multiple work experience role cards. Each card shows a current/present indicator and offers add, edit, remove, and expand. Users can skip the step without entering any experience.
- Step 4 lists Education, Certifications, and Achievements. Each Add/Edit opens a dedicated editor with Back and Save, and Save returns to Step 4.
- Step 5 has inline skill chips with type-to-add from a small local catalog, custom skills, and normalized uniqueness. Projects open a dedicated Back/Save editor. Languages use a bottom sheet with language and proficiency, plus a three-dot menu to edit or delete.
- Review (Step 6) shows every section from real saved data. Each section has an Edit action that opens the editor in Save mode and returns to Review after saving.
- Target Role stays optional and editable from Career/Review, with no seventh step.
- Closing and reopening the app restores the same profile. If a save is interrupted, the unsaved draft is recovered and retried. If a version conflict occurs, it is shown to the user and never silently overwritten.
- Career shows the current profile, its slot, completeness, and per-section counts and status, plus Review/Edit access. Home shows the current profile, completion, Continue Profile, and Career access. Settings follows the agreed information architecture. Future items (AI, ATS, Credits, Resume Export, Subscription, Export History) appear only as clearly inactive slots or honest empty states, with no fake values, PRO badges, or invented legal URLs.
- The entire flow works in Arabic (RTL) and English (LTR).
- flutter analyze reports no new issues. Existing tests pass, and new unit, widget, and golden tests cover the new sections and flow.
- The final report states plainly what was verified live against development Supabase, what was verified only with mocks, and what still needs a real Android device.

## Out of scope
- AI backend, "Improve with Jobix", AI proposals and suggestions, and AI usage counts. These keep their visual slots only.
- ATS engine and scores, Credits, Daily Reward, subscriptions and billing, paid profile slots.
- Cover Letter, Professional Email, Resume Preview rendering, PDF generation/export, and resume templates.
- Volunteer Experience. It is not placed in any of the six specified steps, so the data model leaves room for it, but no UI is built.
- App Language selection on Step 1. Resume language belongs to future output configuration.

## Steps
1. **Auth root-cause fix** — Reproduce signup and sign-in against development Supabase, capture the real error behind the generic message, and fix the cause in the client, the configuration, or the provisioning path. Map known failure categories to specific localized messages. Confirm that the existing trigger provisions Profile #1 exactly once and that the post-auth route reaches Step 1.
2. **Server data model for all sections** — Add RLS-protected, owner-scoped tables for work experience, education, certifications, achievements, skills, projects, and languages, linked to the career profile. Repeatable sections get stable client-generated IDs and ordering, and work experience/projects store original user text so future AI generations can sit alongside it. Recalculate completeness against the approved Contact/section weights without changing the 50% AI transition rule.
3. **Unified versioned mutation** — Extend the existing profile mutation RPC to cover every section, including Personal Information (the compatibility RPC is kept working). It must keep idempotency keys, optimistic version checks, and explicit conflict responses. RLS stays as strict as it is now, and no privileged keys are added to the client.
4. **Local drafts and pending-save recovery** — Extend the existing encrypted local draft store (schema migration) to cover structured section and entity drafts. Add a minimal pending-save queue so unacknowledged saves retry with the same idempotency key after the app restarts. Surface conflicts to the user and never overwrite silently.
5. **Single profile read model** — Expand the career profile repository and model so they return the complete profile (all sections plus counts). Builder, Review, Career, and Home all read this one source of truth, and there are no per-screen models.
6. **Builder shell and routing** — Create a shared builder scaffold with step header, progress bar, sticky Back/Continue bar, safe-area and keyboard handling. Define routes for the six steps and for the dedicated entity editors. Editors take an origin (builder or review) so Save returns to the right place.
7. **Steps 1–2** — Restructure the existing Personal Information and Summary editors into builder steps that follow the screenshots: links section, counter, validation, and expandable hints. Saving happens on Continue, and the AI slots are visibly inactive.
8. **Reusable repeatable-entity pattern** — Build one card-list component and one dedicated Back/Save editor pattern, including the empty state, remove confirmation, and validation. Use them for work experience, education, certifications, achievements, and projects.
9. **Steps 3–5** — Implement Work Experience (role cards, present toggle, date validation, skippable step), Education & Credentials (three lists with dedicated editors), and Skills/Projects/Languages (inline chips with a small local catalog, project editor, language bottom sheet with three-dot actions), all matching the screenshots.
10. **Review Profile** — Build Step 6 as a real screen that renders every section from saved data, with Edit actions that complete the Review → Edit → Save → Review loop, plus access to Target Role. The ATS/AI audit area appears only as an inactive future slot.
11. **Career, Home, Settings restyle** — Rebuild these three screens to the screenshots using real profile data and counts. Show honest empty or inactive states for deferred features, and keep the agreed Settings sections without inventing URLs or subscription state.
12. **Bilingual and RTL/LTR** — Add Arabic and English strings for every new screen. Check directional layout, icons, and date formatting in both directions.
13. **Tests and verification** — Add repository, mutation, draft recovery, and widget tests for each section and for builder/review navigation, plus goldens for key screens in both directions. Run flutter analyze and the full existing test suite, then do a live development-Supabase check of auth, Profile #1, the mutation path, and reload persistence. Report results and device-only limits honestly.

## Relevant files
- `mobile/jobix/lib/core/navigation/router.dart`
- `mobile/jobix/lib/features/personal_information/personal_information_page.dart`
- `mobile/jobix/lib/features/personal_information/personal_information_fields.dart`
- `mobile/jobix/lib/features/career_profile/text_section_page.dart`
- `mobile/jobix/lib/features/career_profile/text_section_repository.dart`
- `mobile/jobix/lib/features/career_profile/career_profile_repository.dart`
- `mobile/jobix/lib/features/career_profile/career_profile.dart`
- `mobile/jobix/lib/core/database/database.dart`
- `mobile/jobix/lib/features/core_mvp/career_page.dart`
- `mobile/jobix/lib/features/home/home_page.dart`
- `mobile/jobix/lib/features/core_mvp/settings_page.dart`
- `mobile/jobix/lib/features/auth/auth_page.dart`
- `mobile/jobix/lib/features/auth/auth_repository.dart`
- `mobile/jobix/lib/features/auth/auth_controller.dart`
- `mobile/jobix/supabase/migrations/202610040006_profile_text.sql`
- `mobile/jobix/supabase/migrations/202610030003_registration_entry.sql`
- `mobile/jobix/test/first_slice_widget_test.dart`
- `mobile/jobix/test/text_section_repository_test.dart`
- `attached_assets/JobiX_Architecture_V2_1790975874316.md`
- `attached_assets/JobiX_Product_Design_1790975900645.md`
- `attached_assets/DESIGN_1790975900644.md`
- `attached_assets/JobiX_-_Step_1_Personal_Info_&_Links_1791218272215.png`
- `attached_assets/JobiX_-_Step_2_Summary_&_AI_Hints_1791218272215.png`
- `attached_assets/JobiX_-_Step_3_Experience_&_AI_Proposal_1791218272216.png`
- `attached_assets/JobiX_-_Step_4_Education_&_Credentials_1791218272216.png`
- `attached_assets/JobiX_-_Step_5_Skills,_Projects_&_Languages_1791218272217.png`
- `attached_assets/JobiX_-_Step_6_Review_&_ATS_Audit_1791218272217.png`
- `attached_assets/JobiX_-_Career_1791218262062.png`
- `attached_assets/JobiX_-_Home_1791218262063.png`
- `attached_assets/JobiX_-_Settings_1791218262063.png`
- `attached_assets/JobiX_-_Resume_Preview_&_Export_1791218272213.png`
