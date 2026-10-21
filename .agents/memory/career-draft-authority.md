---
name: Career draft authority
description: Device-only explicit Drafts, abandoned editing state, and genuinely uncertain server saves.
---

Incomplete or offline-only edits must remain device-only Drafts, not
server-side Profile Entry Drafts. Explicitly saved local Drafts are different
from abandoned editing-session changes. Supabase remains authoritative for
confirmed saved data. Reconnection alone must never upload a local Draft.
Local Drafts do not affect completeness or appear in Resume/PDF output.

**Why:** The owner replaced the earlier server-persisted Draft proposal with a
simpler, explicitly approved local-only/offline workflow.

**How to apply:** Reuse account/profile-scoped encrypted local persistence,
explain device-only/uninstall limitations, and require explicit online Save
and authoritative acknowledgement before promoting a Draft. Preserve the
existing sign-out loss warning/confirmation. Ordinary unsaved edits must not
produce the uncertain-save warning; an actually submitted, unresolved request
must retain its original key and payload until reconciled, even after Back.
Enforce Draft exclusion from canonical Resume data, not merely Flutter cards.
Summary examples edit the field only and must never invent background claims.
The shared AI improvement box remains non-functional until separately approved.

An incomplete edit must not silently turn an existing Complete entry into a
Draft or remove its last confirmed content from the Resume. The owner prefers
separate saved edit copies only if they are compatible without excessive scope.

**Why:** The owner explicitly prioritized preserving the existing Complete
entry during incomplete editing and required discard never to delete it.

**How to apply:** Retain Complete-edit validation and server version/authorization
protections. Do not reclassify authoritative Complete data as a Draft. Local
pending copies must not silently replace fresher confirmed server data.
