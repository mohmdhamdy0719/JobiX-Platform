---
name: Development account provisioning
description: Successful Supabase test authentication is not proof of a provisioned Jobix app account.
---

Check application-account provisioning separately from authentication before
claiming a live core-product verification.

**Why:** A configured development test credential authenticated successfully
but had no Jobix application-account record. Auth users may predate the
account/bootstrap migrations. Native widget and disposable SQL success cannot
establish that a legacy test account is provisioned.

**How to apply:** Check the authenticated actor's app-account lifecycle before
core API tests. Stop and ask for the owner's backfill and signup-credit policy
instead of silently provisioning historical accounts, reviving inactive
accounts, or granting retroactive credits. Report the live-test gate separately
from local verification; do not save account identities or credentials here.

The owner approved provisioning only missing configured development test
accounts with an empty first Profile, free first slot, and zero Credits.
Existing accounts/data must remain unchanged; no retroactive signup grant.

**Why:** The owner selected “Provision with 0 Credits” rather than retroactive
bonuses or leaving those test accounts unprovisioned.

**How to apply:** This is a development-test provisioning policy, not permission
to backfill other users or environments, revive inactive accounts, or remove
ledger records. Preserve the genuine-new-signup +5 behavior.