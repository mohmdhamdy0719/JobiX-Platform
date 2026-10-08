# Jobix verification evidence

## Managed image and restricted runtime credential checkpoint

**PARTIALLY VERIFIED; no worker/Edge/Scheduler deployment; exports disabled.**

- Managed build succeeded in `me-central1`; image pushed to existing
  `jobix-dev/pdf-worker`, pinned digest
  `sha256:670a21879bd42deae556d2208b83571e5c0d145c10a58c51423027956412347d`.
- Managed image verification passed actual AOT canonical generator and pinned
  Playwright/Chromium English/Arabic PDF generation/structural/text/font checks,
  plus invalid-PDF rejection. The first synthetic-fixture attempt failed on its
  invalid day-date; correcting to the logical month DTO passed without product
  changes. Host Chromium is not used as a production-engine substitute.
- Created only the approved restricted development LOGIN and encrypted secret
  version. Backend secret access and verified-TLS login passed. Membership is
  exactly export gateway/worker; privileged flags are false; direct export
  INSERT and user UPDATE are denied. No credential output/file or SA key.
- IAM still blocks deployment: custom bucket role exists, but obsolete
  backend `storage.objectUser` membership remains; signing still permits extra
  token/JWT/delegation powers. No IAM policy was changed without grant-removal
  consent. Existing principals must be preserved when correcting scope.
- Canonical/public build source remains retained for retry, no active export
  fixture objects remain, and no real Credit transaction or export activation
  occurred. Full private Edge→worker, Scheduler, and live export/deletion
  journeys remain unverified.

## Operator access update — private backend storage/signing verified

**PARTIALLY VERIFIED; deployment/activation remain blocked.**

- Actual backend-identity `GoogleStorage` adapter passed conditional upload,
  duplicate create rejection, generation-specific inspect/read, IAM self-signBlob,
  private signed download and signed-generation tamper rejection. Anonymous
  access was denied. Signed URL/token/signature were not printed or persisted.
- Only the freshly created synthetic protocol fixture was deleted by exact
  generation; the owned prefix and full active export prefix were verified empty.
  This is not an actual Chromium PDF, Cloud Run metadata identity, authenticated
  Edge export or Credit finalization test.
- Cloud Build inventory/default-builder reads succeeded. Actual submission
  failed on missing deployer actAs of
  `850519041397-compute@developer.gserviceaccount.com`.
- Runtime-secret resource project number was verified against the approved
  bucket. Both numeric/friendly path checks still deny required secret access.
  No runtime database credential/LOGIN was created, read out or substituted.
- Minimum IAM has not passed: observed backend objectUser grant permits
  update/restore/move in addition to approved CRUD. Effective signing permissions
  include token/JWT/delegation operations beyond signBlob. No IAM mutation was
  made; narrowing must preserve unrelated principals/bindings.
- Native/product code and dependency manifests/locks remain unchanged.
  Operational tool syntax and dependency checksum checks passed.

## Development migration and approved cleanup checkpoint

**PARTIALLY VERIFIED; exports disabled; worker deployment blocked by IAM/access.**

Completed against development only:
- Verified TLS with the supplied public Supabase Root 2021 CA; applied all six
  Phase 3 migrations (012–017) in one transaction. Re-running the protected
  runner passed checksum/idempotency checks. The development ledger has six
  entries; both export rollout flags remain false.
- Verified upload-flight RLS, denied client job INSERT/purge/ledger UPDATE and
  private-client table access. No production/staging connection was made.
- Read back private bucket IAM/uniform access; no public principal grants.
  Installed/read back only the approved Delete rule: age seven days, prefix
  `exports/`, suffix `.pdf`. Existing prefix inventory was empty.
- Live DB tests passed canonical preparation, atomic same-key replay, reserve
  two/release on freeze, client table denial, cross-actor status isolation,
  object-absence verification and export snapshot/related-data purge. All
  synthetic identities/data/Credit entries and temporary flag changes rolled
  back; no existing account/profile/completeness/allowance data was modified.
- Live private GCS conditional-create/conflict and anonymous denial tests
  passed with an explicitly synthetic storage-protocol fixture using deployer
  tooling. Its exact generation was deleted and no active export objects remain.
  This does not verify the runtime backend or real PDF/signed download path.
- Bundled the public CA for the managed runtime; uploaded only allowlisted
  source/fonts/licenses/public CA privately for a managed build retry. No
  developer config, credentials or user data is included. The build source is
  retained outside `exports/`; it is not deleted as a test fixture.

Actual blocks: managed build submission 403, custom-role creation 403,
`secretmanager.secrets.create` 403, and no tested storage or self-signBlob
permissions for the backend. No service-account keys, IAM grants, worker,
Scheduler jobs, Edge rollout or runtime credentials were created. No dependency,
Flutter product/signing, AI or billing changes. Full deployed end-to-end
verification and Phase 3 completion remain outstanding.

## Development implementation authorization — current build increment

The owner superseded the recording-only pause with complete Phase 3 DEVELOPMENT
implementation/deployment/live-test authorization. Production/staging, new
service-account keys, AI/billing, broader product changes and unjustified upgrades
remain excluded. Destructive/irreversible cloud operations require approval.

Implemented in this increment:
- Forward-only migration 017: private durable physical-upload flight tracking,
  one unresolved create per job, late-response settlement without Credit
  finalization, distributed quiescence checks, export-only transactional
  snapshot/job/receipt/reservation purge with absence verification.
- Existing account/profile DELETING transitions freeze exports automatically;
  physical deletion cannot cascade away export evidence before cleanup.
  No new Auth/account deletion API, slot policy or immutable-ledger mutation.
- Conditional upload metadata includes the unique fence; matching stored
  source/document/fence evidence reconciles a lost response. Unproved requests
  keep deletion pending. Prefix listing/removal covers orphan objects; absence
  is checked again before snapshot purge.
- Private recovery invokes deletion integration. PDF expiry still preserves
  snapshots/history/replay and never silently regenerates or charges.
- Managed-build Dockerfile and strict context allowlist, same Dart 3.8.0 AOT
  canonical source and locked Playwright engine; no local Docker or version upgrade.
- Guarded opt-in additive development migration runner, single transaction,
  checksum ledger, verified TLS and rollout flags unchanged.

Evidence: canonical AOT compiled successfully and actual AOT/Dart source → host
Chromium/Poppler → disposable PostgreSQL integration passed, including historical
security/credits/RLS tests and new freeze/ambiguous-flight/purge/physical-delete
guards. Production container/pinned browser and deployed end-to-end path are not
verified; no remote migration/deployment/live Credit transaction occurred.
All **36 backend contract/recovery/cleanup tests passed**. JavaScript syntax,
opt-out migration-runner guard, unchanged dependency-manifest/lock checksums and
diff checks passed. No Flutter product/test code changed in this increment;
the previously passing **208 regression + 16 export tests** were preserved.

Authenticated development checks found the approved repository/bucket, no
Cloud Run services/Scheduler jobs, usable backend actAs/impersonation, and
Supabase function-list access. Cloud Build list/Secret Manager list returned
403; backend bucket permission tests returned no granted permissions.
The administrative DB connection failed verified TLS without its trusted root
certificate. Public certificate download and management retrieval were denied;
TLS verification was not weakened. These are access/runtime blockers, not
reopened product decisions. No IAM/bucket/lifecycle/production changes were made.

## Phase 3 local PDF/Credits implementation — 2026-10-08

**Status: PARTIALLY VERIFIED; rollout remains blocked and disabled.**
No live migrations, deployment/IAM/Scheduler/Cloud Run changes, GCS writes/signing
or real Credit operations. Deletion/snapshot policy was not implemented in the
preceding local pass; its product contract is now approved as recorded below.
No signing/APK/build-environment changes or AI work.

### Approved deletion/retention decision — recording only

The exact owner-approved ten-point contract and current restrictions are recorded
in `backend/pdf/ADR-retention-deletion.md`. Product approval is not implementation,
deployment or live-test authorization. All remote gates remain closed.

PDF objects retain the approved seven-day logical lifetime; expiry/missing
downloads never silently regenerate or charge again. Expiry alone does not require
immediate snapshot/canonical-HTML deletion. Explicit Export Again uses current
profile data and costs two Credits. Profile/account deletion must freeze new
export work, invalidate leases, release pending reservations, prevent usable
late/stale objects, remove its export objects/snapshots/related export data and
verify no active export objects/snapshots remain before completion.

No additional retention period or change outside PDF/export deletion integration
is approved. No implementation or test behavior was changed for this record.
Existing fixtures intentionally describe the current incomplete purge path,
not satisfaction of the newly approved full-deletion contract. No tests/builds,
migrations, worker starts, live operations or deployments were run for this update.

### Additional authorized local pipeline/recovery step

**Implemented and fixture-verified; not approved for rollout.**

- Canonical preparation now checks normalized UTF-8 source size in a separate
  source-only pass before HTML/font rendering, using the same Dart generator.
  Snapshots archive exact embedded-font checksums, font-license text/checksums,
  bundle/model/template/config versions and immutable canonical HTML.
- Two additional **unapplied** forward migration files harden null/stale fences,
  active-profile guards, recovery eligibility after lock waits, asset metadata
  and private cleanup hooks. No historical migrations were edited.
- Independent heartbeat/hard-deadline cancellation covers stalled render,
  validation and storage adapters; late results cannot finalize a newer lease.
- Private freeze hooks consume an **already DELETING** account/profile state,
  invalidate job leases and release only pending reservations. They never modify
  Auth or mark account deletion complete. Object cleanup requires an explicit
  quiescence verifier and generation checks. In that local pass the snapshot
  policy was unapproved; purge remains unimplemented despite the subsequent ADR
  approval. Current instructions permit recording only.
- Seven-day expiry cleanup preserves completed charges, history and replay;
  verification markers prevent repeatedly scanning already-cleaned objects.
  Private recovery is wired to the approved PDF-only expiry cleanup hook.
- Client history/download/Export Again eligibility respects active profile and
  ownership; structural invalid URLs are reported rather than silently omitted.

Latest checks:
- **33 Node contract/recovery/cleanup tests passed**, including deterministic
  virtual-clock heartbeat, timeout, stale upload, ambiguous upload/completion,
  conditional-create adoption, asset tampering, pagination, expired objects and
  cleanup races.
- **208 Flutter regression tests passed** with default-off exports.
- **16 opt-in local Flutter checks passed**, including reopened frozen requests,
  explicit visibility/config versioning, paid Export Again, history pagination,
  insufficient-Credit retry, invalid included personal URLs and successful free
  download byte streaming to a mocked save channel without URL persistence.
- Historical + new migrations and SQL lifecycle/freeze tests passed in a
  disposable PostgreSQL cluster. Actual concurrent connections returned the
  same accepted receipt with one reservation. An injected failure between debit
  and job completion rolled back both. Duplicate callbacks debit/release once.
- End-to-end canonical Dart + actual existing local Chromium/Poppler passed:
  free repeat download, paid Export Again, exact-generation expiry cleanup, and
  a real canonical CV over twenty pages rejected before upload/debit.
- Analyzer: zero errors/warnings; two pre-existing standalone fixture import
  infos. Client secret/layout/token checks passed.
- Declared PDF dependencies restored at their existing exact versions into
  the isolated product directory, with its own frozen lockfile. Root manifests,
  root lock and Flutter manifest/lock hashes unchanged.

**Runtime blocker:** the downloaded Playwright-pinned headless browser does not
launch in this Nix/host libc environment. It initially lacked shared libraries;
reusing available libraries exposed incompatible glibc ABI requirements.
No browser substitution, system-library upgrade or cloud image build was done.
The CDP integration uses the explicitly identified existing host Chromium and
does not prove production Playwright runtime readiness. Browser child processes
now receive only approved non-secret environment fields.

Local checks passed:
- Standalone Dart EN/AR structural validity, unscored Volunteer, optional
  descriptions, explicit visibility and contact rules.
- Sixteen built-in Node contract checks: transport-idempotency, replay before
  mutable reads, pre-reservation conflicts, input rejection, free download,
  confirmed missing vs transient object failures, fenced worker/proof ordering,
  20-page overflow before upload, concurrency slots, text preservation and
  fail-closed private authentication/startup/TTL.
- Existing historical and new forward-only migrations applied successfully to
  disposable PostgreSQL. Synthetic tests cover default-off gates, immutable
  snapshots, exact replay after edits/old receipt pruning, owner isolation,
  no reservation on stale versions, stale leases, successful single debit,
  repeated completion, missing-file handling, expiry release, role restrictions
  and configuration/profile-version increments without completeness/AI change.
- Real disposable SQL + server canonical Dart HTML + actual local Chromium PDF
  with verified English/Arabic text + exactly one debit + free repeat downloads.
  Storage is explicitly an in-memory test adapter, **not GCS**.
- Existing print checker self-tests: 21 passed.
- All 16 canonical EN/AR print fixtures passed all 304 cohesion checks, text,
  embedded-font and A4 checks. No baseline was refreshed.
- Owner-authorized locked Flutter/Dart package restoration completed.
  `pubspec.yaml` and `pubspec.lock` hashes are unchanged; no upgrades.
- Full Flutter regression suite: **208 passed**, with export disabled by default.
- Opt-in local export-control suite: **9 passed**, using synthetic HTTP fixtures
  and disposable encrypted SQLCipher. Covers exact server Preview bytes, explicit
  visibility/structural evidence, English/Arabic phone-width layouts, cost
  confirmation without submission, ambiguous acceptance followed by reopening
  and same-key reconciliation, expired downloads without replacement, and
  explicit Preview review after confirmed version conflicts.
- Flutter analysis has **zero errors/warnings**. Run with
  `--no-fatal-infos`; two pre-existing informational relative-import notices in
  the standalone print-fixture tool remain. Client secret/layout/token checks pass.

Not verified: Android SAF/real-phone controls, production Playwright runtime packaging, deployed Edge/OIDC,
private GCS/IAM/runtime TLS and live reservation recovery under cloud failures.
The earlier missing-cache analyzer failure was resolved by owner-authorized
restoration, not by upgrading packages or weakening product validation.

See `backend/pdf/README.md` for reproducible local checks and closed readiness
gates. Source work is local only; this evidence is not rollout/device acceptance.

## Offline Resume print regression suite — 2026-10-08

**Status: PASSED.** This is synthetic canonical-renderer verification, not
Android/WebView/phone acceptance or a PDF export feature.

Run from the repository root:

```sh
python3 -m unittest discover -s mobile/jobix/tool -p test_resume_print.py -v
# Also run the existing visual-checker self-tests (no baseline refresh):
python3 -m unittest discover -s mobile/jobix/tool -p 'test_resume_print*.py' -v
python3 mobile/jobix/tool/check_resume_print.py
# Optional: retain synthetic HTML/manifest/DOM/PDF/text/screenshots/report in /tmp
python3 mobile/jobix/tool/check_resume_print.py --keep
```

Requirements are a POSIX host, Python 3.10+, the **existing** Dart SDK, Chromium,
`pdftotext` and `pdffonts` on PATH, and the packaged Inter/IBM Plex Arabic fonts.
The suite is Python
stdlib-only. It reports missing tools rather than installing them. Direct Dart
VM execution and relative imports of the existing pure-Dart canonical sources
avoid package restoration, CLI telemetry and the missing Flutter lint cache.
The existing comparison-fixture command remains available without
`--regression`. No dependency/configuration or analyzer-rule changes were made.

### Automated coverage and observed results

- **16 fixtures passed:** short, long, four varied page-boundary profiles,
  plus two populated credential/language profiles in each of English and Arabic.
  All repeatable fixture fields pass the current
  structural validator. Names, email and portfolio contacts include long cases.
- HTML uses `ResumeRender.html` directly, the packaged fonts and unchanged
  canonical CSS/CSP. The suite checks language/direction, model/template
  revisions, stable template IDs and profile metadata.
- Valid authored UL/LI grouping, plain/numbered paragraphs, blank paragraphs,
  per-record text/metadata preservation and ordered descriptions are checked
  against the input manifest. Paid Work and Volunteer remain separate.
  Skills remain one selectable compact paragraph with every skill in order.
- The four added fixtures populate Certifications, Achievements and Languages
  alongside the existing sections. They check each title, issuer, issue/expiry/
  achievement month, credential ID, authored description and safe HTTPS URL
  against the source manifest. Link text and DOM href must both match, including
  query-string punctuation. Expiry labels and all five proficiency labels
  (Basic, Conversational, Professional, Fluent, Native) must use the selected
  English/Arabic translation in the correct record.
- Minimal credentials/achievements have empty optional descriptions, dates,
  credential IDs and URLs; no phantom expiry label or link is allowed. Long
  issuer text, IDs, URLs and mixed-direction multiline descriptions remain
  within the actual field limits. Every language has a mixed-script SQL island.
  Missing/moved titles and unexpected extra records are rejected.
- PDF extraction preserves complete normalized visible characters, including
  punctuation and repeated text, rather than just checking a final sentinel.
  NFKC normalization and removal of whitespace/direction controls accommodate
  Arabic shaping/visual ordering without hiding lost punctuation or content.
  Unique Latin markers also prove each authored Work line survives exactly
  once; long fixtures exercise entries split across pages.
- All pages are A4; the canonical page rule must specify **18mm margins**.
  Extracted text boxes are checked for clipping/overflow. Vertical font-box
  tolerance is 5pt because Poppler's ascent/descent boxes are not painted ink
  (the 24pt Inter heading extends about 3pt above its CSS line box). Horizontal
  tolerance is 1.5pt. No arbitrary long-document page count is enforced.
- **304 heading/metadata cohesion checks passed**, using same-page first
  content, actual line positions and observed heading-font boxes. This avoids
  mistaking an Arabic section word repeated in metadata for a second heading.
- Both short fixtures are one page. Long fixtures were seven pages in English
  and five in Arabic; boundary fixtures were three pages in this toolchain.
  Expanded fixtures must exercise pagination, not match these exact counts.
  Added credential cases were three pages per language; their long variants
  were six pages. These observed counts are not assertions. The original short
  one-page contract remains unchanged.
- Both packaged font faces load; printed fonts are embedded with Unicode text
  extraction, with no unexpected fallback fonts or whole-entry page locks.
- **12 logical/print checker self-tests passed** (21 including the nine
  existing visual-checker self-tests), including intentionally missing/reordered
  text, missing skills/metadata/punctuation, wrong revisions/page geometry,
  malformed lists, font failure, overflow and orphaned headings.
  The new negative checks remove each credential/achievement field and all
  five proficiency labels independently from DOM and extracted PDF text, and
  reject untranslated labels, changed hrefs, spurious optional values, moved
  records and changed section order.

The original 12 fixture inputs, including all three selected visual-baseline
cases, are unchanged. This extension does not generate, approve or refresh any
visual baseline. The opt-in visual results below describe the earlier reviewed
run, not a new visual comparison for the added credential cases.

The browser uses a local DevTools pipe, not a listening server. HTTP(S) requests
are blocked and background browser networking is disabled. Tool subprocesses
receive only boot/environment settings, not application credentials. Files are
temporary and synthetic; successful evidence is deleted unless `--keep` is
requested, and failure evidence is retained for diagnosis.

No Flutter product source, Auth/Supabase/database/RLS, scoring/AI state,
architecture, Android signing/build configuration or dependency files changed.
No supporting services, live-data, AI or APK-build operations ran. Existing
APK/build artifacts are preserved.

## Opt-in offline Arabic/RTL visual guard — 2026-10-08

**Status: PASSED.** All 12 logical/print fixtures and all 17 checker self-tests
passed. Seven representative PDF pages matched the explicitly reviewed baseline
with zero changed pixels. Negative self-tests reject joining/mark-like ink loss
or addition, weight/position changes, dimension changes, altered candidates,
unreviewed baselines, engine/font/policy drift and missing page coverage.

Visual snapshots **complement all logical text, embedded-font, geometry and
heading-cohesion assertions above; they never replace them**. The same Dart
canonical renderer and local Chromium DevTools pipe produce the PDFs. Existing
`pdftoppm` rasterizes them at 96 DPI; no dependency installation, second product
renderer, HTTP server, app/API startup or live account/data is involved.

The representative set covers every PDF page of Arabic short, Arabic boundary-10
and English boundary-10 (currently seven pages). Arabic synthetic content adds
joined letters/lam-alef, tashkeel, punctuation, quotes and Latin SQL/C++/R&D/date
islands; existing contacts, mixed skills and long headers exercise bidi/wrapping.
PNG previews and RGB PPM comparison rasters are temporary/ignored only.

```sh
python3 -m unittest discover -s mobile/jobix/tool -p 'test_resume_print*.py' -v
# Candidate directory MUST be new. Generation does not approve anything.
python3 mobile/jobix/tool/check_resume_print.py \
  --visual-candidates mobile/jobix/.resume-visual-baselines/new-review
# OPEN EVERY generated PNG. Compare with prior approved PNGs if available.
# Check joining, diacritics, punctuation, Latin island order, contacts/dates,
# weight, spacing, header wrapping, alignment and page continuations.
python3 mobile/jobix/tool/resume_print_visual.py \
  --approve mobile/jobix/.resume-visual-baselines/new-review \
  --review-note "Describe which pages/features were visually checked and why accepted"
# Only an explicitly reviewed manifest can be compared:
python3 mobile/jobix/tool/check_resume_print.py \
  --visual-baselines mobile/jobix/.resume-visual-baselines/new-review --keep
```

The ignored `mobile/jobix/.resume-visual-baselines/current` set was explicitly
visually reviewed page-by-page for this change. Review found joined Arabic,
visible diacritics/punctuation, intact LTR contact/date/skill islands, wrapped
long headings and unclipped page continuations. This is an agent-reviewed host
baseline, **not owner design approval, native WebView or real-phone acceptance**.
Because evidence is intentionally not committed, a fresh checkout must obtain
the retained reviewed directory or generate **and deliberately review** new
candidates; a missing baseline is a failure, not an auto-update.

Recorded capture versions: Chromium **152.0.7977.64**, revision
`506c834ecceaa943c5f41e6cfe7f68acb5c45346`, JS **15.2.124.18**;
Poppler **26.06.0**, Linux x86_64. Font binary SHA-256 fingerprints (version
authority, including any internal font-name/version changes):

- Inter.ttf: `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031`
- IBMPlexSansArabic-Regular.ttf: `6f611412270a132bbac838da9259d4c68569b4175f3b3b8fa3fa36a30b56dab9`

Each manifest records these engine/font fingerprints, capture policy, source
hashes, image hashes and a separate explicit review note/time. Changing
Chromium, Poppler, fonts, platform, DPI/tolerances, fixture content or page
coverage fails closed. Generate a *separate* candidate set and inspect **all**
pages deliberately; do not automatically bless the new output or loosen
tolerances to hide regressions. Candidate generation cannot overwrite an
existing directory, and approval verifies PPM/PNG integrity before recording
review. Baseline PPM integrity is also checked during comparison.

Tolerance: ignore RGB channel changes <=24/255, allow at most **1.5% changed
pixels relative to ink** over the page, and at most **12%** within any 64x64
tile (minimum denominator 32 ink pixels). Ink means either image has a channel
below 245. This tolerates minor antialiasing, not page-sized white-space dilution
or broad font/position changes; local tiles catch small missing joins/marks.
Dimensions must match exactly; no image registration, cropping or blurring
hides shifts. This is not a guarantee of catching every subpixel defect.

On failure the suite retains current PDF/PNG/PPM evidence in `/tmp` and writes
a red changed-pixel `*-diff.ppm` where pixel comparison ran. Open that alongside
the approved PNG; `report.json`/`visual-manifest.json` on successful runs record
the results. Poppler may emit existing Type 3 glyph bounding-box warnings while
rasterizing bullets; these do not waive text/font checks or visual comparison.

## Phase 2 — Volunteer and targeted Resume refinements — 2026-10-08

**Status: implementation, local checks and authorized development rollout
verified; native acceptance remains BLOCKED / NOT VERIFIED.** Remote execution
occurred only after explicit owner approval and secure access provisioning.

### Implemented

- A first-class `volunteer` type and `volunteer_experiences` snapshot array;
  separately stored owner-scoped records through the additive
  `202610080011_volunteer_experience.sql` migration.
- Organization, Role/Title, optional Location, month range, current toggle and
  optional Description with the approved limits. Current roles clear stale
  end months; zero-year dates are rejected.
- Create/edit/delete entry points in Career Profile, builder Step 3 and Review,
  English/Arabic labels, unchanged six-step navigation and the accepted
  explicit-Save/discard/quality-warning policy.
- Generic encrypted drafts/outbox reuse, version/conflict handling, frozen
  unknown-Save replay and canonical profile cache. No local database schema or
  dependency version changes.
- Volunteer is distinct unpaid ATS/profile evidence and a separate Resume
  section. No new ATS/AI operation or paid-employment classification.
- Compact plain-text Skills and valid semantic lists for explicitly authored
  bullets, preserving prose, blank lines and ambiguous numbering.
- Centered personal header selected after current/centered EN/AR comparisons,
  including long names/contacts. It separates personal information from the
  body while retaining conventional text and mixed-script isolation.
- Shared canonical HTML/CSS retains A4/margins, embedded Inter/IBM Plex Arabic,
  escaping/CSP and existing template IDs. Renderer/model revision metadata is
  2; this is not a completeness algorithm revision. Metadata/header cohesion
  improved without whole-entry pagination locks or a second PDF renderer.

### Completeness and AI-state boundary

Volunteer never qualifies for percentage credit or a scored evidence count.
The existing Contact/Evidence/Skills/Summary/Languages/Target Role weights,
30 + 15 evidence qualification, algorithm/version and 50% latch are unchanged.
Volunteer mutations update only profile/item versions and timestamps; they
do not invoke completeness recomputation or update its trigger column.
The migration contains no scoring/AI-state backfill.

No product Auth or AI code, historical migration, Android signing/configuration,
supporting Node service, package/lockfile, staging or production resource was
changed. The disposable SQL fixture alone gained the role/schema shape needed
to execute the existing later-foundation tests; it must never run on Supabase.

### Passed checks

- `dart tool/check_foundation.dart config/dev.local.json`.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: **204 tests passed**, using real
  SQLCipher and packaged production fonts.
- EN/AR Volunteer widget Save/edit/discard/delete and quiet pre-Save/empty
  descriptions, generic Back regressions and Review return paths.
- Encrypted host database reopening with a lost Volunteer Save response,
  retained frozen key, no duplicate record and unchanged 45%/algorithm.
  This is not native Keystore/process-death proof.
- `bash tool/test_rls.sh`: existing foundation and later Resume/AI foundations,
  populated-database Volunteer migration, exact old acknowledgement replay,
  CRUD/idempotency/conflicts, malformed input, anonymous/cross-owner/direct-write
  denial and deleting/deleted-account guards.
- SQL non-regression at 0%, 45%, 50%, 55%, including a legacy above-threshold
  profile with no allowance row: Volunteer operations preserve profile scoring,
  AI rows, wallet and ledger. Normal paid evidence still contributes 30 then 15.
- Chromium static canonical fixtures: short EN/AR documents each print as one
  A4 page; long EN/AR documents print as seven/five A4 pages. All 96 authored
  test lines per language and final skill text are retained. Long names/links
  wrap without clipping. These are offline print fixtures, not PDF export.
- Reviewed host-native Career/builder captures and canonical EN/AR header
  comparisons. Only Career and builder Steps 3/6 golden references changed.
- Existing Phase 1 ARM64 APK retained with SHA-256
  `88e58035b912ddb43208ace1ee947e1ef3f89cf880851982c0a7074ec08315c5`.

Canonical comparisons are reproducible with
`dart tool/render_resume_fixtures.dart <output-directory>` from the native app
directory; only synthetic, explicitly labelled fixture data is used.

### Approval/readiness gates still open

**Development gate resolved:** the owner approved
`lmouxhbjhtqdtiqijcee` and supplied `JOBIX_DEV_DATABASE_URL` through the secure
form. No credential value was printed or committed.

- `python3 tool/apply_volunteer.py` passed read-only target, verify-full TLS and
  installed-contract checks. The pre-existing scoring, snapshot and mutation
  bodies matched the approved baseline.
- `python3 tool/apply_volunteer.py --apply-approved-dev` applied only the
  additive Volunteer migration. In-transaction exact comparisons proved that
  all existing profile, AI, wallet and idempotency rows were unchanged.
- The protected live transaction passed Volunteer CRUD/replay/conflicts,
  ownership and actual Supabase role/RLS checks, malformed-input rejection,
  legacy paid 30 + 15 qualification and Volunteer non-credit/latch/allowance
  invariants. Synthetic test Auth/app/credit rows were rolled back.
  No disposable local Auth schema or role fixture was applied to Supabase.
- Historical acknowledgement preservation was checked during migration;
  same-key replay was checked live. Replay of a pre-migration response lacking
  the Volunteer array was separately verified in the disposable local suite.
- `python3 tool/check_volunteer_http.py` confirmed anonymous HTTP Volunteer
  reads and mutations are denied with permission code `42501`. No rows were
  exposed or written. This is not authenticated SDK/phone journey proof.
- A subsequent read-only target/contract check passed against the installed
  Volunteer wrapper and unchanged previous implementations.
- Only the explicitly authorized development target was used. No staging,
  production, product Auth configuration, old migration or AI operation changed.

1. **Native acceptance/signing:** no Android device is attached and the
   previously used debug keystore is absent. No new key, signed APK or phone
   installation was generated. Recover the correct signing key or obtain
   explicit approval for an alternative test arrangement; do not uninstall
   or clear existing M31 data to bypass an update-signature conflict.
2. Actual Android WebView appearance, authenticated SDK/phone Save/edit/delete,
   phone restart and device-specific lifecycle behavior remain unverified until
   that gate is resolved. Host tests/Chromium/live SQL are not substitutes.

No later phase or supporting-service repair was started.

## Fresh Samsung M31 ARM64 development APK — 2026-10-08

After the native bug-fix phase, the owner explicitly approved installing the
missing Android build tools, accepting SDK licenses and recreating the ignored
development build settings. This removes the earlier APK-build setup blocker;
it does **not** establish real-phone runtime acceptance.

- Built the merged native bug-fix source at
  `12af109219041d7a667c2ca88aa382bf382c32ee`, without product code,
  Auth/Supabase/RLS, dependency-version or supporting-service changes.
- Installed Android command-line tools 12.0, platform 36, build tools 35.0.0,
  NDK 27.0.12077973 and CMake 3.22.1 into ignored workspace storage. Gradle
  also installed platform 34 for an existing plugin's build requirements.
- Restored locked Flutter/Dart packages and recreated only the ignored
  `config/dev.local.json` using the existing public development settings.
  `dart tool/check_foundation.dart config/dev.local.json` passed.
- Successful command, with workspace-local Android SDK and Gradle cache:

  ```sh
  flutter build apk --debug --target-platform android-arm64 --split-per-abi \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `deliverables/jobix-m31-native-bugfix/jobix-m31-arm64-dev.apk`.
  Size: **97,399,913 bytes**. Package: `com.mhflow.jobix`. Version: 1.0.0 (1).
  Minimum Android API: 24 (Android 7.0). Target/compile API: 36.
- Packaged native code is ARM64 only (`arm64-v8a`), including Flutter and
  SQLCipher. `apksigner verify` passed with APK Signature Scheme v2.
- APK SHA-256:
  `88e58035b912ddb43208ace1ee947e1ef3f89cf880851982c0a7074ec08315c5`.

### Signing continuity warning

No previous debug keystore existed in this workspace. The new build has a
new debug signing certificate:
`7c16b8b1283ed20a73b25ac595152ec5b9df55ed3de6db08aa467ecb9d2380be`.
It differs from the previously archived builder APK's certificate
`109e7d8f025f4999cd084c8a1841aca199344a515d9482b52fa192617f326f6b`.

If that earlier build is installed on the phone, Android will reject an
in-place update with this new certificate. **Do not uninstall Jobix or clear
its data to bypass the conflict.** Recover the original signing key, or obtain
separate approval for another safe testing arrangement. The earlier APKs and
archives remain unchanged.

The new APK has not been installed or launched on the Samsung M31 by the agent.
The original phone crash, physical/predictive Back and WebView behavior still
require actual phone testing. This is a development/debug APK, not a production
release or publication.

## Native bug-fix phase — 2026-10-08

**Status: BLOCKED / PARTIALLY VERIFIED.** The approved five-bug native changes
are implemented and host-verified. Real Android acceptance remains open. This
is not a claim that the reported opening-time phone crash has been reproduced
or fixed on Android.

### Reproduction and lifecycle evidence

- Flutter 3.32.0 host widget test, using an existing Arabic/NATIVE language
  fixture: open its Edit menu, change proficiency to FLUENT, Save, reopen the
  editor, then dismiss with system Back.
- Opening and the first Save did not fail in this reproduction. On dismissal,
  the original implementation produced `A TextEditingController was used after
  being disposed`, followed by an overflow and the reported
  `framework.dart:6161` / `_dependents.isEmpty` assertion. The complete pre-fix
  output is retained in `docs/verification/language-dismissal-before.txt`.
- The modal pop-result future completed before route unmount, while the
  caller immediately disposed the controller. The sheet now owns its state
  and disposes the controller at widget teardown. Assertions are not hidden
  or suppressed; dependency versions were not changed.
- The regression now passes for opening, proficiency selection, Save,
  reopening, dropdown dismissal, Stay/Discard, sheet Back and parent Back.
  The owner's original Android opening-time stack is still needed to confirm
  whether it has the same primary failure.

### Implemented boundaries

- Central modern Back handling provides meaningful parent destinations,
  keyboard/modal precedence, reentrancy protection and localized EN/AR root
  exit confirmation. Editor overrides cover loading/error branches and block
  leaving during an active Save. Resume preview Back closes preview state
  before returning to Career; its renderer/configuration is unchanged.
- New repeatable drafts remain editor-only. Back drains queued local writes
  before scoped discard; existing-record edits offer Stay/Discard and retain
  the saved baseline. Explicit Add can resume an interrupted editor-only
  draft without showing it as a saved parent-list record.
- Skill suggestion selection only edits the input. Explicit Add/submit commits
  a skill. Language edits use explicit Save; Back does not submit them.
- Unknown Save outcomes retain their exact frozen outbox request and explain
  that an already-sent Save cannot be undone by Back. Parent-list navigation
  does not automatically replay it; explicit Retry remains available.
- Empty/whitespace optional prose is quiet. Non-empty short prose receives
  quality guidance only after explicit Save activity or saved reopening.
  Existing field limits and completeness calculations remain unchanged.
- Only the Country/City leading icons were removed. Suggestions, clear
  controls, selection and existing field behavior remain in place.

### Completed local checks

- Locked Dart/Flutter packages restored with `dart pub get --enforce-lockfile`,
  after explicit owner approval. `pubspec.yaml` and `pubspec.lock` are unchanged.
- `flutter analyze`: **PASS, no issues**.
- Full `flutter test --reporter expanded`: **PASS, 195 tests**. Includes EN/AR
  narrow layouts, all seven existing repeatable editor patterns, delayed local
  write/discard, unresolved Save preservation, explicit skill submission,
  modal/dropdown/root Back, keyboard-first Back, error-state Back and busy Save.
- A final saved-empty-description check also passes in both the parent list
  and Review. Review's descriptive badge is separated from server completeness;
  its existing golden and edit-navigation checks still pass.
- `dart tool/check_foundation.dart`: **PASS**.
- `bash tool/test_rls.sh`: **PASS**, disposable local PostgreSQL only, not live
  Supabase. No migration, schema, Auth, RLS or remote configuration was changed.
- Three golden baselines were updated only for the requested Country/City
  icon removal and replacing the obsolete Save & Continue Later control with
  Back. The final full suite compares successfully against those baselines.

### Remaining native gate and preserved work

The current workspace lacks the Android SDK directory and the ignored native
development define file. An authorized Android device/emulator and required
development configuration were not supplied for this phase. No SDK/tooling was
installed, APK rebuilt/installed, live account used or Android launch performed.
Physical IME/gesture/predictive Back and the actual Android language-edit crash
remain unverified; Resume WebView native Back also needs device acceptance.

Earlier ARM64 build evidence below and existing distribution APK/ZIP files are
preserved as historical results, not builds of these changes. Supporting
Node/browser/API services, their dependencies, Auth flows, Supabase/database/RLS,
scoring, architecture and later feature phases remain outside this work.
No Git reset, rebase, force push or history rewrite was performed. Stop here;
no new or archived follow-up task is started.

## ARM64 review build and Android access check — 2026-10-07

- Recreated the ignored development-only `config/dev.local.json` from the
  approved public workspace settings. `dart tool/check_foundation.dart
  config/dev.local.json` passed. Staging and production remain unconfigured.
- Installed Google command-line tools 12.0, Android platform 36, build tools
  35.0.0, NDK 27.0.12077973 and CMake 3.22.1 under ignored workspace storage.
  Android licenses were accepted; Flutter reports the Android toolchain ready.
  Flutter's license check emitted a non-fatal SDK XML version warning.
- `flutter pub get` passed. From `mobile/jobix`, this ARM64 development build
  passed:

  ```sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug --target-platform android-arm64 --split-per-abi \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`
  (97,380,913 bytes), package `com.mhflow.jobix`, version 1.0.0 (1), minimum
  Android API 24, target/compile API 36. The packaged Flutter engine is ARM64.
  APK signature verification passed using APK Signature Scheme v2.
- SHA-256:
  `5b91498893ed9467c2b9c56c1c8b03ba9a58af3cf112f4d354c68099d155d2b7`
- **Physical-device acceptance remains blocked.** `adb devices -l` returned no
  Android devices and Flutter lists only the Linux host. No installation or
  Android launch occurred. Signup email delivery/callback, Keystore-backed
  persistence, Career Profile editing and Resume preview therefore remain
  unverified on a phone. An authorized Android device and, for signup, an
  owner-approved test inbox are still required. An APK build is not device
  verification.
- No product code, database, RLS, Auth settings, staging or production settings
  were changed.

## Real-flow development verification — 2026-10-05

### A. Verified live

- `tool/live_builder_flow_test.dart`: actual Flutter screens against development
  Supabase (no fake Auth/Profile/Core APIs). Confirmed test-account sign-in,
  real startup policy, one stable Profile #1 across repeated reads, six-step
  Continue/Back flow, personal/summary saves, saves in all seven entity sections,
  multiple experience entries, invalid-month Save rejection without a server
  mutation, confirmed experience deletion, Review → Edit → Save → Review, and
  Career using the same profile.
- A successful real mutation acknowledgement was deliberately dropped by the
  host transport. SQLCipher was closed/reopened, the app/providers/SDK recreated,
  and the session recovered. The persisted outbox replayed the original key:
  server version stayed unchanged and each created item appeared exactly once.
  This is host app reconstruction, not Android process-death verification.
- Temporary items were deleted and original personal information, Resume
  Language, summary and existing items restored. The first fake-clock harness
  run required restoration from prior server acknowledgements; the final
  real-time-binding pass completed and verified its own cleanup.
- `tool/live_dev_redesign_test.dart`: confirmed Auth, SDK recovery/startup policy
  and denied direct policy-table access passed.
- `tool/live_profile_sections_test.dart`: live replay, VERSION_CONFLICT,
  VALIDATION_FAILED, DUPLICATE_ITEM, owner B isolation and deletion passed;
  temporary items removed, completeness and Credits unchanged.
- Development Auth configuration was read from the Management API:
  email enabled, signup enabled, confirmation required, built-in mailer,
  two emails/hour and native callback allowlisted. No settings were changed.

### B. Verified with host tests/mocks only

- Full default Flutter suite: 145/145 passed; analyze clean; foundation
  client-secret/layout/token/config checks passed.
- English/Arabic invalid-month draft → Back → disk close/reopen → Edit
  regressions cover experience, education, certification, achievement and
  project drafts. Month labels preserve invalid/incomplete input without a crash.
- AR/EN/RTL layouts, empty states, stale-draft choices and exhaustive Review
  section navigation are covered by host tests, not a physical Android device.
- Live UI test session storage is memory-only. SQLCipher is real disk storage;
  Android Keystore and native App Links are not supplied by this host harness.

### C. Fixed during this verification

- Month formatting now checks the range before indexing localized month names.
  Invalid persisted drafts remain visible/editable; Save validation remains strict.
- Added the opt-in real-network Flutter UI/restart/fault-injection regression.
  It uses a real-time binding and private temporary restoration snapshots.
- No redesign, new features, architecture changes, RLS changes, auto-confirmation,
  external SMTP, AI/model evaluation, staging or production work.

### D. Still requires the Samsung and an authorized inbox

- No connected Android device, installed emulator or `/dev/kvm` is available.
  An APK build is not an installation/launch/runtime test.
- Fresh Sign Up → delivered confirmation email → confirmation callback →
  Sign In → first-registration Step 1 has NOT been verified end to end.
  Existing confirmed accounts work, but that is not proof of new-user delivery.
- Supabase's built-in mailer sends only to project-team addresses, at the current
  two-email/hour limit. The management credential cannot read organization/team
  membership (HTTP 403); no inbox integration is available. An owner-approved
  unused team-member email and owner access to its inbox are needed. Do not use
  an assumed plus alias, auto-confirm, disable confirmation or add external SMTP.
- On the Samsung: install/launch, fresh confirmation link, actual force-stop
  and relaunch, Keystore-backed recovery, offline/interrupted saves,
  native Back/keyboard/scrolling and Arabic RTL must still be checked.
- Official mailer restrictions:
  https://supabase.com/docs/guides/auth/auth-smtp

### Development APK

- Built ARM64 debug APK, package `com.mhflow.jobix`, version 1.0.0 (1),
  minimum Android API 24, target API 36; APK Signature Scheme v2 verified.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.
- Download: `build/verification/jobix-dev-arm64-debug.zip`. Extract first.
  Archive integrity passed. Raw APK exceeds the Library file-size limit.
- SHA-256:
  `545e012cff5ed3fe5ef9604a93a049045a947396a9405690bd8bef9a9d48fe67`.
- Exact command in this workspace:

  ```sh
  cd mobile/jobix
  source /tmp/jobix_env.sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug --target-platform android-arm64 \
    --split-per-abi --dart-define-from-file=config/dev.local.json
  ```

- Existing `config/dev.local.json`, Flutter/JDK/Android SDK and accepted licenses
  are present here. Outside this workspace, supply the genuine development
  configuration and equivalent build toolchain; never put privileged/test-user
  credentials in Dart defines.
- On the computer connected to the Samsung, after extracting the download:

  ```sh
  adb install -r app-arm64-v8a-debug.apk
  adb shell am force-stop com.mhflow.jobix
  adb shell monkey -p com.mhflow.jobix -c android.intent.category.LAUNCHER 1
  ```

  If installation reports a signing mismatch, do not uninstall or clear app
  storage without first preserving data and agreeing on that destructive step.

### E. Exact next recommended task

Samsung acceptance of this development APK, using a fresh Supabase-team-authorized
email: complete signup/confirmation/first entry, all six steps, Review editing,
force-stop/session recovery and offline-save recovery. Fix only observed native
issues. Volunteer Experience and other feature work remain subsequent tasks.

## Screenshot-inspired onboarding update — 2026-10-03

Only the three existing native Flutter introduction screens were revised using
the owner's newly supplied CV, AI-assistance and export/update screenshots.
Approved copy, Skip/Back/Continue behavior, persisted progress, language
switching and the four-question boundary are unchanged. Illustrations are
static, text-free and excluded from accessibility semantics; they do not
introduce AI/export actions, fictional CV facts or unsupported ATS claims.

- `flutter analyze --no-pub`: no issues.
- `dart tool/check_foundation.dart`: passed.
- Ordinary `flutter test --no-pub --reporter expanded`: **88 tests passed**,
  including normal golden comparisons after refreshing only onboarding
  baselines. Four added regressions exercise English/Arabic at 320×568 and
  800×1280 with 1.6 text scaling, reachable fixed Continue, and ordered entry
  into research. Existing auth/profile/draft tests remain passing.
- Actual Flutter English/Arabic renders were visually inspected. Contact
  sheets are `build/review/jobix-onboarding-en.png` and
  `build/review/jobix-onboarding-ar.png`, not physical-device screenshots.
- Development ARM debug APK rebuilt with genuine existing dev defines:
  `build/app/outputs/flutter-apk/app-debug.apk`, 166,618,451 bytes.
  SHA-256: `644df21326c6c011886fe10664798f1fab63340b01b70b07e6b6a4ea4b86a508`.
- APK v2 signature verification passed. Its signing certificate matches the
  previous delivered APK; no uninstall or deletion of local data is required.
- `build/review/jobix-onboarding-debug.zip` contains the unchanged
  `app-debug.apk`, 75,475,988 bytes compressed. ZIP integrity and extracted
  APK hash equality passed.
- No dependencies, localization copy, research/auth behavior, architecture,
  database, provider/policy settings, staging or production were changed.

Physical installation, device rendering and native lifecycle/security acceptance
remain unverified; prior separately recorded live-service evidence was not
rerun or replaced by these widget renders.

## Current delivery — original native redesign, 2026-10-03

The owner's resumed brief supersedes earlier blocked audit/HTML-matching status.
See [VISUAL_REDESIGN_REPORT.md](VISUAL_REDESIGN_REPORT.md) and
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Older sections below are historical
evidence, not current font/icon/policy status.

### Passed

- Final `flutter analyze --no-pub`: no issues.
- Final ordinary `flutter test --no-pub --reporter expanded`: **84 tests passed**,
  including normal comparisons against refreshed visual baselines. Actual
  SQLCipher is used for persistence tests.
- `dart tool/check_foundation.dart`: credential, directional-layout and shared
  design-value checks pass; `git diff --check` has no whitespace errors.
- Real isolated-dev smoke test: **1 live test passed**. Public Auth settings
  Google=true; signed-out startup performs no policy request; confirmed real
  password sign-in, SDK memory-adapter persistence/recovery and authenticated
  startup pass. Authenticated policy RPC returns owner-approved dev
  1.0.0 / 1.0.0 / 1; direct policy-table read remains denied.
- Development-only policy configuration uses the existing protected psql
  mechanism and certificate/hostname-verified TLS. No schema, RLS, production,
  staging or Auth-provider settings were changed.
- English/Arabic 320×568 and 800×1280 research, at 1.6 text scale, retain reachable
  final rows and all four ordered questions. 402×874 renders cover all current
  redesigned flows; a simulated 300px IME inset retains reachable Auth submit.
  Language switching, empty fields, validation, semantic error relocalization,
  App/Resume independence, draft preservation and navigation guards pass.
- ARM debug APK rebuild succeeds with true dev defines, package
  `com.mhflow.jobix`, version `1.0.0+1`, min SDK 24, target/compile SDK 36.
- APK signature verifies (v2); signing certificate matches the prior review
  APK, so no destructive uninstall is requested.
- APK contains approved unchanged brand masters, real Inter and four Noto Sans
  Arabic weights/glyphs plus OFL license. Android/iOS launcher resources use the
  approved icon, replacing Flutter defaults.
- Packaged Flutter engines are ARMv7/ARM64. Other plugin libraries include
  x86/x86_64, but no Flutter engine for those ABIs is packaged; **emulator/x86
  execution is not claimed**.
- Review ZIP integrity passes and the extracted APK hash equals the output APK:
  `3da0dc7ed03916797f9ba2849c1200dc88a5502628f201261d5a05295e32468b`.
- Output APK: `build/app/outputs/flutter-apk/app-debug.apk`
  (166,593,924 bytes). Compressed unchanged package:
  `build/review/jobix-dev-debug.zip` (below the delivery size limit).
- **31 full-size redesigned-flow widget renders** and labelled contact sheets
  delivered in `build/review/`; actual rendered PNGs were visually inspected.

### Explicitly not passed / release dependencies

`adb devices` has no connected device. The owner supplied Galaxy M31 /
M315F/DSN / Android 12 and older problem captures, but no new physical evidence
for this rebuilt APK. Physical installation, Samsung keyboard/system splash,
touch feel, process-death recovery and Keystore acceptance remain unverified.
No simulated capture or debug build is described as physical-device acceptance.

Real Google browser OAuth, email confirmation/recovery delivery and external
deep-link/device lifecycle are not verified by settings flags or test fakes.
Native iOS/Xcode/Keychain verification is unavailable. No confirmation, guard,
session or RLS bypass was introduced.

Terms/Privacy URLs and operational production policy require approved pre-launch
configuration. These were not implementation blockers for this explicitly
authorized development redesign. No next feature slice was started.

## Physical-device visual review — access check, 2026-10-03

**Subsequent owner evidence:** Ten physical-device screenshots were supplied.
They show native launch/initialization, all three English introductions, English
and Arabic Q1, Auth gateway, a signup error and startup failure. The owner later
identified Galaxy M31 / M315F/DSN / Android 12. Q2–Q4, selected states, keyboard
behavior and Personal Information were not established by those old captures.
The owner changed visual strategy to an original
Flutter design system; see [VISUAL_REDESIGN_AUDIT.md](VISUAL_REDESIGN_AUDIT.md).
At audit time, read-only dev checks confirmed Auth health/settings HTTP 200,
email/Google enabled, email autoconfirm disabled and zero operational `mobile`
policy rows. The later explicit dev-only configuration above resolves that gap.
Missing policy is a confirmed authenticated-startup blocker; without device
logs the precise captured exception is not established. No remote changes,
guard bypass, UI implementation or device rerun occurred during this audit.
Review/redesign remains incomplete pending brand/legal inputs and policy
remediation authorization. The initial access check below predates the captures.

**Owner clarification:** Approved logo/icon masters are now supplied but not
integrated. The review device is Samsung M315F/DSN (Galaxy M31), Android 12.
Terms/Privacy URLs remain a documented pre-launch dependency. The owner requires
stopping at missing policy values, with no database/policy/migration changes.
The absent `mobile` policy lacks required `minimum_supported_version` and
`policy_version`; `recommended_version` is optional. No values were invented,
no guard was bypassed, and no new implementation or device rerun is claimed.

- `adb devices -l` returned an empty device list. No physical Android device
  is accessible from this workspace, and no owner-provided device captures or
  observations have been supplied for this review.
- The existing review ZIP and original APK are present at the paths below.
  No installation, native launch or interactive visual inspection was performed.
- The previously documented absent operational `mobile` policy and unverified
  email/Google provider setup remain review limitations; their live state was
  not rechecked or changed. Startup/authentication guards were not bypassed.
- Review is **blocked, not complete**. Physical-device evidence is needed for
  introduction, Q1–Q4, authentication and reachable Personal Information,
  English/Arabic direction, independent App/Resume Language, initial empty
  fields, touch targets, keyboard, scrolling and navigation. An observed issue
  must precede a minimal authorized UI fix and a device rerun.
- No UI/product, architecture, database, provider/policy, staging or production
  change was made. Build/signature/widget evidence is not device acceptance.

## Physical-Android review APK — 2026-10-03

Development/debug build only, explicitly authorized for visual review.

- Installed Android SDK/build components and accepted their licenses. Flutter
  doctor reports a healthy Android toolchain. No emulator or replacement
  Expo/React Native/Linux application was created.
- Restored ignored dev configuration from existing workspace public settings.
  `dart tool/check_foundation.dart config/dev.local.json` passed. No new
  credentials or staging/production configuration was created.
- The first default debug build requested an unavailable legacy x86 profile
  engine artifact. The successful build explicitly targets physical-device
  ARM CPUs. Pinned Android NDK 27.0.12077973 to satisfy the existing native
  plugins instead of the older wrapped-Flutter default.
- Successful command, from `mobile/jobix`, with the workspace-local Gradle cache:

  ```sh
  GRADLE_USER_HOME="$PWD/../../.local/toolchains/gradle-cache" \
    flutter build apk --debug \
    --target-platform android-arm,android-arm64 \
    --dart-define-from-file=config/dev.local.json
  ```

- APK: `mobile/jobix/build/app/outputs/flutter-apk/app-debug.apk`
- Download archive: `mobile/jobix/build/review/jobix-dev-debug.zip` (73,958,679
  bytes), containing the unchanged `app-debug.apk`. ZIP integrity checked.
  The raw APK exceeds the Library's 100 MiB upload limit.
- Size: 143,700,892 bytes. SHA-256:
  `700ce05a9443b41b10ed6c400d4ee53852ab3fc5c9042a5417d6652ebf967fc7`
- `apksigner verify --verbose`: passed, APK Signature Scheme v2.
- Package `com.mhflow.jobix`, version 1.0.0 (1), debuggable, minimum API 24,
  target/compile API 36. Flutter engines are present for ARMv7 and ARM64;
  other ABI plugin libraries do not imply x86 emulator support.
- No product flow/UI, architecture, schema, migration or remote database changes.
  The standard three-environment build script is unchanged and was not used
  for this specifically authorized development-only review build.

**Not verified:** installation/launch on a physical device, native keyboard,
Keystore/session restore and the full interactive Auth/Profile journey.
The documented operational-policy/provider prerequisites are not bypassed or
changed by producing an APK. No production/staging build or release acceptance
is claimed. Earlier missing-toolchain/build statements below are historical;
remaining native-device acceptance gates still apply.

## HTML/product correction — 2026-10-03

Completed only the requested first-slice revision. No next feature, server
migration, live database write, environment/configuration change or original
HTML edit was made.

- `flutter gen-l10n`, `dart format lib test`, `flutter analyze`: passed;
  analyzer reported **no issues**.
- `dart tool/check_foundation.dart`: public-client secret, directional-layout
  and token checks passed. `git diff --check`: passed.
- Final `flutter test` without `--update-goldens`: **68 tests passed**.
  This includes 20 first-slice contract tests and 15 widget tests, plus the
  existing Foundation tests.
- New regressions cover every incomplete first-time stage and direct Auth,
  Login, confirmation/reset URLs; Skip remains introduction-only.
- Rendered-content assertions cover all three English introduction pages,
  research, empty Personal and mixed-language Personal; they reject fictional
  identities/location/contact claims and the named unsupported ATS/marketing
  claims. The approved ATS-friendly headline remains.
- Empty Personal controllers/server snapshots are asserted for all eight
  fields. Displaying the EG suggestion and saving Resume Language alone sends
  no Country or other personal values. Accepting Egypt explicitly creates only
  a draft until another explicit Save.
- Resume changes preserve content/App Language. App Language changes preserve
  Resume Language, CV labels and user content.
- Disposable local PostgreSQL Foundation/slice RLS/RPC/bootstrap checks passed.
  The empty-bootstrap assertion now covers **all eight** personal fields,
  plus null Profile name and Resume Language. No live checks were repeated.
- Regenerated and visually inspected native-widget goldens: all three
  onboarding pages; all four English research pages; Arabic research;
  empty English Personal (a tall all-section test render); mixed English
  App/Arabic Resume Personal. Existing Auth/Home baselines also still pass.
  A 320px phone/1.6x text check passes. These are test renders, not device captures.

Exact source adaptations and remaining HTML differences are recorded in
[FIRST_SLICE.md](FIRST_SLICE.md#deliberate-differences-from-the-original-html).
The provider configuration, operational policy, native build/device/security
and full location-catalog gates below remain unverified/unchanged.

## First vertical slice — 2026-10-03 (pre-correction evidence)

This is the separately authorized feature slice; it supersedes the historical
Foundation-only scope below, not the remaining native acceptance gates.
See [FIRST_SLICE.md](FIRST_SLICE.md) for source authority, implemented
contracts, minimal Architecture V2 patches and visual handoff limitations.

### Passed in the current checkout

- Flutter localization/Drift generation and dependency resolution.
- `flutter analyze`: **no issues**.
- `flutter test`: **65 tests passed**, including the 19 new contract and
  13 new native-widget journey tests. That run compared goldens normally,
  without `--update-goldens`; no screenshot mismatch or layout error.
- Actual SQLCipher encrypted v1→v2 migration, settings preservation, repeated
  singleton onboarding writes, restart/readback, account-scoped drafts,
  offline retention and offline acknowledged-cache use.
- Atomic research ownership/command writes reject a stale snapshot, a
  switched account or signed-out caller. Context cannot be assigned to a
  different account during a delayed response.
- Three-screen order/Skip, ordered four-question research retention and Q4's
  maximum, confirmation guards, Google/reset boundary calls, returning Home,
  new-registration Personal entry, Save & Continue Later and safe Discard.
- Sign-out explains that local unsaved work is removed but acknowledged
  server data remains; cancelling it preserves the draft.
- Unknown-outcome retries use the same frozen command after further edits;
  version conflicts do not silently overwrite, and non-network failures never
  fall back to an old acknowledged Profile.
- Mixed English App/Arabic Resume labels and direction without content
  translation; optional custom city/history selection; 320px phone and
  1.6× text navigation; native goldens for onboarding, research, auth, Home
  and Personal Information.
- `dart tool/check_foundation.dart`: public-client secret, directional-layout
  and token checks passed. `git diff --check` passed.
- Disposable local PostgreSQL Foundation + slice checks: Auth-trigger
  bootstrap, exactly one empty Profile/slot/personal record per new account,
  no Resume-language default, duplicate prevention, anonymous denial, owner
  isolation, lifecycle exclusion, partial saves, idempotent replay,
  payload-mismatch rejection, version conflicts and first-entry claim isolation.

### Live isolated-development SQL

Applied the two source migrations, in order, using the server-only protected
session-pooler credential, the uploaded public CA and verified TLS:

- `202610030002_first_vertical_slice.sql`
- `202610030003_registration_entry.sql`

The target was checked against the already authorized isolated development
project. Staging/production were not contacted or changed. The existing
Foundation schema was required, not replaced.

The real Supabase PostgreSQL roles and `auth.uid()` passed the slice bootstrap,
RLS and save/retry checks. First-entry routing is server-authoritative:
new identities can claim first entry once; returning identities cannot be
misclassified solely by choosing a Signup or Login button. Anonymous callers,
other owners and inactive accounts cannot claim another user's state.
SQL fixtures were inserted only inside a rollback transaction and removed
by rollback; no new persistent Auth account or profile test data remains.
No operational app-policy version was seeded.

These are **live SQL** results, not real Google/email provider round trips,
native deep-link, Keystore/Keychain or new PostgREST/SDK journey results.
Historical Foundation live HTTP/session evidence below remains separate.

### Still unverified / unavailable

- The previously supplied, ignored public dev client config file is absent
  in this checkout and must be restored from genuine settings.
- Staging/production public settings remain NOT_CONFIGURED. The three-project
  native build gate is preserved; no APK/IPA or release build pass is claimed.
- Supabase Google provider configuration, confirmation enforcement/mail
  delivery, reset emails and native redirect allowlisting/round trips.
  The required redirect is `com.mhflow.jobix://auth/callback`.
- Foundation recorded the operational `mobile` policy as absent; no slice
  migration creates it. Authenticated startup remains fail-closed without
  an administrator-approved policy.
- Physical Android/iOS device storage, process death, backups/device transfer,
  native RTL/locale/deep-link behavior and macOS/Xcode/CocoaPods.
- Full approved location autocomplete catalog; only account history/custom
  input is implemented. No dataset was invented or downloaded.
- Final separate visual frames for confirmation/recovery/conflicts;
  these use minimum structural UI with the accepted shared styling.
  Research HTML frames exist and are used by the correction above.

The source-tested slice is implemented; the unavailable native/provider gates
are not certified. Do not interpret this as production readiness.

## Final disposition — 2026-10-03

The user accepted the successful live Supabase verification and authorized
closing this verification task with the remaining unavailable prerequisites
recorded as **environment blockers**. This closes the authorized work, not the
unverified native acceptance gates. No native build or device pass is claimed.

### Exact environment blockers and unverified checks

| Environment blocker | Checks that remain unverified |
| --- | --- |
| Genuine staging and production public Supabase configuration is unavailable; both remain `NOT_CONFIGURED`. | The existing three-distinct-project build gate stops Android before compilation. No Android APK build is verified. |
| No macOS runner with Xcode and CocoaPods is available. | iOS dependency installation, Xcode validation, compilation and native integration are unverified. |
| No physical Android device is available. | Android Keystore-backed session persistence across process death, immediate sign-out after real cold-start restore, native SQLCipher wrong/missing-key behavior, backup/device-transfer exclusion, locale restoration, RTL and native startup guards are unverified. |
| No physical iOS device is available. | iOS Keychain-backed session persistence across process death, immediate sign-out after real cold-start restore, native SQLCipher wrong/missing-key behavior, backup/device-transfer exclusion, locale restoration, RTL and native startup guards are unverified. |

Do not create or invent staging/production projects or credentials to satisfy
these gates. Staging/production configuration remains unchanged. Do not bypass
the build gate or substitute fake credentials, simulated native verification,
browser results or in-memory SDK results for genuine native evidence.
Further verification requires the actual missing prerequisites and separate
authorization; no feature, UI or architecture work is authorized.

### Persistent migration and data disposition

- The authorized Foundation migration remains applied to isolated **dev**:
  `public.users`, `public.app_policies`, their RLS/grants and
  `public.read_app_policy(text)`. It was not reverted or reapplied.
- SQL test rows were rolled back. Temporary live-verification Foundation user
  and policy rows were removed, and their absence was confirmed during the
  successful run. No operational minimum-version policy remains seeded.
- The user-supplied disposable Auth accounts remain; setup/test sessions were
  revoked. The harness did not create or delete those Auth accounts.
- No staging/production migration or data change occurred.
- `supabase/tests/local_auth_fixture.sql` was never deployed to Supabase.

Finalization changes documentation only. Earlier successful results below are
retained without repeating live writes or claiming unavailable native checks.

### Files changed during this verification work

Source/documentation/configuration inventory, excluding generated Flutter
outputs and installed SDK/cache files:

- `mobile/jobix/README.md`
- `mobile/jobix/VERIFICATION.md`
- `mobile/jobix/tool/live_supabase_test.dart`
- `mobile/jobix/tool/verify_live_supabase.py`
- `mobile/jobix/android/app/build.gradle.kts`
- `mobile/jobix/android/app/src/main/kotlin/com/example/jobix/MainActivity.kt`
  (removed during the approved package relocation)
- `mobile/jobix/android/app/src/main/kotlin/com/mhflow/jobix/MainActivity.kt`
  (approved package relocation)
- `mobile/jobix/ios/Flutter/AppFrameworkInfo.plist`
- `mobile/jobix/ios/Podfile`
- `mobile/jobix/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/jobix/config/dev.local.json` (ignored public dev configuration)
- `.replit` (authorized tooling setup)
- `attached_assets/0_prod-ca-2021_1791007607421.crt` (uploaded public CA)
- `.agents/memory/MEMORY.md`
- `.agents/memory/database-network-access.md`
- `.agents/memory/native-tooling.md`
- `.agents/memory/policy-rpc-compatibility.md`
- `.agents/memory/jobix-authority.md`

This finalization changes only `mobile/jobix/VERIFICATION.md` and
`.agents/memory/jobix-authority.md`. The existing migration source and local
auth fixture are unchanged; staging/production configuration is unchanged.

## Local verification — 2026-10-02

Executed from the Linux workspace:

```sh
JOBIX_SQLCIPHER_LIBRARY=/nix/store/j6vh2fybrzqqac8fkhwdd2dzvk539ql2-sqlcipher-4.6.1/lib/libsqlcipher.so \
  bash mobile/jobix/tool/verify.sh
```

Result: exit status 0.

- Dependency resolution, localization and Drift generation passed.
- Public-client secret, directional-layout and design-token checks passed.
- Flutter analysis reported no issues.
- All 33 Flutter tests passed.
- SQLCipher 4.6.1 exercised encrypted database creation/reopening, wrong-key
  rejection, missing-key rejection and locale persistence on Linux.
- The real Supabase SDK restoration/sign-out test passed with synthetic session
  data, in-memory secure-storage replacement and fixture HTTP transport.
- Disposable local PostgreSQL checks passed for anonymous denial, owner
  isolation, deleted-account exclusion, authenticated policy RPC access,
  direct policy-table denial and client mutation denial.

These results do **not** verify Android Keystore, iOS Keychain, device backups,
device transfer or live Supabase Auth/PostgREST. Expected SQLCipher
wrong-key diagnostic errors were emitted during the passing negative test.

## Saved configuration checks

After the workspace configuration was supplied:

- `dart tool/check_foundation.dart config/dev.local.json` passed. The ignored
  dev file contains only public client configuration.
- Static checks confirmed the Android namespace/activity/application ID,
  compile/minimum/target API levels, all three iOS app and test bundle IDs,
  all project deployment targets, Podfile and Flutter framework minimum OS,
  and package version agree with the approved values.
- `git diff --check` passed.

These checks do not claim native compilation. No staging/production local
configuration was generated from the `NOT_CONFIGURED` markers.

## Remaining acceptance gates

| Requirement | Current evidence / blocker |
| --- | --- |
| Approved application identifiers, OS targets and build version | Supplied through workspace configuration: `com.mhflow.jobix` on both platforms, Android minimum API 24 / target API 36, iOS 13.0, version 1.0.0. Applied to native build settings; native compilation remains unverified. |
| Public dev/staging/prod Supabase configuration | Public dev configuration supplied. Staging and production explicitly marked `NOT_CONFIGURED`. Three distinct project hosts are still required by the build gate. |
| Android SDK and APK build | SDK platform 36, build tools 34/35, NDK 26.3.11579264, CMake 3.22.1 and command-line tools 16.0 installed. Build command stopped at missing staging configuration before compilation. No APK verified. |
| iOS validation/build | User confirms no macOS runner is available. No iOS build verified. |
| Native session persistence and immediate cold-start sign-out | Fixture and live real-session SDK restart/sign-out checks pass with in-memory storage. Native devices are still required to verify Keystore/Keychain and actual process restarts. |
| Native SQLCipher wrong/missing-key behavior | Linux tests pass; native library/storage integration remains unverified. |
| Backup and device-transfer exclusion | Platform configuration exists; actual backup/transfer behavior remains unverified. |
| Native locale restoration, RTL and startup guards | Local tests pass; native device execution remains unverified. |
| Live Supabase migration and isolation/RPC checks | Passed: authorized migration, real-role SQL RLS tests, anonymous HTTP denial and authenticated PostgREST isolation/safe RPC checks with two real Auth accounts. |
| Live minimum-version enforcement and session restoration/sign-out | Passed against live dev Auth/RPC with the Foundation startup guard and in-memory session adapter. Temporary policy removed; native startup/storage remains unverified. |

## Safety boundary

Full Foundation/native verification requires evidence for every remaining gate.
The user-authorized task closure above does not certify those blocked gates.
Do not substitute a browser/desktop result for native verification.
Never deploy `supabase/tests/local_auth_fixture.sql` to Supabase.
Only `supabase/migrations/202610030001_foundation.sql` is the application
migration, and applying it requires explicit authorization for the isolated
development project. Flutter accepts only public publishable/anon client keys;
never put service-role/admin credentials into client configuration.

No later feature slice is authorized by this verification work.

## Authorized setup and live connectivity — 2026-10-03

- User authorized Android SDK license acceptance and installation.
- User confirmed the configured dev project is isolated and authorized the
  existing Foundation migration only.
- User stated that no macOS runner or Android/iOS physical devices are
  currently available. `adb devices` also reported no attached devices.
- Public-key requests to the configured dev project returned:
  - `/auth/v1/health`: HTTP 200.
  - `/rest/v1/users?select=id&limit=1`: HTTP 404, `PGRST205`.
  - `/rest/v1/rpc/read_app_policy`: HTTP 404, `PGRST202`.

The latter responses report missing API resources, not proof of database
schema absence or successful RLS enforcement. Administrative schema inspection
is required before applying the migration. No remote SQL, user creation or
policy writes were performed by these connectivity probes.

## Android setup result — 2026-10-03

The workspace package installer supplied `android-tools` and the standalone
SDK manager after rejecting the nested Nix Android SDK package attribute.
SDK packages were downloaded from Google's repository. The install was moved
to ignored workspace toolchain storage after home-directory quota exhaustion;
the incomplete NDK install was replaced and its package metadata checked.

- Flutter detected platform 36 and build tools 35.0.0.
- SDK manager 16.0 runs successfully.
- Build-tools `aapt2 version` runs successfully.
- NDK package metadata and CMake executable are present.
- Authorized `android-sdk-license` acceptance was recorded for installed
  packages. Six unrelated SDK license agreements remain unaccepted; Flutter
  reports this warning.
- Latest command-line tools 23.0 now use Android CLI in place of SDK manager.
  They were removed from the active SDK so Flutter 3.32.0 uses tools 16.0.
- `bash mobile/jobix/tool/build_android.sh dev` failed at
  `config/staging.local.json` because staging/production are not configured.
  No native compilation occurred. The build gate was intentionally retained.

SDK discovery and executable checks are not an APK build or device test.

## Dev database connection check — 2026-10-03

The server-only database URL was supplied through workspace Secrets. Its
connection target matched the authorized isolated dev project and public dev
configuration. Neither its value nor password was displayed or embedded in
Flutter.

Read-only connection attempts failed before database authentication. Network
diagnostics confirmed the direct endpoint resolves only to IPv6, and TCP
connection failed with `EAFNOSUPPORT` in this workspace. Administrative schema
inspection, migration application and live SQL/RLS verification were therefore
unexecuted at this stage. A session-pooler connection URL on port 5432 was
required. The password had not yet been validated, because no database
connection was established. Subsequent pooler and verified-CA checks below
resolved this blocker.

## Replacement session-pooler check — 2026-10-03

The replacement secret passed the authorized-project and port checks. TCP
reachability and PostgreSQL authentication succeeded using `sslmode=require`.
Read-only schema inspection confirmed:

- Existing Supabase `auth.users`: present.
- Foundation `public.users`: absent.
- Foundation `public.app_policies`: absent.
- Foundation `read_app_policy(text)` RPC: absent.

The backend `pg_stat_ssl` flag was false; through a pooler, this describes the
pooler-to-database connection, not the TLS client-to-pooler connection.
`sslmode=require` does not validate the server certificate or hostname.

A separate certificate-validating client handshake failed with
`CERTIFICATE_VERIFY_FAILED` (self-signed certificate in chain). Administrative
writes were paused before reading/applying migration SQL. The public Supabase
server root/CA certificate from the authorized project's dashboard is required
to verify this connection. No migration, test inserts or policy writes occurred
before the CA was supplied and verification succeeded, as recorded below.

## Authorized migration and live RLS — 2026-10-03

The public CA certificate supplied from the isolated dev project enabled
client-to-pooler certificate and hostname validation with TLS 1.3.
PostgreSQL administrative calls used `sslmode=verify-full` with that CA.

The existing `202610030001_foundation.sql` migration was applied to the
authorized isolated development project after checking that Supabase Auth
exists and that the Foundation objects do not already exist. The migration
transaction included a precondition guard and transaction-level advisory lock
to prevent accidental reapplication or overwriting an existing schema.

`supabase/tests/rls.sql` then passed against the real Supabase roles and
`auth.uid()` function. Only rollback-only test rows were inserted; the local
auth schema/role fixture was never read, applied or deployed to Supabase.

Passing checks:

- Anonymous SQL cannot read users or invoke the policy RPC.
- Authenticated owners see only their own non-deleted user row.
- Deleted accounts are excluded.
- Authenticated policy RPC access succeeds; raw policy access fails.
- Client user/policy mutations are denied.
- Both Foundation tables have RLS enabled.
- The RPC is security-definer with an empty search path and does not project
  private `configuration`.
- Follow-up queries confirmed no Foundation user rows, policy rows or temporary
  auth test rows remained after the test transaction rolled back.
- Anonymous PostgREST user query: HTTP 200, empty result.
- Anonymous direct policy query and RPC: HTTP 401, `42501`.

These are live SQL/RLS and anonymous HTTP checks, not proof of authenticated
HTTP behavior, real Auth session restoration, minimum-version startup guards,
or native secure storage. The live Auth/HTTP gates were subsequently checked
below; native acceptance gates remain open.

## Live Auth, authenticated API and SDK verification — 2026-10-03

Two distinct, disposable, email-confirmed dev Auth accounts were supplied
through workspace Secrets. Both password sign-ins succeeded. The opt-in
`tool/verify_live_supabase.py` harness then created temporary Foundation user
rows and a test-only `mobile` minimum-version policy, refusing to overwrite
existing rows. Administrative calls used the verified dev session pooler;
Flutter received no database/admin credential.

Passing live checks:

- Each real JWT can read exactly its own Foundation user row, and cannot read
  the other account's row through PostgREST.
- Direct policy-table access is denied; client user insert/update/delete and
  policy update requests are denied with PostgreSQL permission errors.
- Authenticated RPC returns exactly the four public policy/version fields,
  never the private test configuration.
- The real Foundation startup orchestration blocks approved build version
  `1.0.0` against temporary live minimum `2.0.0`. A test caller at version
  `2.0.0` is permitted; this does not change the approved package version.
- A missing live policy fails closed. The installed SDK can surface HTTP 406
  for an empty RPC `maybeSingle` result rather than returning null; either
  explicit failure prevents startup.
- A genuine Auth session is persisted through `SecureSessionStorage`, then
  refreshed against live Auth and restored after SDK disposal/reinitialization.
- With implicit recovery deferred, explicitly awaited restoration completes
  before sign-out. Immediate sign-out clears current/persisted session state
  and receives successful live server logout.
- The revoked refresh token is rejected by live Auth; no delayed recovery
  resurrects the session.
- A later SDK restart remains signed out, and the signed-out startup guard
  makes no policy request.
- Temporary Foundation user/policy rows were removed and their absence
  confirmed. Setup/test sessions were revoked; supplied Auth accounts remain.

The harness uses a memory-only `SecretStore` across SDK instances. This is not
process-death persistence or Android/iOS secure-storage proof. Database opening
is a test port here, not native SQLCipher verification. Native cold starts,
backup/transfer exclusion, encrypted storage, locale/RTL and device startup
still require the unavailable native runners/devices. No staging/production
resource, product feature, or operational policy was created.