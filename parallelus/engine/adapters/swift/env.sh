#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../../agentrc
. "$ROOT/parallelus/engine/agentrc"

# Check for Swift compiler
if ! command -v swift >/dev/null 2>&1; then
  echo "swift adapter: swift not found in PATH" >&2
  echo "Please install Swift from https://swift.org/download/" >&2
  exit 1
fi

# Validate Swift Package Manager by invoking it directly
if ! swift package --version >/dev/null 2>&1; then
  echo "swift adapter: Swift Package Manager not available" >&2
  exit 1
fi

# Check for SwiftLint (optional but recommended)
if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swift adapter: SwiftLint not found (optional)" >&2
  echo "Install with: brew install swiftlint" >&2
fi

# Check for SwiftFormat (optional but recommended)
if ! command -v swiftformat >/dev/null 2>&1; then
  echo "swift adapter: SwiftFormat not found (optional)" >&2
  echo "Install with: brew install swiftformat" >&2
fi

# Resolve dependencies if Package.swift exists
if [[ -f "$ROOT/Package.swift" ]]; then
  echo "swift adapter: resolving dependencies..." >&2
  cd "$ROOT"
  swift package resolve >/dev/null 2>&1 || true
fi

echo "swift adapter: environment ready" >&2
