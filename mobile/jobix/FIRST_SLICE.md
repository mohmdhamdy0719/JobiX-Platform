# First Jobix vertical slice

## Authority and scope

Implemented under the resolved product-owner decisions in
`attached_assets/Pasted-The-product-owner-decisions-for-Task-4-are-now-resolved_1791013262606.txt`.
The existing Foundation, Product Design, Architecture V2 and Constitution
remain authoritative; V1 is historical. The pnpm starter is not the Jobix
runtime.

No AI, ATS, Credits, export, rendering, translation, analytics, premium billing,
background sync, outbox or worker is implemented. Later builder steps are not
invented or exposed as functioning features.

## Implemented contracts

- Exactly three introduction screens, with Skip; approved copy comes from
  Product Design rather than unsupported marketing claims in reference HTML.
- Exactly four ordered research questions; no group Skip, Q4 capped at three.
  Selections and last incomplete question persist in encrypted local storage.
  No anonymous server users or onboarding rows are created.
- Confirmed email/password authentication, Google OAuth boundary, email
  confirmation UI, forgot-password and recovery UI. Native callbacks use
  `com.mhflow.jobix://auth/callback`, secure PKCE/session storage and the
  existing restoration barrier. Client identity never comes from callback
  parameters supplied by the caller.
- Registration's database trigger creates one real, empty Profile #1,
  unlocked slot #1 and empty personal-data record in the Auth transaction.
  Auth user uniqueness and the active-slot unique index prevent duplication.
  No Credits, name, template or Resume-language default is invented.
- New registrations route to Personal Information; returning launches go to
  Home. Server-owned registration-entry metadata distinguishes new Google
  accounts from returning accounts independently of which form was used.
  Home exposes the unfinished Personal step and Continue Career. There are
  no implemented later steps to resume in this slice.
- Full Name, Email and Phone are required only by the future export contract;
  partial values can be saved, retained and left. Country, City, LinkedIn,
  GitHub and Portfolio remain optional.
- App Language controls navigation, research, buttons and dialogs.
  Nullable, explicitly selected Resume Language controls field labels,
  examples and guidance. Existing content is never translated; email,
  phone and URLs remain LTR, mixed content retains its natural direction.
- Country/City are manual and optional. Device region EG can offer an
  explicitly accepted Egypt suggestion. No GPS/IP lookup or silent server
  population occurs. City supports custom values and autocomplete over
  that account's previously saved values only.
- Save explicitly sends a versioned, idempotent command. Failed/unknown
  outcomes retain a frozen request identity inside the encrypted draft for
  explicit Retry; there is no queue or automatic sender. A later edit does
  not change the pending command's payload.
- Leaving dirty work offers Save & Continue Later, Discard or Stay.
  Continue Later retains locally; Discard deletes only unacknowledged local
  drafts. An unknown save outcome must first be reconciled. Version conflicts
  offer latest-server data or an explicit local rebase, never silent
  last-write-wins.
- Acknowledged caches can be used for network errors only, never malformed
  responses, authorization, account lifecycle or missing provisioning.
  Cross-account state is invalidated; in-flight writes cannot restore another
  account's local data after sign-out.

## Minimal Architecture V2 dependency patches

1. Drift schema v2 adds only local onboarding, acknowledged Profile snapshots
   and drafts. The real v1→v2 migration preserves Foundation settings.
   No local server-schema mirror, fake schema version or worker tables.
2. Migration `202610030002_first_vertical_slice.sql` adds the real tables used
   by this slice, owner RLS, bootstrap trigger and synchronous save RPCs.
   The V2 idempotency record's future operation link is nullable because no
   background operations engine is introduced. Inline commands retain
   user/key scope, SHA-256 payload fingerprints, version checks and responses.
3. Migration `202610030003_registration_entry.sql` adds one account-routing
   flag and an owner-only atomic claim RPC. This is required because Google
   OAuth can register or sign in regardless of the button's wording.
   The claim runs only after confirmed authentication and Foundation's policy
   guard. Existing accounts default to returning; no Profile backfill.
   After the first guarded routing claim, a subsequent reopening goes Home,
   even if the user closed the first-entry screen before completing fields.

Both slice migrations are applied to the authorized **isolated development**
database. No staging or production changes were made. Local auth emulation
is never deployed. Live SQL fixtures run inside a rollback-only transaction.
No operational minimum-version policy was seeded.

## Visual sources and missing handoffs

The accepted `attached_assets/jobix_*.html` references provide the shared
blue/navy palette, Inter, surface treatments, typography, radii, controls,
cards, spacing and logo. Flutter renders native widgets; no HTML is placed
in a WebView and no web/Expo replacement is created. HTML references for
AI/ATS/other later screens are visual references only.

Approved onboarding, Home and Personal Information visuals are reused.
Research, confirmation, reset, recovery and conflict dialogs have only the
minimum structural UI using those shared tokens; no separate final frames
for these states were supplied. Original system splash/native launcher icon
acceptance is not claimed. Production Arabic uses platform font fallback;
Arabic goldens use the documented test-only DejaVu font, not a new production
font choice.

No full approved country/city autocomplete catalog was supplied. The history
autocomplete is intentionally limited, not a replacement fabricated catalog.
Adding a complete catalog awaits its approved handoff.

## Verification and remaining gates

Current execution details are in [VERIFICATION.md](VERIFICATION.md).
Flutter tests/goldens verify native widget rendering, but are not evidence of
an Android/iOS device, actual Keystore/Keychain integration or a signed build.

- Restore genuine public development client configuration: the ignored
  `config/dev.local.json` is absent in this checkout.
- Staging/production remain NOT_CONFIGURED; the existing three-project build
  gate is unchanged and must not be bypassed.
- Configure and verify Supabase email confirmation, mail delivery, reset links,
  Google provider credentials and the native callback redirect allowlist.
  Provider boundaries are implemented/tested, but real Google browser/device
  round trips and email delivery are not verified.
- The operational `mobile` app-policy row remains absent, as deliberately
  recorded by Foundation. Its version must be approved by administration;
  authenticated startup fails closed until it exists.
- macOS/Xcode/CocoaPods, physical Android/iOS devices, release signing and
  native build/storage/backup/deep-link acceptance remain unavailable.

Do not claim this source-tested slice is production-ready or use browser
mockups as substitutes for native acceptance.