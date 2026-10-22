---
name: Policy RPC compatibility
description: Supabase RPC response compatibility and request-aware HTTP fixtures
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

HTTP fixtures for Supabase RPCs must attach the originating request to their
responses, not just a valid JSON body and status.

**Why:** The pinned PostgREST parser dereferences response request metadata.
A mock response without it throws a TypeError before application-level parsing,
which can look like a repository or UI loading failure.

**How to apply:** Preserve request metadata in MockClient responses; keep
transport-contract failures distinct from application save/reconciliation errors.