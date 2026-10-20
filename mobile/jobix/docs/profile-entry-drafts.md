# Career entry drafts and writing guidance

## Required backend prerequisite

`supabase/migrations/202610200024_persisted_profile_entry_drafts.sql`
is a new local migration, **not applied to Development or Production**.
It requires migrations through 023. Review and separately authorize its
Development application before using this client with real saved entries.
No Edge/Gateway/Worker deployment or cost/accounting change is required.
The updated client calls `save_profile_entry`; it must not be released before
that RPC and the eight `is_draft` columns are available.

## Existing flow and extension

Previously, `EntityRepository` saved complete records through `profile_mutate`.
Migration 008 adds structural requirements; migration 011 adds Volunteer.
Ordinary editing-session changes are memory-only. The existing encrypted local
outbox stores only an explicitly submitted, unresolved request.

Drafts extend the same eight owner-scoped tables with `is_draft NOT NULL DEFAULT
false`. Existing records retain their IDs and contents. No existing row is
automatically reclassified. Existing RLS and direct-write restrictions remain.
Nullable Skill/Language and Volunteer fields permit incomplete records; the new
RPC enforces the existing structural requirements for Complete saves.

`save_profile_entry`:

- Checks the active account/profile, locks that profile, and enforces its version.
- Hashes the immutable command including Draft intent and replays its saved
  acknowledgement for the same key. Changed payloads cannot reuse a key.
- For complete records, retains existing typed mutation validation.
- For incomplete drafts, skips only migration 008's structural guard and retains
  the original typed/format/owner/version mutation validation. Volunteer and
  nullable Skill/Language writes use the same atomic version/idempotency model.
- Uses a transaction-local trigger marker so draft status is set before existing
  completeness recomputation and snapshot generation. It restores the marker on
  both success and failure.
- Discards only a row that is still Draft, under the same profile lock/version
  checks. A stale Draft card cannot delete a completed record.
- Returns a canonical snapshot without drafts. The separate owner/RLS-protected
  table read restores saved draft cards and field values.

New outbox commands record their RPC protocol. Pre-existing unresolved commands
still reconcile through `profile_mutate`, with their original key and payload.
Unknown responses remain frozen; retry never invents a replacement mutation.
Back abandons only unsubmitted editing changes, never deletes a server Draft.
Only explicit, confirmed discard removes a saved Draft.

## Minimum Complete-save requirements

These mirror the existing structural rules, not percentage-completeness scoring:

| Entity | Required |
| --- | --- |
| Work Experience | Job title, company, start month; end month unless current |
| Volunteer | Organization, role, start month; end month unless current |
| Education | Degree, institution, field of study, start month; end month unless current |
| Certification | Name, issuer, issue month |
| Achievement | Title, issuer, achieved month |
| Project | Name, role, project month |
| Skill | Name |
| Language | Name and existing proficiency enum |

Descriptions, location, URLs, and other optional fields stay optional. Existing
length, month range, URL, and enum validation still applies to supplied fields,
even for Drafts. A custom Education degree must retain its existing explicit
text. Short optional descriptions affect quality/completeness only.
Volunteer remains non-scoring.

The six multi-field career editors offer Save as draft on missing requirements.
Skill/Language compact add controls retain their existing mandatory-field
validation; saved drafts of these types can be resumed via their section editor.

## Rendering and Layout

The canonical `jobix_profile_text_snapshot` filters every career-entry array
against authoritative table status. `jobix_export_source` uses that snapshot,
so hiding cards in Flutter is not the security boundary. Local Preview's
`CareerProfile.of` and serialization additionally exclude Draft entries.
Drafts do not qualify completeness. Resume Layout order/visibility/configuration
is not changed by entry saves, and visible sections still exclude drafts.
The PDF pipeline, Credits, limits, and accounting are not changed.

## UI/copy

Summary examples are read-only, six-item, bounded navigation. Using an example
only edits the field; existing text requires replacement confirmation. Saving
still requires the screen's explicit Save. The six approved English paragraphs
are in `summary_examples.dart`, with Arabic equivalents.

Career examples are illustrative only; FAQ expansion never fills fields.
The shared Improve with JobiX component retains its disabled/non-functional AI
behavior; only approved copy changes.

Android `RESULT_CANCELED` returns `cancelled`, a normal no-save result.
Only that result with no evidence of a write/exception is silent. Missing picker
results, write/permission failures, and PDF integrity errors remain visible.
No replacement export or Credit mutation is initiated by download/cancellation.

## Local verification and manual acceptance

Focused disposable database command:

```sh
cd mobile/jobix
bash tool/test_rls.sh --profile-entry-drafts-only
```

It uses the existing disposable Unix-socket-only PostgreSQL instance, applies
001–024 in order, runs current Layout regression and draft SQL/RLS assertions,
and removes the fixture. It never accepts a remote URL.
The old `profile_sections.sql` targets pre-008 incomplete-save semantics and is
not suitable after the later Complete-entry structural guard.

After separate Development migration approval/application and a fresh APK:

1. Enter an incomplete Experience. Save → Back keeps text; Save → Save as draft
   confirms only after the server acknowledgement.
2. Reopen/restart; the section's Draft card restores those exact saved fields.
   Edit then Back/discard editing changes; the previously saved Draft remains.
3. Complete required fields and Save. The same record becomes Complete and
   appears in Local Preview. Draft-only entries never appear there.
4. Verify saved Layout order/visibility still applies to complete entries.
5. Keep draft cancels deletion; confirmed Discard removes only that Draft.
6. Offline/unconfirmed saves show no success. Reconnect and reconcile the same
   request. Check a second account cannot read/edit the first account's drafts.
7. Summary examples navigate all six; Close/declined replacement do not edit.
   Use copies to the field, but reopening after discarding does not retain it.
8. Download an already completed PDF: Back/cancel the Android picker is silent.
   Save still works; genuine write failure still shows the localized error.

No physical-device behavior or live backend persistence is established by the
local fixtures. No APK or live PDF export is produced for this increment.

## Approved English copy

- Summary: **Write your summary**; **Tips to help you write a professional summary**;
  **Write about your professional background, strengths, and experience…**
- Samples: **Explore summary examples**; **Professional Summary Examples**;
  **Use this summary**; **Close**; bounded **Previous example** / **Next example**.
  All six paragraphs are preserved verbatim from the owner's brief.
- Shared improvement copy: **Write naturally and share as much relevant detail
  as you can. JobiX can help turn your information into professional,
  ATS-friendly wording.** The unavailable-AI notice is no longer rendered.
- Example card: **Example on a Resume**. FAQ headings:
  **Tips to help you write a professional work experience**;
  **Tips to help you describe your volunteer experience**;
  **Tips to help you present your education**;
  **Tips to help you describe your projects**;
  **Tips to help you present your certifications**;
  **Tips to help you describe your achievements**.
- **Save as draft?** — **This entry is missing some essential information. You
  can save it as a draft and complete it later. Drafts do not appear in your
  Resume.** Actions: **Save as draft** / **Back**.
- **Discard draft?** — **This draft will be permanently removed. This action
  cannot be undone.** Actions: **Discard draft** / **Keep draft**.
- Record labels: **Draft** / **Complete**. **Draft saved.** appears only after
  acknowledgement. Existing unconfirmed-save/error messaging remains.

## Executed checks

All commands ran locally in `mobile/jobix`, with synthetic test data only.

1. `bash tool/test_rls.sh --profile-entry-drafts-only`: final exit **0**.
   Verified disposable Unix socket/TCP disabled, migrations 001–024, saved Layout
   regression, eight entity minimum rules, canonical filtering, actual
   `jobix_export_source` filtering, promotion, replay, discard status guard,
   cross-account RLS, no export jobs/debits, and fixture cleanup.
2. Flutter regression command:

   ```sh
   JOBIX_SQLCIPHER_LIBRARY=/nix/store/qfpyahp6qvv4lqbmvrpmdnh4f4hqfa6j-sqlcipher-4.6.1/lib/libsqlcipher.so \
   flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true --reporter expanded \
     test/entity_repository_test.dart test/resume_data_ux_test.dart \
     test/profile_sections_test.dart test/resume_layout_test.dart \
     test/resume_preview_snapshot_test.dart test/resume_preview_session_test.dart \
     test/resume_preview_layout_test.dart test/resume_export_test.dart
   ```

   Initial result: **112 passed, 2 failed** (new test code incorrectly treated a
   Tooltip finder as an IconButton). Those two finders were corrected, and the
   complete `resume_data_ux_test.dart` rerun passed **5/5**. The other 112 included
   export recovery, Credits/idempotency mocks, successful downloads, cancellation,
   genuine write failures, Layout/canonicalizer, and Preview tests.
3. `flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true --reporter expanded
   test/first_slice_widget_test.dart --name 'persisted entry Draft|summary example remains unsaved'`:
   **3 passed, 1 failed** initially (ambiguous Back label). The explicitly keyed
   confirmation was rerun with `--name 'persisted entry Draft confirmation'`:
   **1/1 passed**. All four selected integration cases passed after correction.
4. After the final month parser/RTL/hint changes:
   `flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true --reporter expanded
   test/profile_sections_test.dart test/resume_data_ux_test.dart`: **18/18 passed**.
5. Existing editable Education autocomplete regression:
   `flutter test --no-pub --dart-define=JOBIX_ENABLE_PDF_EXPORT=true --reporter expanded
   test/first_slice_widget_test.dart --plain-name
   'education suggestions remain editable and do not save before explicit Save'`:
   **1/1 passed**.
6. Final `flutter analyze --no-pub`: **exit 0, no issues**.
   `dart format` on changed Dart files, `bash -n tool/test_rls.sh`, and
   `git diff --check`: **exit 0**.

During development, focused SQL checks caught an ambiguous parameter reference
and a fixture comparing absent (`NULL`) layout configuration; both were fixed.
The final fixture saves a real ordered/hidden layout first, then asserts it is
unchanged. No assertions were weakened or skipped. The historical pre-008 suite
noted above remains unchanged.

Not run: full app/golden suite, Android Kotlin compilation/APK build, device
validation, remote migration, live persistence, live export/download, or AI.
