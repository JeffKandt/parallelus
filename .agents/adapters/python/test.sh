#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../../agentrc
. "$ROOT/.agents/agentrc"

"$ROOT/.agents/adapters/python/env.sh" >/dev/null

# shellcheck disable=SC1091
. "$ROOT/${VENV_PATH}/bin/activate"

eval "$PY_TEST_CMD"
