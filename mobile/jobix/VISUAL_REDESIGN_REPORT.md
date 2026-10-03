# Jobix visual redesign delivery — 2026-10-03

## Delivered scope and authority

The owner's resumed written brief replaces the prior screenshot/HTML imitation
and minimal-review-only boundary with an original native Flutter visual redesign
of startup, three introductions, four context questions, authentication,
bilingual typography, shared presentation components and native brand packaging.
It also explicitly authorizes development-only mobile policy configuration.

No dashboard, full Career Profile Builder, full Settings, AI, ATS, Credits,
Cover Letter, Professional Email, PDF export or next feature slice was built.
Existing product flows, routes, profile/draft data, App/Resume language
independence, secure-session barrier and policy/RLS guards remain.

## Screens and UI fixes

- Branded navy startup with approved white logo, real loading indication,
  safe storage/session/policy failure notices, retry and guarded update state.
- Three typography-led introductions; placeholder document illustrations
  removed. One compact language control lives in the introduction header.
  Continuation remains separate from introduction-only Skip.
- Four compact context-question screens retain exact option values, ordering,
  selection/persistence and Q4 maximum-three behavior. Context remains distinct
  from CV content; every answer remains reachable by scrolling.
- Separate login/signup/confirmation/reset/recovery presentations. Signup has
  no Forgot password; login does. Empty fields, localized email/required-password
  validation, visibility controls, busy/success/failure presentation and
  keyboard actions remain usable.
- Google is shown only after real public server settings report enabled.
  Failed discovery is explicit, with retry; email authentication stays available.
- Terms/Privacy acknowledgement is structurally present and clearly says links
  are not configured. No destinations or password policy were invented.
- Changed auth modes clear fields and stale form notices; changing language
  within a mode retains typed content. Semantic notices relocalize.
- Captures exposed an Arabic-language-label font fallback problem, double
  RTL arrow mirroring and ambiguous technical step fractions. These were
  corrected, rerendered and visually inspected.

## Files changed

- `lib/core/design/tokens.dart`, `slice_widgets.dart`,
  `app_language_button.dart`; new `async_states.dart`.
- `lib/app.dart`; onboarding/research/auth/Foundation pages;
  new `auth_notice.dart`, `provider_settings.dart`.
- `features/boot/startup.dart` adds safe failure categories without changing
  guard order or authorizing failed startup. Retry also retries failed entry state.
- Both ARBs and regenerated localized Dart files.
- `pubspec.yaml`, approved brand assets, production font assets/licenses.
- Android manifest, density-specific legacy/adaptive icons, launch resources;
  iOS AppIcon/LaunchImage catalogues and launch storyboard.
- Widget/startup/provider-setting tests, production font test loader and
  regenerated/new render baselines.
- Development-only configuration SQL and protected administration script;
  asset packaging tool and explicit live development smoke test.
- Supporting Python image/font dependencies and native library packages,
  design-system/report/audit/verification documentation and durable authority
  notes. No API/mockup service or application architecture was replaced.

Full visual roles/components are documented in `DESIGN_SYSTEM.md`.

## Fonts and licenses

- Existing approved Inter with existing `assets/fonts/OFL.txt`.
- Added Noto Sans Arabic Regular/Medium/SemiBold/Bold (400/500/600/700),
  instanced at normal width from the Google Fonts openly licensed variable font.
- Source: https://github.com/google/fonts/tree/main/ofl/notosansarabic
- SIL OFL 1.1: `assets/fonts/OFL-NotoSansArabic.txt`, included in app assets.
- Actual packaged fonts are loaded in widget captures. No DejaVu/test font
  or Android-only fallback is used for these redesigned-flow renders.
- Mixed Latin/Arabic text, numbers, email fields, RTL controls and App/Resume
  independence are covered by regression tests.

## Approved development policy

`supabase/config/dev_mobile_policy.sql` configures only the existing mobile row:

```
minimum_supported_version = 1.0.0
recommended_version = 1.0.0
policy_version = 1
```

`tool/configure_dev_policy.py` uses the existing protected psql mechanism,
explicit isolated-dev opt-in, an authorized-project/host/user check,
certificate/hostname-verified TLS, transaction and advisory lock. It refuses to
overwrite a differing policy and verifies readback and retained RLS.

This is configuration, **not a schema migration**. It does not alter provider
configuration, RLS, staging or production, and no server credentials enter
Flutter. These values require review before any production launch.

The former missing-development-policy blocker is resolved. Real authenticated
RPC/readback passed; it does not prove the precise cause of the older device
exception, for which device logs were not supplied.

## Verification

- `flutter analyze --no-pub`: no issues.
- Final normal regression run: **84 tests passed**; separate real-development
  smoke run: **1 live test passed**.
- `dart tool/check_foundation.dart`: client credential/layout/token checks pass.
- Regression tests run with real SQLCipher, including all existing persistence,
  secure-session, policy, data-preservation and navigation contracts.
- Existing and added bilingual widget tests verify intro/research order, Skip
  boundaries, selection retention/max-three, auth/provider/validation notices,
  app language switching, independent Resume Language, empty Personal fields
  and preservation of typed content.
- Simulated 300px keyboard inset keeps Auth submit scroll-reachable.
- Small-screen/text-scale checks do not suppress or arbitrarily shrink text.
- Updated render baselines are compared normally after generation; captures are
  actual Flutter widget output with injected test service boundaries.
- Explicit real dev smoke test passed: public Auth settings Google=true,
  signed-out startup makes no policy request, confirmed password sign-in,
  memory-adapter SDK persistence/recovery, authenticated guarded startup and
  mobile policy values 1.0.0 / 1.0.0 / 1. Direct client policy-table read denied.
- ARMv7/ARM64 debug build succeeded with genuine dev defines, API minimum 24.
  Artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- Android and iOS icon catalogues are generated from the approved icon, not
  Flutter defaults. Final APK manifest/fonts/native libraries/signature and
  unchanged ZIP integrity are checked during packaging.

The final verification addendum in `VERIFICATION.md` records test totals and
packaged APK identity. No old fixture-writing policy test or schema migration
was rerun against live development during this redesign.

## Captures and review package

`test/goldens/redesign_*.png` contains **31** English/Arabic introductions, all four
research questions, gateway/login/signup, validation and auth error, and
startup/loading/policy error/update-required views. Contact sheets and original
captures are delivered separately; they are explicitly labelled **widget test
renders — not physical-device screenshots**.

`build/review/jobix-dev-debug.zip` contains the unchanged rebuilt APK. Extract
`app-debug.apk` and install it on an actual ARM Android device running API 24+.
It uses development services, not production. It is a review/debug build, not
a production release/signing/deployment.

## Remaining verification and release dependencies

- **No connected physical Android device:** `adb devices` lists none. The owner
  previously identified Galaxy M31 / Samsung M315F/DSN / Android 12 and supplied
  old captures, but has not yet supplied captures/observations for this rebuild.
  Physical installation, native IME/system splash, touch feel, device Keystore,
  session recovery after process death and new-flow acceptance are unverified.
- Google enabled flag is verified, not real browser OAuth. Mail confirmation,
  recovery delivery and deep-link lifecycle need a real inbox/device. No account
  confirmation was bypassed, and no passwords/provider settings were changed.
- iOS icons/launch resources are prepared, but Xcode/iOS compilation and
  Keychain/device review are unavailable here.
- Approved legal URLs and operational production policy/version remain
  pre-launch configuration dependencies, not blockers to this dev implementation.
- Full responsive/assistive acceptance is not equivalent to simulated
  widget dimensions or text scaling.

Stop here. No next feature slice is authorized.