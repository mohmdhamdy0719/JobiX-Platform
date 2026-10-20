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

An incomplete edit must not silently turn an existing Complete entry into a
Draft or remove its last confirmed content from the Resume. The owner prefers
separate saved edit copies only if they are compatible without excessive scope.

**Why:** The owner explicitly prioritized preserving the existing Complete
entry during incomplete editing and required discard never to delete it.

**How to apply:** Protect this distinction server-side as well as in the UI.
Do not introduce saved edit copies without defining original-version conflicts,
replacement versus addition, and the existing duplicate-name behavior.
