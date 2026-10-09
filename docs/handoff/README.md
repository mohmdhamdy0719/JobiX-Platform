# Jobix handoff index

Read [the root README](../../README.md), [current project status](../../PROJECT_STATUS.md),
[AI handoff instructions](../AI_HANDOFF.md), and [proposed next steps](../NEXT_STEPS.md)
before continuing from a different account. Those documents are the current
2026-10-09 handoff set. `PROJECT_HANDOFF.md` and the numbered status/roadmap
files below are preserved historical snapshots; follow their product/architecture
references, but not superseded feature-status, test-total, setup, or remote-state
claims.

1. [Project overview](00_PROJECT_OVERVIEW.md)
2. [Architecture sources and boundary](02_ARCHITECTURE.md)
3. [Approved and unresolved product decisions](03_PRODUCT_DECISIONS.md)
4. [Implementation timeline](04_IMPLEMENTATION_HISTORY.md)
5. [Recoverable task/plan history](05_TASK_HISTORY.md)
6. [Roadmap](06_CURRENT_ROADMAP.md)
7. [Remaining work](07_REMAINING_WORK.md)
8. [Verification evidence](08_TESTING_STATUS.md)
9. [Development setup](09_ENVIRONMENT_AND_SETUP.md)
10. [Move to another Replit account](10_MIGRATION_GUIDE.md)
11. [Known issues](11_KNOWN_ISSUES.md)
12. [Non-negotiable decisions](12_DO_NOT_CHANGE.md)
13. [Repository/file map](13_FILE_MAP.md)

Supporting evidence: [security/publication audit](SECURITY_AUDIT.md),
[accessible Git log](history/GIT_HISTORY.md), and
[preserved HTML inventory](history/HTML_INVENTORY.md). Historical full task
plans are preserved under `history/`; their acceptance criteria are not
implementation evidence.

The root contains a Replit pnpm template as well as the Jobix Flutter app. The
root workflows for `artifacts/api-server` and `artifacts/mockup-sandbox` are not
the Jobix application. Do not mistake an API health response or component mockup
for the mobile product.

An earlier GitHub check and the migration guide are historical evidence only.
This checkout currently has a GitHub-hosted `origin` and local tracking refs,
but the destination branch/history and remote LFS payload transfer were not
re-fetched or written during the 2026-10-09 documentation handoff. The current
source baseline had 65 reachable commits and seven LFS-managed APK/archive
deliverables; `git lfs fsck --objects` passed locally. No push, force push,
rebase, or history rewrite was performed in this handoff. Verify both Git and
LFS access and compare commit graphs before publishing.

Current native setup commands and environment limits are in the root README.
The Node PDF package is not part of the root pnpm workspace and has its own
tracked frozen lock; do not assume the root workspace install restores it.

Replit internal task, plan and checkpoint records are not guaranteed to be
available after cloning. Preserved task text in `.local/tasks/` is workspace
state and ignored by Git; the recoverable parts have been summarized in the
tracked task history. Do not treat the summary as a complete export of Replit
conversation history.
