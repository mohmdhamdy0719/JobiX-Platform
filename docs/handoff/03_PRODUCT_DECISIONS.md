# 03 — Product decisions

Statuses distinguish owner-approved rules from components that merely exist.

| Decision | Status | Constraint |
|---|---|---|
| Native Flutter; English/Arabic; real RTL Arabic | APPROVED / IMPLEMENTED | Keep the mobile architecture and language/content distinction. |
| First-install onboarding and research, then authentication | APPROVED / PARTIALLY IMPLEMENTED | Install completion is durable; fresh answers attach only to the registration that created them. Existing sign-in must not overwrite account context. |
| Career Profile is the source dataset; Resume is presentation/configuration | APPROVED / PARTIALLY IMPLEMENTED | Template/language change must not create a second profile or translate user content. |
| Three Career Profile slots | APPROVED in V2 | User can have at most three; do not infer that paid creation is enabled by schema alone. |
| New successful resume PDF export costs 2 Credits; valid existing download costs 0; failed export has no permanent debit | APPROVED / FOUNDATION ONLY | Reservation is finalized only after actual server export success. No PDF worker is connected. |
| Signup grant +5 Credits; Profile 2/3 unlock cost 10/20 | APPROVED / PARTIAL | Signup wallet exists; paid slot unlock is not implemented. |
| AI: first Profile gets six shared explicit requests; afterward Free 3/day, Premium 10/day | APPROVED / PARTIAL | Server `ai_allowance` response and gated UI exist; no generation endpoint. Premium entitlement is not wired. |
| AI default `gemini-3.5-flash`, global endpoint, Arabic quality priority | APPROVED, NOT OPERATIONAL | Set server-side only; no silent model fallback or Flutter secret. See README/architecture. |
| AI proposals preserve source/history and require explicit acceptance | APPROVED, NOT IMPLEMENTED | No generation can be claimed complete; do not auto-apply/fabricate claims. |
| Completion: Contact 5%+5%+5%; evidence/section weights and AI transition | APPROVED; current computation is algorithm-versioned | See `jobix-authority.md` only as workspace memory, and validate against V2/product spec before edits. No arbitrary cap that changes the approved 50% transition. |
| Resume language changes labels/direction, not source content | APPROVED / PARTIAL | Two template identifiers, English LTR and Arabic RTL; user-owned text stays untranslated. |
| ATS claims/scores | DEFERRED | No ATS audit engine or score is operational. |
| Cover Letter and Professional Email | DEFERRED | Do not add during handoff migration. |
| Billing/subscriptions, rewards, paid AI add-ons/advanced paid features | DEFERRED | No subscriptions or entitlement writer were introduced. |
| Photo storage | PARTIALLY IMPLEMENTED | Private owner-scoped bounded database attachment; no public URL or GCS reuse. Validate storage/retention implications before changing. |

Where a later architecture document conflicts with one of these summaries, read
the authoritative source and preserve an explicit owner-approved resolution;
mark unprovided behavior UNRESOLVED rather than inventing it.
