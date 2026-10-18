# AI feature inventory

## Current source evidence

- `mobile/jobix/lib/features/builder/ai_allowance.dart` reads `ai_allowance` after the authenticated first profile is loaded. The database function (migration 010) returns server-side allocation only; the client does not count, reserve, consume, or fabricate generations.
- Allowance model supports a first-profile bucket of 6 and a daily bucket (default 3, schema permits 10). Transition is latched at the approved first-profile completeness threshold; daily date is calculated in `Africa/Cairo`.
- `generation_enabled` is returned as `false` by the checked-in function. `JobixImprovement` is a presentation component with optional callbacks and explicit “AI improvement is not available yet” UI when no callback is wired.
- Targeted source search found no current Gemini, Vertex, OpenAI, Anthropic or other model request, prompt implementation, provider SDK, or server generation function in the current app/Edge/Backend paths. The existence of allowance accounting is not a working AI feature.
- No Premium entitlement writer exists in migration 010. Do not promise a paid tier or a particular model/provider.

| Feature | Status | Remaining requirements |
|---|---|---|
| Resume assistance/improvement | PARTIAL / generation disabled | Choose provider/model with owner approval; define input minimization, prompt, output schema, validation, consent, reservation/settlement, retries, quota, rate, abuse and cost tests. Keep proposal separate until user accepts. |
| Professional email generation | NOT_IMPLEMENTED in current source search | Product specification, templates/model, privacy, quota/cost and UI required. |
| Cover letter generation | NOT_IMPLEMENTED in current source search | Same approval and safety requirements. |
| Multi-profile AI support | PARTIAL data model only | Profile slots exist; no AI generation path or profile-scoped AI flow. |
| Other AI features | NOT_FOUND in current code search | Do not infer from roadmap/mockups. |

## Security/privacy and cost constraints

No prompts, provider keys, data retention policy for prompts, or generation telemetry were found because generation is not wired. Before implementation: use server-side provider credentials only; minimize personal fields; reject prompt-injection instructions that attempt to override system constraints; validate output and never overwrite profile facts automatically; show user review/acceptance; enforce server-owned limits atomically; measure tokens and charge limits; test provider timeout/ambiguous outcome and no double-consumption. Provider/model choices and costs remain unverified and outside this documentation task.
