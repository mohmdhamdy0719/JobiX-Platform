---
name: Native tooling constraints
description: Package availability and SDK-root behavior differ across workspace tooling
---

Do not assume a package that evaluates in Nixpkgs is available through the
workspace system-package installer, or that an SDK manager honors its
command-line SDK-root option.

**Why:** The workspace package index rejected the nested Android SDK attribute
even though Nixpkgs knew it. The separately packaged SDK manager accepted the
SDK-root argument but ignored it during installation, falling back to a
read-only system directory. Its help also advertises an unimplemented uninstall
command; use the installed Google command-line tools for that operation.

**How to apply:** Check installer results and actual installation destinations.
Use explicit writable SDK-root environment configuration and verify native
tool discovery before claiming a toolchain is supplied. Do not treat device
tools alone as an Android build SDK.

Bundled Flutter fonts do not configure fonts for system image tools.

**Why:** Native Flutter captures rendered correctly while external image
composition failed because its default font was unavailable.

**How to apply:** Supply a bundled approved font explicitly when an image tool
renders captions. For combining existing raster captures, avoid unnecessary
text rendering or dependency installation.

Library delivery has a 100 MiB per-file limit; use ABI-specific development APKs.

**Why:** The combined native debug APK exceeded the asset-registration limit,
while separate ARM64 and ARMv7 builds fit it.

**How to apply:** Keep a clearly labeled ARM64 development build for the
Galaxy M31 device class and avoid promising a downloadable combined binary
without checking its size. This is asset delivery, not production publishing.

Keep large native SDK/NDK downloads and extraction inside ignored workspace
storage rather than the home filesystem.

**Why:** Home-directory quota exhaustion killed an NDK install even though
filesystem free-space output suggested enough space. Workspace storage is a
separate mount with a different capacity.

**How to apply:** Check both storage location and quotas when installing native
toolchains, including temporary extraction directories and download caches.

Pin command-line tools compatible with the existing Flutter version rather
than assuming Google's latest CLI retains the SDK manager interface.

**Why:** Recent command-line tools replace SDK manager with Android CLI;
Flutter 3.32.0 cannot recognize its license-status output.

**How to apply:** Verify Flutter/tool compatibility before upgrading native
tooling. An unknown license status can be a CLI compatibility problem rather
than missing license acceptance.

Use explicit physical-device ARM targets for debug review builds with this
Flutter distribution. Match the NDK to the highest requirement of the locked
native plugins, not blindly to the wrapped Flutter SDK's default.

**Why:** The default debug build requested an unavailable legacy x86 profile
engine artifact. The wrapped SDK's default NDK was also older than the existing
plugins required. Explicit ARM targets and the plugins' required NDK produced
a signed debug APK without changing product behavior.

**How to apply:** For physical Android review use
`--target-platform android-arm,android-arm64` with the genuine dev define file.
Do not fabricate engine artifacts or replace Flutter. Plugin libraries may
still include other ABIs; inspect the packaged Flutter engine before claiming
an emulator architecture is supported.

Large debug APKs can exceed the Library's 100 MiB per-file upload limit.
Package the unchanged APK in a compressed ZIP when that makes delivery fit.

**Why:** Direct APK registration was rejected by the upload limit, while the
compressed archive could be delivered without rebuilding or altering the app.

**How to apply:** Preserve the original APK/output path, check archive integrity
and tell the user to extract the APK before installation.

Flutter's localization generation can run before its package-restore command
has repaired missing cached dependencies.

**Why:** After a workspace merge, package metadata referenced an absent home
cache. Flutter package restore failed during localization formatting before
it could restore the missing lints package.

**How to apply:** Restore locked packages against the actual installed Flutter
SDK and a writable workspace cache before retrying Flutter commands. Do not
remove analyzer rules or change dependency versions to bypass a missing cache.

When a resumed workspace has Dart package metadata but no matching home pub
cache, Flutter's localization formatter can fail before dependency resolution.
Bootstrap Dart dependencies with the installed Flutter SDK's Dart executable
and explicit FLUTTER_ROOT, then use normal Flutter commands.

**Why:** The localization generator tried to resolve lint includes from an
absent cache before flutter pub get could repair it; standalone Dart did not
recognize the Flutter SDK without its root.

**How to apply:** Check the package metadata's actual SDK path and cache
availability first. Do not disable linting, change pinned dependencies or
rewrite localization just to bypass this startup ordering problem.

Verify Python package/interpreter minor versions before using native image
tools; the package installer and the activated module may resolve differently.

**Why:** Asset-tool packages were installed for Python 3.12 while the module's
shim pointed to 3.13, making successful installation look like missing packages.

**How to apply:** Use the matching interpreter and its installed site-packages;
do not repeatedly reinstall or create an unsupported virtual environment.

Use a real-time Flutter test binding for opt-in host UI tests that call live
services, rather than the default automated fake-clock binding.

**Why:** Mixing real SDK networking with fake test clocks can delay response
handling and cleanup even after server writes succeed, producing false timeouts.

**How to apply:** Use LiveTestWidgetsFlutterBinding for live Flutter flows and
settle popup animations before interacting. Keep fixture snapshots private and
verify restoration after every live mutation pass. This is still host UI
verification, not proof of native Keystore, email callbacks or process-death recovery.