# 08 — Testing and verification status

Last recorded verification is from the current Replit workspace. Rerun relevant
checks after migration/setup; a passing host test is not native-device evidence.

| Area | Status | Evidence / limits |
|---|---|---|
| `flutter analyze` | PASS | Final polish check reported no issues. |
| Flutter host tests | PASS | Full suite: 177 passed, then 33 final focused database/lifecycle/renderer checks. This is not the same run; not to be added into one count. |
| Widget/golden, EN/AR | PARTIAL | English/Arabic golden suite/captures were run and inspected; real screen/navigation coverage is host-based. No host golden is physical device acceptance. |
| Supabase Auth/Profile | PASS, development | `VERIFICATION.md`: actual dev Supabase auth, profile-section, owner-isolation and version-conflict UI checks. New confirmation-email delivery/callback on a physical phone remains outstanding. |
| Recent SQL foundation | PASS, isolated dev | Migrations 008–010 were applied to the authorized isolated development project. Transactional fixture/rollback checks exercised profile extras, structural requirements, stale versions, Resume config, allowance read, Credits reserve/release/consume and replay. Not a production check or a worker integration. |
| RLS/security | PARTIAL | Historical migration/RLS tests and protected dev script checks; no independent external security audit claimed. |
| AI/model/provider | NOT TESTED / NOT IMPLEMENTED | No Vertex invocation, AI history, proposal acceptance, reconciliation or provider smoke test. |
| Resume rendering | PARTIAL | Host renderer tests verify source preservation, escaping, template marker, A4 CSS and directions. No exact PDF/Chromium pagination/export exists. |
| Android | PARTIAL | Signed debug ARM64 APK built; APK signature/archive verified. No connected device/emulator launch test. |
| iOS | NOT TESTED | Native project files exist; no iOS device/runtime acceptance in current evidence. |
| GitHub migration | BLOCKED | API-read checked a private `master` with one IDE-only initial commit. No source push/remote history reconciliation. |

`mobile/jobix/VERIFICATION.md` is longer historical evidence and can include
earlier milestones. Use its dated sections accurately; do not upgrade a previous
145-test run to the later 177-test count without naming the run.
