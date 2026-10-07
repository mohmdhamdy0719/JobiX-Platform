# 00 — Project overview

## Product

Jobix is a bilingual Arabic/English career profile and resume-building mobile
product. It guides a job seeker from authentication through a structured Career
Profile, then uses that profile as the source for a separately configured resume
presentation. The data model, validations and approval rules come from the
preserved Constitution, Product Design, and Architecture V2—not reference HTML
or generated copy.

## Current implementation

- **Client:** Flutter/Dart, Riverpod, GoRouter, Drift with SQLCipher local
  persistence, `supabase_flutter`, native Android and iOS projects.
- **Backend:** Supabase Auth and Postgres; additive SQL migrations, owner-scoped
  RLS, narrow security-definer RPCs, client idempotency/version checks.
- **Language:** English and Arabic with LTR/RTL, IBM Plex Sans Arabic and Inter.
- **Journey:** first-install onboarding/research, Auth/confirmation, provisioned
  Profile #1, six-step builder, Review/Edit, Home/Career/Settings.
- **Resume:** config points at Career Profile #1; templates identify English or
  Arabic output. Selectable-text HTML is displayed in a native WebView with A4
  print styles; there is no actual PDF renderer/export pipeline.
- **AI:** allowance UI reads the server contract; improvement UI is a
  non-generating proposal component. No Gemini/Vertex call, operation/history
  flow, or proposal persistence/apply path is operational.
- **Credits:** the existing account/ledger/balance path and development RPC tests
  exist. Worker-only reservation/release/finalization foundations were added;
  no PDF worker invokes them. No client-side authoritative balance is allowed.
- **Private profile extras:** custom links and optional image data use an
  owner-scoped development database record; this does not reuse the private
  PDF-only GCS bucket or create a public image URL.

## Scope boundaries

The UI or schema for a capability does not imply an operational provider or
worker. At this milestone, AI generation, PDF export, production deployment,
payments, subscription, Professional Email and Cover Letter are incomplete or
deferred. See `07_REMAINING_WORK.md`.

## Workspace boundary

The repository root contains the standard Replit pnpm starter and related
artifacts, but Jobix itself is `mobile/jobix/`. The currently registered API and
mockup workflows are not a Jobix customer-facing app.
