#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
env="${1:?Supply dev, staging or prod}"
case "$env" in dev|staging|prod) ;; *) echo "Invalid environment" >&2; exit 1 ;; esac
# All three projects must be configured and distinct before a build.
dart tool/check_foundation.dart config/{dev,staging,prod}.local.json
flutter build apk --debug --dart-define-from-file="config/$env.local.json"