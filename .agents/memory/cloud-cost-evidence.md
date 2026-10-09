---
name: Cloud cost evidence
description: Regional price verification and current Google Cloud budget distinctions for cost assessments.
---

Do not treat a region listed in a fetched pricing page as proof that the displayed price table belongs to that region.

**Why:** Google Cloud's fetched pricing text can flatten the region selector while retaining the default Iowa table. Regional Catalog access can fail even when public pricing pages and operational service reads work.

**How to apply:** Verify region-selected SKUs/calculator output explicitly. Label default-region numerical models as references and mark unavailable regional rates UNKNOWN rather than inventing an uplift.

Distinguish alerts-only budgets from service spend-cap budgets, and recheck current official documentation before claiming that Google budgets cannot enforce limits.

**Why:** Official documentation now describes monthly, single-project/single-eligible-service spend caps, including Cloud Run, based on gross estimated usage. Those caps can pause services used for downloads and recovery as well as new rendering.

**How to apply:** Verify account eligibility and actual configured scope; preserve application admission controls and a recovery runbook. Do not assume provider spend caps enforce only new exports or cover unrelated services/storage.
