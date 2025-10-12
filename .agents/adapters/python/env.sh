#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../../agentrc
. "$ROOT/.agents/agentrc"

PYTHON_BIN="${PYTHON:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PYTHON_BIN=python
  else
    echo "python adapter: python3 not found" >&2
    exit 1
  fi
fi

VENV_DIR="$ROOT/${VENV_PATH}" 

if [[ ! -d "$VENV_DIR" ]]; then
  echo "python adapter: creating virtualenv at $VENV_DIR" >&2
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090
. "$VENV_DIR/bin/activate"

if [[ -f "$ROOT/requirements.txt" ]]; then
  pip install -r "$ROOT/requirements.txt" >/dev/null
fi

echo "python adapter: environment ready at $VENV_DIR" >&2
