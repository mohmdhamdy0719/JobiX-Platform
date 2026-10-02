---
name: Secure auth startup
description: Supabase Flutter background recovery can race with immediate sign-out
---
Do not assume Supabase Flutter initialization means persisted-session recovery
has finished. Treat recovery as a startup barrier before exposing authenticated
routes or sign-out.

**Why:** A real-SDK fixture restored a previously persisted valid session after
sign-out had already emitted its signed-out event. SDK initialization starts an
unawaited background recovery; the race is not limited to expired sessions.

**How to apply:** Preserve explicitly awaited secure-store recovery, with SDK
implicit restoration disabled by the adapter. Recheck this behaviour when
upgrading the SDK. Test immediate logout after cold-start restoration, not only
the final startup state. Keep tokens out of diagnostic output.