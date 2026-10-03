# Jobix visual redesign audit — 2026-10-03

## Current status — owner-authorized redesign delivered

This document preserves the **pre-implementation audit** below. Its earlier
“stopped”, “not integrated”, absent-policy and missing-font findings are now
historical, not current blockers.

The owner's resumed instruction explicitly authorized original native Flutter
visuals, supplied unchanged brand masters, Noto Sans Arabic integration and the
development-only mobile policy 1.0.0 / 1.0.0 / 1. The previous screenshot/HTML
imitation requirement no longer controls this redesign.

See [VISUAL_REDESIGN_REPORT.md](VISUAL_REDESIGN_REPORT.md) for delivered scope,
files, verification and remaining limitations. No production changes or new
feature slice were made. Physical Galaxy M31 rerun remains unverified because
there is no connected device or fresh owner evidence for the redesigned APK.

## Owner inputs received after the audit

- Approved dark/primary logo and white-background app-icon master were supplied
  and visually inspected. These resolve the missing-brand-input findings below.
  Preserve their proportions, colors, shape and clear space; do not redraw,
  recolor, simplify or generate alternative marks. They are not yet integrated.
- Physical review device: Samsung M315F/DSN (Galaxy M31), Android 12,
  as explicitly supplied by the owner. No additional device access is available.
- No approved public Terms/Privacy URLs exist. Document as a pre-launch
  dependency; do not invent links or production destinations.
- The owner explicitly prohibits inventing/changing policy values and instructs
  stopping if required values are absent. The last read-only check found no row
  for `policy_key = 'mobile'`. Its required, missing owner-approved values are
  `minimum_supported_version` (format major.minor.patch) and `policy_version`
  (text). `recommended_version` is optional; configuration and timestamp have
  schema defaults. Version 1.0.0 in the APK/config is not an approved minimum
  policy value and must not be used to invent one.
- Work is stopped at this blocker, not completed. No assets were transformed,
  no app implementation/build/rerun occurred, and no database, policy, migration,
  provider or authentication setting was changed.

## Authority and scope

The owner now replaces HTML/Stitch/Figma visual imitation with an original,
professional Jobix Flutter design system. Product requirements, flows, rules,
brand, architecture and functional behavior remain fixed. This phase covers
foundation/startup, three introduction screens, four research questions and
authentication only. Existing Personal Information functionality must not regress;
no next feature slice, full Settings, dashboard, builder, AI, ATS or PDF work is
authorized. Resume typography requirements are future constraints, not permission
to implement rendering/export.

## 1. Current UI problems

The ten owner-supplied physical-device captures show:

- Blank navy native launch followed by a plain “Starting Jobix” spinner.
- Large decorative skeleton CV cards, inconsistent headline alignment, and
  unused lower-screen space across introductions.
- White portions of the supplied logo disappear against the light canvas.
- Research rows consume substantial height; the seventh Q1 option is below
  the captured viewport. This establishes a density/scroll-affordance concern,
  not proof that the option cannot be reached.
- Arabic falls back to a visually different system face; production Noto Sans
  Arabic is absent.
- Repeated globe controls in introduction, research and authentication.
- Create Account includes Forgot password, an always-visible Google action,
  no terms/privacy agreement presentation, and a generic error card.
- One signup capture contains Arabic error copy within an English screen.
  Current code uses localized copy for both notice and auth-flow errors; the
  screenshot does not establish the exact sequence causing the mismatch.
- Startup failure gives no diagnostic category.

No captures verify Q2–Q4, Personal Information, keyboard behavior, selected
research states or the device model/API/ABI. No connected device is available.

## 2. Existing reusable components

`core/design/slice_widgets.dart` contains SliceScaffold, SliceCard,
PrimaryAction, ChoiceTile, SectionHeading, BrandMark and OnboardingArt.
`app_language_button.dart` provides a persisted language control.
Forms still use direct Material TextFormField/OutlinedButton/TextButton widgets.
The shared frame already supports SafeArea, scrolling, constrained width and
bottom actions; preserve these capabilities while restyling.

## 3. Existing tokens

`core/design/tokens.dart` supplies TokensV0 and foundationTheme:
blue primary #2563EB, navy #0F172A, lavender-white background #F8F9FF,
white cards, slate secondary text, 4–64 spacing, 16 page gutter,
8/12/16 radii and 12–36 type sizes. Several compositions still contain
literal sizing/shadow/motion values. Material 3 defaults remain visible,
particularly secondary buttons, fields and startup.

## 4. Existing fonts

Inter.ttf is bundled and declared in pubspec.yaml. Arabic production text uses
platform fallback. DejaVuSans exists only in tests; it is not the production
Arabic font. The new system must bundle Inter and Noto Sans Arabic, select
UI typography by App Language, and preserve independent Resume Language.
Openly licensed Noto Sans Arabic can be obtained without requesting a secret.

## 5–6. Missing assets and required logo variants

The only standalone bundled brand asset is a white-J/blue-X raster logo.
No dark/primary-on-light variant or owner-supplied launcher-icon master was
found. Required inputs: approved dark/primary logo variant for light surfaces
and the existing app-icon master. The white logo can serve a dark splash
background; do not recolor or redraw the mark without authorization.
No new splash background or ornamental illustration is needed.
Approved Terms and Privacy URLs/content are also missing from current auth UI.

## 7. App icon integration

Android mipmap and iOS AppIcon files still contain the Flutter mark.
AndroidManifest.xml lacks android:icon. Android 12+ launch explicitly uses a
transparent splash icon. Integrate the owner's icon with native packaging,
including adaptive Android resources and iOS sizes; do not redesign it.
iOS build acceptance remains unavailable without macOS/Xcode.

## 8. Startup/authentication investigation

Read-only probes against the existing authorized isolated development project:

- Dev config targets the authorized project and version 1.0.0.
- Auth health and public settings return HTTP 200 from this workspace.
- Public settings report email=true, google=true, mailer_autoconfirm=false.
  Enabled flags do not prove Google credentials/callbacks or mail delivery work.
- Verified-TLS, read-only SQL reports zero operational `mobile` policy rows.
  The `read_app_policy(text)` RPC exists.

Startup opens encrypted storage, initializes Supabase with public compile-time
defines, explicitly awaits secure session restoration, then checks the policy
only for a confirmed session. A missing policy throws or produces a PostgREST
empty-result error; the router sends startup errors to `/startup-failed`.
First-entry RPC errors also use that destination.

Thus the absent operational policy is a confirmed authenticated-startup blocker,
consistent with the post-auth device failure. It is not proof of the exact
device exception: no device logs/session state were supplied. Initial
signed-out introduction launch demonstrates that startup did work at least
once on the owner's device. Workspace reachability does not establish device
network health.

Do not change copy alone, skip the guard, seed a fabricated policy, clear a
session silently or alter RLS. Required remediation is an administrator-approved
operational policy/version in development, plus sanitized diagnostic categories
to distinguish storage, restoration, policy/network and first-entry failures.
No remote setting, account, policy or provider was changed during this audit.

## 9. Proposed visual direction

Original mobile-first editorial design: white/warm-neutral surfaces, brand blue
primary actions, navy headings, modest 8–12 corner radii, fine borders, little
or no elevation, and consistent start-aligned hierarchy. Reuse existing brand
colors rather than inventing a new identity.

- Typography roles: 28 headline / 22 section / 16 body / 14 supporting, with
  language-specific line height and 500–700 weight hierarchy.
- Spacing: 4-based scale, 20 standard page gutter, 16 compact gutter.
- Minimum 48 logical-pixel interactive targets; primary actions about 52 high
  when space allows. Solid blue enabled actions; distinctly muted but readable
  disabled actions; loading preserves layout and prevents duplicate taps.
- Compact research rows without redundant icon tiles; selected state uses
  border, tint and checked control, not color alone.
- Intentional typography-led introductions, with only small meaningful visual
  cues if justified; no fake document/dashboard skeletons.
- One compact introduction header language control, no repeated globe.
  No full Settings implementation in this phase.
- Separate signup/sign-in presentations, external field labels, explicit
  error styling and keyboard-aware layout; Forgot password only on sign-in.
- Shared motion tokens around 150–220ms, directional navigation and reduced
  motion support. Layout-driven spacing, scrolling and bounded compact type
  adjustments on short screens; never suppress accessibility scaling globally.
- Preserve all research ordering/selection limits, context-only semantics,
  existing authentication contracts and startup/session guards.

## 10. Planned modification inventory

- `lib/core/design/tokens.dart`: original shared tokens and locale-aware theme.
- Split focused reusable components under `lib/core/design/` for buttons,
  fields, selection rows, headers/progress and loading/error/empty states.
- `lib/app.dart`: localized production typography/theme integration.
- `pubspec.yaml`, `assets/fonts/`, `assets/brand/`: fonts/licenses and supplied
  approved brand assets.
- `features/shell/foundation_page.dart`: branded initialization/error states.
- `features/onboarding/onboarding_page.dart`, `research_page.dart`: new visuals,
  existing state/actions retained.
- `features/auth/auth_page.dart`: professional separate form presentations.
- `lib/l10n/app_en.arb`, `app_ar.arb` and regenerated localizations:
  approved copy, consistent bilingual states.
- `core/providers.dart`, `core/navigation/router.dart` and targeted auth error
  handling only as needed for safe diagnosis/retry; no architecture replacement.
- Android launch/icon resources and manifest; iOS launch/icon assets.
- Focused widget/contract tests, visual baselines and verification documentation.

The above inventory was proposed at audit time and has now been implemented
within the later owner authorization; see the report. Terms/Privacy URLs remain
a pre-launch dependency, not an implementation blocker. Physical-device rerun
still requires actual device access or new owner evidence. Widget renders and
APK builds cannot substitute for it.