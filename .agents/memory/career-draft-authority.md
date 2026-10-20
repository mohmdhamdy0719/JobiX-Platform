---
name: Career draft authority
description: Owner's distinction between intentional saved career Drafts and ordinary unsaved editing state.
---

An explicitly saved incomplete career entry is an intentional, server-persisted
Draft. It is not an abandoned editing-session draft. Supabase is authoritative;
do not create a competing local-only persistent store. Ordinary unsaved edits
must still be abandoned on leaving, while Back must not delete a previously
saved career Draft.

**Why:** The owner explicitly requested returning to incomplete entries without
publishing them or restoring edits the user intended to abandon.

**How to apply:** Require authoritative acknowledgement for Save/Complete and
explicit confirmation for Draft deletion. Preserve uncertain-request recovery
separately from saved Draft content. Enforce Draft exclusion in canonical Resume
data, not merely Flutter cards, including Preview, Layout, and PDF output.
Summary examples edit the field only and must never invent background claims.
The shared AI improvement box remains non-functional until separately approved.
