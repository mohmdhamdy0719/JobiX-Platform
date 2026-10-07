# Jobix handoff index

Read this folder before continuing development from a different account.
**Current source of truth:** `PROJECT_HANDOFF.md` at the repository root. All
dates/status claims below are limited to tracked history, persisted task plans,
project documentation and this workspace's verified results.

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

The root contains a Replit pnpm template as well as the Jobix Flutter app. The
root workflows for `artifacts/api-server` and `artifacts/mockup-sandbox` are not
the Jobix application. Do not mistake an API health response or component mockup
for the mobile product.

The private GitHub repository named in the handoff brief was checked through the
workspace's authorized GitHub connection: its default `master` branch had one
IDE-only initial commit and no application source; local `main` has its own
41-commit history. There is no GitHub Git remote in this workspace. No push,
force push, rebase, or history rewrite was performed. See the migration guide
before attempting publication.

Replit internal task, plan and checkpoint records are not guaranteed to be
available after cloning. Preserved task text in `.local/tasks/` is workspace
state and ignored by Git; the recoverable parts have been summarized in the
tracked task history. Do not treat the summary as a complete export of Replit
conversation history.
