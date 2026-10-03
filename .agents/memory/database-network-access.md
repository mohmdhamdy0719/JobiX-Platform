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