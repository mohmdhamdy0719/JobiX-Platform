# PDF export and Android download incident

## Current status

**BROKEN as reported on the physical device; exact failing stage unknown.** The owner reported that completed exports that had downloaded earlier, and other History entries, now all fail to download. The latest generic message was: “PDF download failed. Android could not confirm a complete PDF save. Check device storage and retry. Your existing export and Credits are unchanged.” The owner has not supplied the copyable `JOBIX_PDF_DOWNLOAD` JSON from the latest diagnostic build. Do not call the incident fixed.

## Expected flow and code path

1. `ResumePage.showPreview` calls `_loadLocalSnapshot` and `ResumePreviewSnapshotLoader.load` (`mobile/jobix/lib/features/resume/resume_page.dart`, `resume_preview_snapshot.dart`). It reads a fresh profile, profile extras/custom links, saved presentation configuration and local draft fingerprints twice; requires a stable snapshot and explicit saved-version confirmation if drafts/ambiguous saves exist. It builds HTML locally with `ResumeDocument.prepare`/`ResumeRender.html`. Opening this Preview does not call the Edge `document` action and does not create an export job, reserve/debit Credits, or store an export PDF.
2. From the reviewed Preview, `ResumeExportPanelState.createPdf` (`resume_export_panel.dart`) fetches the authoritative server `document`, checks renderer-layout compatibility and compares reviewed versus authoritative fields. A difference refreshes Preview and requires review. It checks balance, asks explicit confirmation, freezes request/idempotency keys locally, then sends `create` through `ResumeExportService.call`. The server compares saved versions, hash and renderer metadata; the Worker renders/validates and uploads.
3. Worker lifecycle: claim/lease/fencing, render, private upload with generation preconditions, verify PDF/object evidence, finalize job and consume one 2-Credit reservation once. Ambiguous outcomes retain reservations/flight evidence until reconciled; known failure releases reservation. Local disposable tests cover retries, timeouts, fencing, duplicate callback and cleanup.
4. Existing-file download is separate: `ResumeOperationPage.download` or History `_download` calls `ResumeExportService.download(export_id)`. It calls only the existing `download` action; it cannot create an export or debit Credits. It validates HTTPS/approved Storage host, disables redirects, checks HTTP 200, declared/expected length, `%PDF-` header and session identity, then calls Android channel `jobix/pdf_save` with bytes/name. A successful existing download is free.
5. `mobile/jobix/android/app/src/main/kotlin/com/mhflow/jobix/MainActivity.kt` opens Android `ACTION_CREATE_DOCUMENT`, writes to the user-selected URI, closes stream, checks final size when the provider supplies it, returns safe stage/byte metadata, and zeros the byte buffer. It does not read PDF content back or verify that an external PDF viewer opens it.

## Confirmed observations versus hypotheses

**Observed / owner supplied**

- Two Development export rows from 17 October were provided with `state=COMPLETED`, `object_size=154591`, and `error_code=null`. This proves the job records completed, not that a client GET or local save succeeded.
- User-facing History showed the affected exports at 09:39 and 16:57 Cairo local time; corresponding UTC DB timestamps were 06:39 and 13:57.
- The owner reported that supplied Gateway/Worker request logs appeared successful. The attempted Storage GET query returned no data. No correlation evidence currently proves whether the signed URL was requested, fetched, expired, or blocked.
- An earlier, separate owner report confirmed one PDF was downloaded and opened on a Samsung M31. Later reports contradict treating that as current reliability proof.
- A diagnostic APK initially still showed the generic Android save failure. A later Development debug build added a “Copy diagnostics” action. The owner has not yet returned that payload; whether the newest build is installed is unverified.
- Current local artifact: `mobile/jobix/build/app/outputs/flutter-apk/app-arm64-v8a-development-debug.apk`, 121,599,553 bytes, timestamp 2026-10-17 17:25:41 UTC, SHA-256 `983cf1be7ffc9595ca1c6a5e2586a0af1e9672061059cc588472f8cd93f3b88f`. Prior build report identifies ARM64 `developmentDebug`, app ID `com.mhflow.jobix`, Development Supabase reference `lmouxhbjhtqdtiqijcee`, and PDF client define enabled. Exact commit provenance is not embedded; file mtime precedes recorded latest commit `406323c` timestamp, so do not claim a source-commit attestation.

**Not established**

- No safe stage JSON for picker start/cancel, URI, output stream, write, close, size check, or activity lifecycle.
- No Storage GET result correlated to the affected export IDs/times. No full `resume-export` -> Gateway -> Worker -> Storage chain for a failed client download.
- No proof of downloaded byte equality or that a locally saved PDF opens on the current app/device.
- No evidence that the object expired, was missing, or that the export job/Credit state is wrong. Do not infer any of these from `SERVICE_UNAVAILABLE`.

## Safe next diagnostic

Use the latest Development debug APK already installed if it contains the copy action; otherwise install the exact verified Development diagnostic APK alongside only if Android signing/package compatibility is acceptable. Select one **already completed** History entry and tap Download once. Do not tap Create/Export Again. If the failure dialog offers “Copy diagnostics”, copy and share only the `JOBIX_PDF_DOWNLOAD` payload. It is designed to contain stage/outcome, HTTP status, expected/received byte counts, Android save booleans, and sanitized exception type; it must not include URL, query, token, credentials, personal profile data or PDF bytes. If the action is absent, report app version/build variant rather than attempting another export.

Then correlate the same export and timestamp in this order: (1) Edge invocation/log result; (2) Gateway/Worker request and safe status fields; (3) Cloud Storage Data Access GET logs if available; (4) operation/job and Credit reservation/transaction read-only state. Request only the missing approved read permissions. Do not broaden IAM or enable new logging without approval.

## Diagnostic/privacy implementation

- Dart: `mobile/jobix/lib/features/resume/resume_export_service.dart` uses debug-only `JOBIX_PDF_DOWNLOAD` structured diagnostics. Sanitized diagnostics intentionally avoid URL/path/query, access tokens, PDF contents and profile fields. `resume_operation_page.dart` offers copy in the download failure dialog.
- Android: `MainActivity.kt` reports picker/write stages, booleans and sizes, plus exception class only; the byte buffer is zeroed in `completeSave`.
- Regression tests: `mobile/jobix/test/resume_export_test.dart` covers download action/status/length/PDF checks and save-result error mapping with mocked HTTP/native channel. These tests do not prove Android Storage Access Framework behavior on a physical phone.
- Keep release logging disabled; do not add signed URL logging. Existing logs supplied by the owner should be shared only after redacting object paths, IDs, URLs and user fields.

## Prior verification limits

`mobile/jobix/backend/pdf/PHASE3_ACCEPTANCE.md` records historical disposable coverage: adapter 11/11; guarded acceptance 8/8; backend regression 101/101; fixture-based Flutter UI paths. It also records one earlier owner-confirmed M31 download/open. Those results do not establish the current Android save or the current failed-download cause. No tests or exports were run for this handover.

Required regression tests before any fix: HTTP non-200, connect/read timeout, body interruption, redirect refusal, truncated/mismatched length, invalid PDF header, session change, picker cancel, no URI, output stream unavailable, write exception, close/size mismatch, activity destruction, repeated download, and confirmation that downloads never call `create` or alter Credit reservations/transactions.
