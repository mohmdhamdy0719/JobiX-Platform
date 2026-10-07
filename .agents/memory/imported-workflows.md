---
name: Imported workflow readiness
description: Imported artifact services can be registered after the initial environment snapshot
---

Recheck the current managed workflows when diagnosing an imported project's
Run failure; do not assume the initial snapshot's empty workflow list is final.
Native Flutter verification does not establish readiness of supporting artifact
services.

**Why:** During this import, artifact registration added and launched the API
and canvas services after initial inspection. Their Node dependencies had not
been restored by the successful Flutter setup, so both services failed to start.

**How to apply:** Inspect current workflow logs and restore each enabled
service's existing dependencies. Verify supporting services separately and
never describe their health or canvas landing page as a running native Jobix app.
