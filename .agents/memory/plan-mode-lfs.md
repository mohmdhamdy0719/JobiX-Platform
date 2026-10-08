---
name: Read-only Git and LFS checks
description: Why an apparently read-only Git status can be blocked during planning
---
In this LFS-enabled workspace, Git status can invoke filtering that attempts
temporary writes under the Git LFS directory. An inspection command is not
necessarily free of filesystem side effects.

**Why:** Plan-mode Git status was blocked on an attempted Git LFS temporary-file
write before subsequent read-only inspection commands could execute.

**How to apply:** When this occurs during planning, use direct file/search
inspection and immutable Git history/object reads instead. Do not repair Git,
change filters or weaken read-only protections just to obtain a status report;
do not claim a clean working tree without a successful appropriate check.
