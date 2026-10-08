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

Treat scratch verification artifacts as ephemeral across sessions, even when
earlier evidence named a working temporary executable or checksum baseline.

**Why:** Scratch artifacts disappeared while repository source and installed
tooling remained available, creating a false local runtime failure.

**How to apply:** Confirm current artifact availability before reusing old
evidence. Distinguish a missing scratch resource from a product/runtime defect;
verify the current source and approved runtime rather than upgrading tooling.
