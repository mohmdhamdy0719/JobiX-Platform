# 01 — Current project status

> **Historical snapshot — superseded.** This file predates the completed Phase 3
> personal export and M31 download/open result. Use the root
> [PROJECT_STATUS.md](../../PROJECT_STATUS.md) for current implementation,
> deployment, test, and acceptance status. Historical claims below are retained
> as dated evidence, not current state.

| Area | Code/database | Provider integration | Evidence |
|---|---|---|---|
| Supabase account, startup policy and Profile #1 | Implemented | Development configured | Historical live development checks and owner-confirmed signup; do not treat that as a newly repeated device test. |
| Six-step builder, Review/Edit, Career | Implemented | Supabase RPCs | Host widgets/goldens and historical real-dev flow. |
| Personal, summary, entities, drafts/outbox | Implemented | Owner/version/idempotency contracts | Host persistence and recorded dev RPC checks. |
| Private photo/custom links | Implemented foundation | Isolated-dev RPCs | Draft/repository tests, transactional SQL; physical gallery/sync remains unverified. |
| AI allowance display | Implemented, generation disabled | Server allowance read | Host display tests and transactional dev checks. |
| AI generation/history/apply | Not implemented | No Vertex request pipeline | No real generations claimed. |
| Credits | Wallet/ledger and reservations foundation | No consuming PDF worker | Recorded SQL reservation/replay checks; not export integration. |
| Resume config/HTML preview | Implemented foundation | Owner-scoped config RPCs | Renderer tests; native WebView/device acceptance outstanding. |
| PDF export/download | Not implemented | No worker/storage pipeline | No PDF integration test. |
| Billing/slots/rewards/ATS | Deferred | No enabled production service | No simulated success. |

Main milestone: builder polish and Resume foundation. Preserve the current
working application during this documentation/migration task.

GitHub publication is **not complete**. The remote private default `master` has
an unrelated initial commit; native Git transport timed out in the workspace.
API access works, but no source commit, remote merge, or push has been performed.
Local `main`, all local branch history, original documents, and Replit remotes
remain intact.
