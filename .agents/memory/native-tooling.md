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
read-only system directory.

**How to apply:** Check installer results and actual installation destinations.
Use explicit writable SDK-root environment configuration and verify native
tool discovery before claiming a toolchain is supplied. Do not treat device
tools alone as an Android build SDK.

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