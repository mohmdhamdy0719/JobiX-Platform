---
name: PDF runtime verification
description: Working host Chromium is not proof the pinned Playwright runtime can run
---
Keep canonical print verification separate from production-runtime readiness.
Never silently replace the pinned engine with the host's working Chromium.

**Why:** The downloaded pinned Linux headless browser lacks compatible host
libraries here. Reusing Nix Chromium libraries exposed a glibc ABI mismatch;
putting their libc paths in the parent process environment also crashed Node.
The existing host Chromium still renders the same canonical document, but
that is a different runtime verification claim.

**How to apply:** Do not globally mix libc through LD_LIBRARY_PATH or upgrade
system tooling as a workaround. Keep browser-only test environments separate
from Node. Report the blocker and verify the pinned distribution in an approved
compatible runtime; cloud image builds/deployment need separate authorization.
