---
name: Cloud cost evidence
description: Regional price verification, PDF-export cost-coverage approval, and Google Cloud budget distinctions.
---

Do not treat a region listed in a fetched pricing page as proof that the displayed price table belongs to that region.

**Why:** Google Cloud's fetched pricing text can flatten the region selector while retaining the default Iowa table. Regional Catalog access can fail even when public pricing pages and operational service reads work.

**How to apply:** Verify region-selected SKUs/calculator output explicitly. Label default-region numerical models as references and mark unavailable regional rates UNKNOWN rather than inventing an uplift.

For current PDF-export readiness, no cost exclusions are approved. Do not assume zero cost for download egress, Supabase, or shared recovery/cleanup, and do not invent a contingency reserve. Keep the live test blocked until modeled rates and residual-cost bounds are evidence-backed and an appropriate shared reserve is justified.

**Why:** The owner explicitly chose evidence-backed coverage with no exclusions at this stage.

**How to apply:** Keep accounting_ready=false and all export gates disabled. This cost-scope decision does not authorize migration application, deployment, or a live export.

Distinguish alerts-only budgets from service spend-cap budgets, and recheck current official documentation before claiming that Google budgets cannot enforce limits.

**Why:** Official documentation now describes monthly, single-project/single-eligible-service spend caps, including Cloud Run, based on gross estimated usage. Those caps can pause services used for downloads and recovery as well as new rendering.

**How to apply:** Verify account eligibility and actual configured scope; preserve application admission controls and a recovery runbook. Do not assume provider spend caps enforce only new exports or cover unrelated services/storage.
