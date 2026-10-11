---
name: Database network access
description: Distinguish IPv6-only database reachability failures from credential failures
---

Use an IPv4-compatible session-pooler route for Supabase administrative checks
when its direct database endpoint resolves only to IPv6.

**Why:** The workspace could reach the public Supabase HTTPS API, but its socket
environment rejected the direct database endpoint's IPv6 address family.
The PostgreSQL client emitted an uninformative error instead of explaining
the address-family restriction.

**How to apply:** Check DNS address families and TCP reachability before
requesting password changes. A failed network connection does not validate or
invalidate the credential. Request replacement connection URLs only through
workspace Secrets, preserve the authorized project target, and require TLS.

## Development database credential boundary

A read-only Development catalog check on 2026-10-11 found that the Replit
`JOBIX_DEV_DATABASE_URL` connects as `postgres`. It is not marked superuser,
but has `CREATEDB`, `CREATEROLE`, `REPLICATION`, `BYPASSRLS`, broad table
privileges, and admin membership on project roles. The separate
`jobix_export_runtime` login is not elevated, has no direct table privileges,
and inherits only the export gateway/worker function roles.

**Why:** A normal status inspection through the persistent Replit DSN has
database-administrator power, while the deployed export runtime is deliberately
restricted.

**How to apply:** Prefer a dedicated read-only role for routine inspections;
reserve the elevated DSN for separately approved, time-bounded migration work.
Keep the runtime login server-only and preserve its no-direct-table-access
boundary.