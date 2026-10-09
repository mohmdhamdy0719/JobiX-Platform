---
name: Development account provisioning
description: Verify app provisioning and reconcile funded tests through durable job/ledger state.
---

## Funded development tests: authoritative reconciliation before retry

Global development export flags do not enforce a one-intent test budget.
An additional key can reserve Credits after the approved job completes.
Close gates on unexpected additional work and inspect authoritative records
without inventing a refund, changing expiry times or repeating the paid test.
Downloads are currently gated too; reopening for download can also resume
unapproved queued work, so reconcile that work before reopening.

**Why:** A personal-phone window completed its one approved debit, then observed
a distinct queued intent/reservation. The safe stop protected against a second
debit but did not itself release the extra reservation.

**How to apply:** Any bounded real-user test. Distinguish same-key replay from
a new intent and distinguish final balance, reserved balance and available
balance. Use approved native expiry/recovery rules, not manual wallet changes.

An assertion, parsing error or caller timeout does not prove the export failed.
Before funding again, refunding or using a new command key, inspect the durable
job, reservation and ledger. Resume verification against the same original
command/job when it already completed; never refund a consumed reservation.

**Why:** A live test's transport-envelope assertion failed while the native
worker completed the single export and consumed exactly the approved Credits.
A fresh test attempt would have risked another funding/debit.

**How to apply:** Any owner-approved bounded paid fixture test. Preserve
ledger audit rows, close the permitted gates, and compensate unused funding
only after authoritative terminal failure/release and reservation reconciliation.

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