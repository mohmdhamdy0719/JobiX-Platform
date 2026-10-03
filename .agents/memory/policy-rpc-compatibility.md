---
name: Policy RPC compatibility
description: Live PostgREST empty-policy responses can differ from fixture assumptions
---

For a missing authenticated startup policy, require that startup refuses entry;
do not assume an RPC `maybeSingle` always returns null or produces one specific
SDK exception type.

**Why:** Live Supabase returned a zero-row HTTP 406 whose wording was not
recognized by the installed SDK's older empty-result parser. The guard still
failed closed, but a fixture-based expectation of only a local missing-policy
exception incorrectly rejected the live result.

**How to apply:** On Supabase SDK/server upgrades, exercise absent-policy RPC
responses against the real service. Preserve explicit failure; never catch all
RPC errors and silently allow authenticated startup.