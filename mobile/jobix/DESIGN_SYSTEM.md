# Jobix native visual system

## Authority and scope

The resumed owner brief supersedes old HTML/screenshot matching for visuals.
Flutter/Riverpod/Drift/Supabase and existing behavior remain authoritative.
This is not an authorization for a dashboard, Settings, builder, AI, ATS or export.

## Visual foundation

- Neutral light canvas (`#FAFBFD`), white content surfaces, navy headings
  (`#14243A`), blue primary actions (`#2563EB`), quiet secondary blue and fine
  neutral borders. No decorative gradients or default Material purple palette.
- Common spacing is centralized in TokensV0: 4, 8, 12, 16, 20, 24, 32, 40,
  48, 56 and 64. Standard phone gutter 20; tablet gutter 28; content max width 560.
- Control radius 10, card radius 12, compact radius 8; zero app-bar/card
  elevation. Rounded cards are used for actual selections and notices, not as
  decorative wrappers around every section.
- Typography role sizes: display 30–36; primary title 28; section 22/18;
  body 16/15; supporting 13; labels 16/14/12. Semibold/bold establish hierarchy.
- English: bundled Inter. Arabic: bundled Noto Sans Arabic 400/500/600/700.
  Arabic body line height 1.7 and headings 1.48; English 1.5 and 1.28.
  Arabic letter spacing is zero. Mixed-script fallback is explicit in text
  and button themes; this matters for the Arabic language label in English UI.
- Body text/blue-action contrast exceeds 4.5:1. Disabled controls are visually
  distinct. Selected rows use tint, border and check mark, not color alone.
  Native accessibility/contrast testing is not claimed by these source checks.

## Shared presentation components

`core/design` owns page/header/scroll structure, brand marks, primary buttons,
cards, section headings, selection rows, notices and branded loading/error
states. Component-specific geometry stays in those shared components rather
than each screen. Material 3 supplies mechanics, not the visual identity.

- Buttons have at least 48 logical-pixel touch targets; primary actions have
  a 52 minimum height and can grow with text, without arbitrary text shrinking.
- Choice rows have a 52 minimum height. Single choices use a circle; Q4 uses a
  checkbox-style control and retains the existing maximum of three choices.
- Empty forms stay genuinely empty. Input examples are hints, never values.
  No fictional CV, demo Profile or invented defaults are added as empty states.
- Headers and gutters use start/end alignment. Scroll areas dismiss keyboard
  on drag. Intros and research have safe-area-aware anchored continuation.
  Auth remains scrollable with keyboard insets.
- Error notices keep semantic state, relocalize without losing typed input, and
  expose a live region. Startup exposes only safe storage/session/policy
  categories, never raw SDK errors, tokens or account information.
- Feedback motion is 170ms, content switching 200ms, Android navigation fade
  220ms. Reduced-motion removes these transitions. Only real loading indicators
  animate indefinitely; illustrations are not permanently animated.

## Brand and native packaging

Use approved dark/primary logo on light surfaces and existing approved white
logo on navy startup. Masters are copied unchanged; no recoloring, redrawing,
cropping or distorted proportions. Android legacy/adaptive icons and all iOS
icon catalogue sizes use the approved white-background icon master. Adaptive
packaging places the original within the safe area so OS masks do not crop it.

Android API 24+ launch layers and API 31+ system splash use the approved mark
on the same navy as Flutter startup. iOS launch assets/storyboard are prepared;
an iOS/Xcode build and device test have not run in this Linux environment.

## Typography licenses and future resumes

Inter was already supplied and approved; its existing assets/fonts/OFL.txt
remains. Noto Sans Arabic comes from Google Fonts:

https://github.com/google/fonts/tree/main/ofl/notosansarabic

The openly licensed variable source is instanced at normal width into
400/500/600/700 files. SIL Open Font License 1.1 is stored and bundled as
assets/fonts/OFL-NotoSansArabic.txt. No system-only Arabic fallback is required.

App Language remains independent of explicitly selected Resume Language.
Future resume rendering should default to Inter/Noto Sans Arabic and preserve
selectable/searchable text, ATS extraction and readability, but resume rendering
and PDF export are not implemented or claimed in this scope.