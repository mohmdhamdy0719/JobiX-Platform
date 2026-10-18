# UI and route review checklist

Route inventory is from `mobile/jobix/lib/core/navigation/router.dart`. This is a source inventory, not a visual review. Arabic and English localizations and golden/widget tests exist, but no running screenshot or device was captured in this handover. Treat each manual column as pending unless explicitly noted.

| Route / screen | Implementation | Data / behavior to review | Existing evidence / manual status |
|---|---|---|---|
| `/boot`, `/startup-failed`, `/update-required` | `lib/features/boot/startup.dart`, `lib/features/shell/foundation_page.dart` | DB/key/session/policy loading, retry, fail-closed update route | Startup tests and goldens exist; physical cold start pending. |
| `/onboarding` | `lib/features/onboarding/onboarding_page.dart` | progress persistence, validation, resume after interruption | Widget/contract tests; visual device review pending. |
| `/research` | `lib/features/onboarding/research_page.dart` | question validation and completion gating | Research tests/goldens; device review pending. |
| `/auth` | `lib/features/auth/auth_page.dart` | password/provider settings, validation, loading, confirmation errors | Auth tests/goldens; test redirect and keyboard on device. |
| `/confirm` | `lib/features/auth/auth_page.dart` mode `confirm` | email callback/confirmation and route state | Source/tests; real email callback pending. |
| `/forgot` | `lib/features/auth/auth_page.dart` mode `forgot` | reset request, safe status/error | Source; real reset flow pending. |
| `/recovery` | `lib/features/auth/auth_page.dart` mode `recovery` | recovery session and password update | Route guard exists; real flow pending. |
| `/home` | `lib/features/home/home_page.dart` | profile greeting, load/empty/error, navigation | Widget/golden coverage; current device review pending. |
| `/career` | `lib/features/core_mvp/career_page.dart` | profile/section navigation, completion indicators | Tests exist; manual review pending. |
| `/career/personal`, `/builder/1` | `lib/features/personal_information/personal_information_page.dart` | validation, dirty state, drafts, save acknowledgement/version conflict | Repository/widget tests; physical keyboard/RTL pending. |
| `/career/extras` | `lib/features/personal_information/profile_extras_page.dart` | photo/custom links, URL validation, pending/retry, explicit saved state | Repository tests; Android picker and recovery pending. |
| `/career/summary`, `/builder/2` | `lib/features/career_profile/text_section_page.dart` | text length/validation, local draft and versioned save | Section tests and EN/AR goldens; device review pending. |
| `/builder/3`, `/builder/4`, `/builder/5` | `lib/features/builder/builder_steps_page.dart` | entity add/edit/delete, validation, keyboard and section state | Builder widget/contract tests; device review pending. |
| `/builder/6` | `lib/features/builder/review_page.dart` | final completeness and continuation choices | Review tests; no current device review. |
| `/career/edit/:section/:id` | `lib/features/builder/entity_editor_page.dart` | item lookup, validation, save, stale item | Entity repository/editor tests; malformed route falls back to review. |
| `/resume` | `lib/features/resume/resume_page.dart`, `lib/features/resume/resume_export_panel.dart` | local snapshot, saved language/layout, pending edits, preview/export gating | Preview snapshot/layout/export widget tests; integrated device download is currently failing. |
| Resume local preview (nested) | `lib/features/resume/resume_preview_page.dart`, `lib/features/resume/resume_render.dart` | page navigation, zoom/content overflow, EN LTR and Arabic RTL | Renderer/widget tests and earlier Local Preview POC device validation; current full profile/device matrix incomplete. |
| `/export-history`, `/credits` | `lib/features/core_mvp/credits_page.dart`, `lib/features/resume/resume_export_panel.dart` | authoritative balance, empty/error/loading, history pagination, free download vs 2-Credit creation | Widget and PDF tests; current device History download broken by report. |
| `/resume-status/:id`, `/resume-details/:id` | `lib/features/resume/resume_operation_page.dart` | polling, terminal states, retry/manual status, download; account change | Widget tests; Android save issue unresolved. |
| `/settings` | `lib/features/core_mvp/settings_page.dart` | locale, account navigation, state loading | Settings goldens; manual review pending. |
| `/settings/account` | `lib/features/core_mvp/account_information_page.dart` | account details, deletion confirmation/freeze, recovery | Source and backend deletion tests; physical/account delete acceptance pending. |

## Cross-screen checks still required

For each route: loading/empty/success/error; validation and focus; duplicate submit prevention; back/gesture/keyboard behavior; English LTR and Arabic RTL; large text/small viewport overflow; focus/semantics; session switch; offline/retry; persistence and dirty-state clarity. Existing localization/golden images establish test artifacts only, not that the latest APK visually matches them.

Specific product constraints to preserve:

- Opening Local Preview is read-only and must never silently save pending profile edits. Explicit saved-version review appears when local draft/save state is unresolved.
- Resume language is separate from app locale; content is not translated automatically.
- A successful new export costs 2 Credits only after explicit confirmation; valid existing downloads are free for 7 days.
- Do not interpret generic `SERVICE_UNAVAILABLE` as a particular UI cause; show safe, actionable messages and preserve unresolved requests.
- Keep the diagnostic copy action limited to sanitized save metadata in debug builds.

No new screenshot, accessibility audit, full route interaction run, or physical visual/performance review was performed here.
