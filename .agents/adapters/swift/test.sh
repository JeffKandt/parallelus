#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../../agentrc
. "$ROOT/.agents/agentrc"

"$ROOT/.agents/adapters/swift/env.sh" >/dev/null

cd "$ROOT"

if [[ -f "Package.swift" ]]; then
  if [[ -n ${SWIFT_TEST_CMD:-} ]]; then
    echo "Running Swift test command: $SWIFT_TEST_CMD" >&2
    if ! eval "$SWIFT_TEST_CMD"; then
      echo "swift adapter: test command failed" >&2
      exit 1
    fi
  else
    echo "swift adapter: SWIFT_TEST_CMD not set, skipping tests" >&2
  fi
else
  echo "No Package.swift found, skipping tests" >&2
fi
