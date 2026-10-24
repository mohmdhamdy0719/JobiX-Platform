---
name: Current JobiX handoff
description: Pointer to the latest consolidated native-app, Development, test, and APK status
---

The detailed current snapshot lives in `docs/JOBIX_AGENT_HANDOFF.md`; this file
is only a durable index. It separates source/test evidence from owner-reported
device/cloud results and marks dated Development facts that require a fresh
read-only check.

**Why:** The repository has multiple long historical handoffs whose snapshots
can conflict with later approved work; future agents need one current entry
point without treating old approvals or cloud observations as current.

**How to apply:** Read the current handoff and the linked feature-specific
contract before work. Recheck the actual source, task board, and worktree; obtain
new explicit approval for remote mutations, Production, or live Credits/exports.
