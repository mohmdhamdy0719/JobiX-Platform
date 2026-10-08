#!/bin/bash
set -euo pipefail

# Jobix is the native Flutter product. A native/docs-only merge does not
# authorize installing the unrelated supporting Node workspace, pushing a
# database, restoring native packages, building/signing or starting services.
# Read the merged commit only; never rewrite history or infer cloud approval.
changes="$(git diff-tree --root -m --no-commit-id --name-only -r HEAD)"
while IFS= read -r path; do
  case "$path" in
    ""|mobile/jobix/*|.agents/memory/*|scripts/post-merge.sh|*.md)
      ;;
    *)
      printf 'BLOCKED: non-native merge path requires explicitly scoped setup: %s\n' "$path" >&2
      printf 'No dependency installation, database push or service start performed.\n' >&2
      exit 1
      ;;
  esac
done <<< "$changes"

printf 'PASS: native/docs-only merge; no supporting-service setup required.\n'
printf 'Native package/build/migration checks remain task-specific and approval-gated.\n'
