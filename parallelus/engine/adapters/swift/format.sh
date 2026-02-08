#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../../agentrc
. "$ROOT/parallelus/engine/agentrc"

"$ROOT/parallelus/engine/adapters/swift/env.sh" >/dev/null

cd "$ROOT"

if [[ -n ${SWIFT_FORMAT_CMD:-} ]]; then
  echo "Running Swift format command: $SWIFT_FORMAT_CMD" >&2
  if ! eval "$SWIFT_FORMAT_CMD"; then
    echo "swift adapter: format command failed" >&2
    exit 1
  fi
else
  echo "swift adapter: SWIFT_FORMAT_CMD not set, skipping format" >&2
fi
