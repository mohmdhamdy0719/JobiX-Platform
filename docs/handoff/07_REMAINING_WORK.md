# 07 — Remaining work

> **Historical snapshot — superseded.** For current gaps and proposed
> priorities, see [PROJECT_STATUS.md](../../PROJECT_STATUS.md) and
> [docs/NEXT_STEPS.md](../NEXT_STEPS.md). Items below are not current status or
> authorization.

## Blocking

- Reconcile local `main` history with the private GitHub repository without
  force-push or history loss. Workspace has no GitHub remote; the repo's existing
  default `master` is a separate, one-commit IDE starter. A GitHub API OAuth
  connection alone does not provide authenticated `git push`.
- Real-device acceptance for native authentication callbacks, local encryption,
  gallery, date/keyboard and WebView behavior.

## High priority

- Build the actual server-only Vertex generation pipeline and AI operation/
  proposal history. UI generation is intentionally disabled.
- Finish private Chromium PDF export, cache/file lifecycle, idempotency and
  successful-export Credits debit. Current WebView is not a PDF proof.
- Verify migration 008–010 on a fresh isolated development database as well as
  the current dev deployment; migration/test scripts' environment guards are
  mandatory.
- Add remote integration/device tests for new profile extras and Resume RPCs;
  the current handoff's transactional checks are dev-only.
- Confirm registration-context behavior with actual confirmed new registration
  and existing sign-in while preserving email verification.

## Medium priority

- Premium-entitlement writes and daily limits; paid profile-slot unlocking.
- iOS gallery and WebView checks and an iOS release/signing plan.
- Production/staging project isolation and operational hardening.

## Future / deferred

Subscriptions/billing, Cover Letter, Professional Email, Daily Reward,
advanced paid features, and a live ATS scoring engine.

## Unknown / needs owner decision

- The GitHub `master` and local `main` commit graphs are unrelated; select a
  documented merge/reconciliation strategy using real Git transport.
- Confirm long-term private photo retention/deletion policy before production.
- Obtain precise Replit task/checkpoint history from the account UI if exact
  task-by-task archival is required. Repository data alone cannot supply it.
- No provider prompt/version contract or PDF worker runtime is implemented;
  do not infer it from the approved high-level architecture.
