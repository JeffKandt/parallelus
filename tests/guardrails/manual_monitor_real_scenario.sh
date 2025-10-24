#!/usr/bin/env bash
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HARNESS_MODE=real "$ROOT/.agents/bin/agents-monitor-real.sh" "$@"
