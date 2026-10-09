---
name: Native tooling constraints
description: Package availability and SDK-root behavior differ across workspace tooling
---

The owner confirmed that the current development APK installed, signed in,
displayed their existing personal resume and downloaded/opened the generated
PDF on Samsung M31.

**Why:** This explicit owner confirmation is physical-device evidence that
host widgets and a successful APK build cannot supply.

**How to apply:** Distinguish owner-reported native success from agent-driven
ADB instrumentation. It does not prove Arabic layout when the actual resume
contains only English, or future APK/native-channel changes.

For an installed Nix library, derive its prefix from the executable on PATH
instead of recursively scanning or globbing the whole /nix/store.

**Why:** Both global store scans timed out while the required SQLCipher
installation was already discoverable through its executable.

**How to apply:** Resolve the installed binary, then inspect only its sibling
library directory. Supply test-specific library paths to the test process,
not global runtime libc/environment settings.

Do not treat an existing Dart package_config as proof locked packages are
still cached. Missing pub-cache files can produce cascading undefined-symbol
errors that look like Flutter API/version failures.

**Why:** The package config survived while critical locked test/UI packages
and even the included formatter/lint options disappeared from the cache.

**How to apply:** Diagnose the first missing-file error before changing app
code or SDK versions. Restore exact locked packages, not upgrades, within
the owner's setup approval; distinguish zero tests loaded from failed tests.

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

Check signing continuity before delivering a rebuilt development APK from a
resumed workspace. Missing home-directory debug keys can silently generate a
new certificate, even when the package ID and source history are unchanged.

**Why:** A fresh ARM64 build verified successfully but its new default debug
certificate differed from the previously delivered APK. Android cannot update
that existing installation with the new signer.

**How to apply:** Compare public APK certificate digests. Never recommend
uninstalling or clearing app data to bypass a signing mismatch; preserve the
old install and recover its original signing key or seek explicit approval
for an alternative test arrangement.

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

Use a real-time Flutter test binding for opt-in host UI tests that involve SDK
streams/networking and actual database-isolate I/O, rather than the default
automated fake-clock binding. This also applies when HTTP is mocked.

**Why:** Mixing asynchronous SDK/database I/O with fake test clocks can delay
response handling and cleanup, producing false timeouts even in local fixtures.

**How to apply:** Use LiveTestWidgetsFlutterBinding for live Flutter flows and
settle popup animations before interacting. Keep fixture snapshots private and
verify restoration after every live mutation pass. This is still host UI
verification, not proof of native Keystore, email callbacks or process-death recovery.

Flutter dependency restoration can run localization generation/formatting before
downloading missing packages.

**Why:** A surviving package configuration may reference a deleted lint cache;
the formatter then fails before dependency resolution can restore that cache.

**How to apply:** For an owner-authorized locked restore, bootstrap only the
missing lint packages at their exact lockfile versions, then use
`flutter pub get --enforce-lockfile`. Do not disable lint rules, upgrade
dependencies or alter package manifests to work around it.

For formatting a pure-Dart helper when the Flutter lint include is missing,
format stdin from outside the native package with explicit language version,
page width and trailing-comma mode. Do not disable analyzer rules or restore
dependencies solely to format that helper.

**Why:** Overriding page width alone still made the formatter resolve the absent
lint include for its trailing-comma configuration; stdin with all formatting
settings supplied avoided that lookup.

**How to apply:** This is a formatting-only workaround for pure-Dart tools.
It does not prove Flutter analysis/tests pass or replace their dependencies.

Native-only merges must not trigger the supporting Node workspace's dependency
installation or an automatic database push. Non-native setup must fail closed
until its scope is explicitly authorized.

**Why:** The generic post-merge hook attempted an unrelated Node install after
a native print-test merge and failed on a registry denial. It also contained an
unconditional database push, contrary to the owner's native/service boundary.

**How to apply:** Keep post-merge setup scope-aware. Test a native no-op hook
directly if the combined setup runner would restart unauthorized supporting
workflows; do not claim workflow reconciliation has been verified in that case.