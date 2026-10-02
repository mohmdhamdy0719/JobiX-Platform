#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# SQLCipher must be real, never substitute plain SQLite for these tests.
export JOBIX_SQLCIPHER_LIBRARY="${JOBIX_SQLCIPHER_LIBRARY:?Set the SQLCipher shared-library path}"
flutter pub get
flutter gen-l10n
flutter pub run build_runner build
dart tool/check_foundation.dart
flutter analyze
flutter test
bash tool/test_rls.sh