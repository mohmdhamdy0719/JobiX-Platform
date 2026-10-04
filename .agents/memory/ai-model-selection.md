---
name: AI model selection
description: Owner's preferred Vertex model, Arabic quality gate and approval boundary for alternatives
---

The owner replaces the previous Gemini 3.8 Flash plan with preferred default
`gemini-3.5-flash-lite` for the Jobix MVP, if suitable. The global inference
endpoint is approved; other product and Architecture V2 decisions must not change.

**Why:** The owner wants reasonable MVP AI costs and potentially high-volume
operations without sacrificing quality for Jobix's actual workloads.

**How to apply:** Evaluate current Google Vertex availability, pricing,
capabilities, lifecycle and processing-location constraints before qualifying
the default. Keep the model ID configurable through the existing server-managed
AI architecture so later routing/upgrades do not require rewriting the AI layer.

Arabic quality is a hard requirement: good generation and understanding,
including Modern Standard Arabic and professional CV-style Arabic. Do not choose
a cheaper model if its Arabic quality is materially worse. Evaluate CV/Summary
rewriting, Work Experience improvement, Projects and other career-content
refinement, Professional Email, Cover Letter, ATS analysis, structured JSON,
English/Arabic and anti-fabrication/factual preservation. This evaluation list
does not independently expand the authorized implementation scope.

**Why:** The owner explicitly requires Arabic quality and factual preservation,
not just low cost or generic multilingual support.

**How to apply:** Treat published capabilities as distinct from demonstrated
Jobix quality. Use synthetic evaluation fixtures rather than private profiles.
Require a currently supported GA/stable model, not deprecated or near retirement,
suitable for production-oriented MVP usage and cost-effective at volume.

If a significant limitation is found, stop rather than silently substituting.
Tell the owner: the problem; the recommended alternative; why it is better for
Jobix; current price difference; regional/data-processing implications; and
whether architecture changes are needed. Only switch after approval.

**Why:** The owner explicitly reserves approval of any alternative model.

**How to apply:** Preserve the preferred model while suitability is unresolved.
Do not silently downgrade, upgrade or enable cross-model fallback.