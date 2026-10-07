# 10 — Migration to another Replit account

## Current publication gate

The provided private repository is
`https://github.com/mohmdhamdy0719/jobix`. Its default branch was `master` with
one IDE-only initial commit when inspected. Local `main` contains the complete
app and a separate 41-commit graph. There is no configured GitHub Git remote.
Read-only native GitHub transport timed out and no credential helper is
configured. Authenticated GitHub API access is available, but it must not be
used to squash the local project history into a snapshot commit.

Before claiming GitHub readiness, establish an authenticated Git transport,
fetch the remote, review both histories, and reconcile on a temporary branch.
Preserve the original `master`, local `main`, all useful refs and five Git LFS
deliverable objects. Use a genuine merge strategy if the histories are
unrelated; do not rebase/squash/force-push away either source history. Resolve
any path collisions explicitly. Inspect the final tree and publish only to the
owner's existing repository.

## After successful publication

1. Ensure the destination account has access to the private GitHub repository.
2. Clone/import the actual published branch and fetch Git LFS objects. Verify
   history and asset checksums rather than assuming a ZIP or LFS pointer is data.
3. Read root `PROJECT_HANDOFF.md`, this folder, and the authoritative attachments.
4. Verify `mobile/jobix/`, root artifacts, SQL migrations, tests, fonts,
   screenshots/prototypes, and `docs/handoff/history/` are present.
5. Install the pinned toolchain and restore dependencies. Do not copy caches,
   build directories, developer databases or local config into source control.
6. Configure required secret names securely. Local credentials and account
   permissions are not supplied by this repository.
7. Reuse existing Supabase development resources and approved Cloud resources.
   Check IAM, callbacks, startup policy and applied schema; do not create a
   replacement database or disable confirmation/RLS.
8. Inspect ordered migrations and current schema. Do not rerun applied
   migrations or execute production/staging changes from development scripts.
9. Run analysis and host tests, then separately authorized live-dev checks with
   fixture restoration. Review `VERIFICATION.md` for environment constraints.
10. Build/run on authorized Android; verify actual signup/inbox/callback,
    Profile #1, builder, Review/Edit, sign-out lifecycle, photos and Resume.
11. Continue from the roadmap—not from the oldest plan or a prototype.

## Not part of Git transfer

Git preserves source history. Replit task dashboards, checkpoints, conversation
history, account authorizations, secret values, native installed tools and remote
databases are separate. Recoverable task/plan text has been preserved/summarized;
inaccessible account-internal records are explicitly not claimed.
