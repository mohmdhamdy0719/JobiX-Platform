---
name: AI model selection
description: Owner-approved Vertex default, Arabic quality requirements and model-switch boundaries
---

The owner intentionally selects `gemini-3.5-flash` as the default Jobix AI
generation model, replacing the previous Flash-Lite preference. The global
inference endpoint remains approved; other product and Architecture V2 decisions
must not change.

**Why:** Flash showed better Arabic quality in the matched evaluation, while
Flash-Lite produced unsuitable Arabic phrasing in a user-facing case. The owner
explicitly accepts the higher model cost in exchange for better quality.

**How to apply:** Use the approved default through one configurable server-side
model selection layer; do not scatter hardcoded model IDs across the application.
Preserve factual-grounding/structured JSON validation, the AI state machine,
allowances/quotas, idempotency, retries and UNKNOWN reconciliation. Do not change
generation limits, product behavior, IAM, region, infrastructure, schema or
architecture unless strictly required for the switch. No additional model
comparisons unless a technical issue blocks the switch.

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

**How to apply:** Preserve the owner-selected default; do not silently downgrade,
upgrade or enable cross-model fallback. If fallback is technically necessary,
stop and report it before implementing it.

## Qualification evidence

Provider-declared structured output and model-supplied fact-reference lists do
not prove complete JSON or faithful career text. Inspect the actual generated
text, including unsupported soft claims, and the provider's termination reason.
Preservation of dates and numbers is insufficient: preserve the meaning of the
action as well, such as handling tickets versus successfully resolving them.

**Why:** A live Arabic evaluation produced repeated escaped characters until
the token limit, leaving incomplete JSON. Other parseable outputs referenced
valid source facts while adding unprovided professional qualities or purposes.
The higher-cost full Flash candidate also produced valid JSON while upgrading
ticket handling into ticket resolution. Higher model capability or price is not
evidence that Jobix's factual-preservation requirement is satisfied.

**How to apply:** Include Arabic degeneration/truncation and factual embellishment
in qualification checks. Reject invalid output through the existing Architecture
V2 failure path; do not equate HTTP 200 with a successful Jobix operation or
self-reported references with factual verification. A small evaluation cannot
establish a population failure rate or prove an untested alternative's Arabic quality.
Check test fixtures for ambiguity before attributing an interpretation error to
the model, and distinguish results for a specific prompt/configuration from
claims about the model's general suitability.

Arabic fluency is a separate qualification gate from JSON validity and factual
grounding. Closed-world instructions should explicitly prohibit upgrading action
strength, inventing purposes and adding unprovided frequency or performance claims.

**Why:** Clearer facts and stricter instructions improved grounding, but a grounded,
parseable Arabic response still contained malformed professional wording. A full
Flash response retained the facts while adding an unprovided usage frequency.

**How to apply:** Review professional Modern Standard Arabic wording independently;
do not mark a model qualified merely because its output parses and preserves
source references. Apply the same grounding criteria to cheaper and higher-cost
models, and do not automatically substitute models to work around one failure.