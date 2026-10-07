---
name: GitHub history transfer
description: API authorization and native Git transport are separate; preserve source and destination graphs rather than making a REST snapshot.
---

Verify actual Git transport and remote history before publishing. A working
GitHub API authorization is not evidence that native Git authentication/network
transport is working. Do not substitute a one-commit REST snapshot when the
owner requires preservation of existing source history.

**Why:** GitHub proxy reads succeeded while native Git transport timed out in
this workspace. The owner explicitly required history preservation, so an API
snapshot would not meet the migration requirement.

**How to apply:** Fetch and inspect both graphs using working authenticated Git,
reconcile without force, and transfer/verify Git LFS content separately from
the Git pointer files. Never delete Replit remotes/refs to make migration easier.
