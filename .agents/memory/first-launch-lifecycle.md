---
name: First-launch lifecycle
description: Installation completion is independent of account-owned answers and final research submission.
---
Keep durable installation completion separate from account-owned research answers.
Completing the final choice is not the same as pressing the final Continue action.
Persist the final completion marker and research snapshot together.

**Why:** Account cleanup must wipe private answers without restarting onboarding,
and changing only the in-memory marker breaks exact-snapshot ownership checks.

**How to apply:** Sign-out should lead to Auth after first-launch completion.
Attach answers only to the registration they were collected for, never merely
because an existing account has no server context.
