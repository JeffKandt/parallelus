#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../../agentrc
. "$ROOT/.agents/agentrc"

"$ROOT/.agents/adapters/swift/env.sh" >/dev/null

cd "$ROOT"

if [[ -n ${SWIFT_LINT_CMD:-} ]]; then
  echo "Running Swift lint command: $SWIFT_LINT_CMD" >&2
  if ! eval "$SWIFT_LINT_CMD"; then
    echo "swift adapter: lint command failed" >&2
    exit 1
  fi
else
  echo "swift adapter: SWIFT_LINT_CMD not set, skipping lint" >&2
fi

if [[ -f "Package.swift" ]]; then
  echo "Running swift package check..." >&2
  swift package check
fi
