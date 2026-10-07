# 02 — Architecture and authority

## Source documents

1. **Current architecture:** `attached_assets/JobiX_Architecture_V2_1790975874316.md`.
   It describes the account/profile model, RLS, command/idempotency contracts,
   ownership, allowance, Credits, AI state and rendering/storage architecture.
2. **Product rules:** `attached_assets/JobiX_Product_Design_1790975900645.md`.
3. **Non-negotiables:** `attached_assets/Jobix_Constitution_1790975874315.md`.
4. **Design reference:** `attached_assets/DESIGN_1790975900644.md`, subject to
   subsequent explicit owner decisions and current app implementation.
5. **Architecture V1:** `attached_assets/JobiX_Architecture_V1_1790975886719.md`
   is retained for history. `mobile/jobix/FIRST_SLICE.md` explicitly marks V1
   historical and V2 authoritative.

Do not rewrite these inputs while documenting. Read the full relevant section
before making future architectural changes.

## Implemented architecture

- App is Flutter-native; authentication uses confirmed Supabase sessions and a
  startup policy/recovery barrier. Do not trust callback-supplied identity.
- Postgres data is owned by `auth.uid()` through RLS and narrow owner-checked
  RPCs. The client uses publishable/anon configuration, never service-role
  credentials.
- Career Profile is the editable, server-versioned source dataset. Resume
  configuration selects language/template for that source rather than copying it
  into a second editable model.
- SQLCipher protects offline onboarding/account drafts. Replays use frozen
  idempotency keys. Stale versions must be surfaced; never use silent
  last-write-wins.
- User-entered experience/education/projects/certifications/achievements/skills/
  languages remain source facts. AI must produce an explicit, version-aware
  proposal and must never invent user history.
- Current private GCS design is PDF-focused. Do not reinterpret it as public or
  image hosting. Profile images are currently stored separately in a bounded
  owner-scoped database record in the isolated development schema.
- One canonical HTML/CSS rendering representation is intended for preview and
  future Chromium PDF. Existing preview code is foundation, not proof of
  paginated PDF parity.
- Cairo-local date/allowance rules and Arabic RTL must be enforced by the server
  where authoritative.

## Migration sequence

Read SQL migrations `mobile/jobix/supabase/migrations/202610030001...010...` in
numeric order, not by applying a guessed glob to another environment. The
isolated-development helpers under `mobile/jobix/tool/apply_*.py` include
environment guards and readbacks. Production and staging remain separate and
must not be pointed at the development scripts.

New Replit workspaces also contain a pnpm starter at the repository root. It is
not a competing Jobix backend and must not replace the Flutter/Supabase design.
