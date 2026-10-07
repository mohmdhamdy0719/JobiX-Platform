# 06 — Current roadmap

Ordered by technical dependencies; no milestone below authorizes changing the
approved product scope.

1. **GitHub migration/reconciliation — BLOCKING.** Current private GitHub
   `master` is an unrelated IDE-only initial commit; local `main` has 41 commits
   and is not configured as a GitHub remote. Use an authenticated Git transport
   that can preserve both histories, reconcile on a branch, test, then publish
   without force. Do not overwrite `master` from REST snapshot APIs.
2. **Native device acceptance.** On authorized Android, test sign-up/confirmation,
   first launch/sign-out/sign-in, all builder steps, drafts, photo picker and
   WebView. iOS has no verified device build in the recorded evidence.
3. **AI operation service and history.** Use approved `gemini-3.5-flash`/global
   server configuration; implement idempotent operation reservation, shared
   allowance, provider calls, failure release, unknown-outcome reconciliation,
   model/prompt/source/version metadata, generation history, proposal review,
   and stale-version acceptance. Do not enable the UI until real provider and
   tests pass.
4. **PDF render and storage.** Invoke the shared canonical renderer from a
   Chromium-compatible server worker; add private generated-PDF lifecycle,
   deterministic metadata, expiry/download behavior and exact success-gated
   two-credit debit. Verify multipage Arabic/English, selectable text and no
   dropped content. No public bucket.
5. **Further approved account/monetization features.** Profile slots, Premium,
   reward, Cover Letter and Professional Email remain separate future milestones
   with explicit provider/backend design and product approval; none belongs in
   this migration.
6. **Production readiness.** Only after owner authorization: deploy policy,
   credentials/IAM, retention/privacy, crash/network/device coverage,
   observability, operations and release signing. Staging/production are not
   configured by copying development configuration.

Completed foundations do not make the dependent services production-ready.
