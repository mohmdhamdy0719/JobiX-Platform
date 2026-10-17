---
name: Resume export widget tests
description: Test the post-accept export status journey without depending on history-screen copy or unbounded animation settling.
---

Widget tests for an accepted export must follow the production navigation path into the operation/status screen. A test callback that swallows the accepted operation ID leaves the test on the export panel, where history labels differ from status-screen copy.

**Why:** active export states animate and poll; `pumpAndSettle` is not an appropriate wait condition while work is nonterminal, and history labels do not prove the operation page received its state.

**How to apply:** navigate using the operation ID, advance fake time in bounded increments until the expected status request completes, and assert the status copy mapped by the resume experience layer.

For Android-save failure tests, the failure dialog remains open while the download future is awaiting dismissal, and the underlying download button can keep an indeterminate spinner active. `pumpAndSettle` may therefore wait indefinitely; off-screen actions also need `ensureVisible`.

**Why:** bounded widget-test pumping avoids hanging on intentional modal/busy states and makes the simulated device interaction reliable.

**How to apply:** use fixed-duration pumps to reach the dialog, ensure the intended action is visible before tapping, then use another bounded pump after closing or copying diagnostics.
