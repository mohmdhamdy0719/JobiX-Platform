---
name: Cloud cost evidence
description: Regional price verification, PDF-export cost-coverage approval, and Google Cloud budget distinctions.
---

Do not treat a region listed in a fetched pricing page as proof that the displayed price table belongs to that region.

**Why:** Google Cloud's fetched pricing text can flatten the region selector while retaining the default Iowa table. Regional Catalog access can fail even when public pricing pages and operational service reads work.

**How to apply:** Verify region-selected SKUs/calculator output explicitly. Label default-region numerical models as references and mark unavailable regional rates UNKNOWN rather than inventing an uplift.

For Development PDF-export readiness, the owner now approves reasonable, documented conservative non-zero engineering estimates for all five cost inputs, including a justified initial shared reserve. Do not assume zero download, Supabase, or cleanup costs, or present estimates as measured provider costs.

**Why:** The owner superseded the earlier evidence-complete blocking requirement, preferring initial estimates that can be validated and adjusted after real usage over indefinite analysis.

**How to apply:** Development accounting configuration and normal export enablement are authorized once estimates are justified and relevant tests pass. New Cloud Run revisions or infrastructure changes require identifying and reporting the specific necessary blocker first. Preserve production and do not claim a successful real export without evidence.

Distinguish alerts-only budgets from service spend-cap budgets, and recheck current official documentation before claiming that Google budgets cannot enforce limits.

**Why:** Official documentation now describes monthly, single-project/single-eligible-service spend caps, including Cloud Run, based on gross estimated usage. Those caps can pause services used for downloads and recovery as well as new rendering.

**How to apply:** Verify account eligibility and actual configured scope; preserve application admission controls and a recovery runbook. Do not assume provider spend caps enforce only new exports or cover unrelated services/storage.
