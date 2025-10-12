#!/usr/bin/env bash
# Interactive harness that validates the agent process using a delegated subagent
# session rather than non-interactive Codex execution.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCOPE_TEMPLATE=${SCOPE_TEMPLATE:-"$ROOT/.agents/prompts/process_smoke.txt"}
SUBAGENT_LAUNCHER=${SUBAGENT_LAUNCHER:-auto}
KEEP_SANDBOX=${KEEP_SANDBOX:-0}

usage() {
  cat <<'USAGE'
process_self_test.sh [options]

Environment variables:
  SCOPE_TEMPLATE      Path to the scope/spec used for the throwaway sandbox
  SUBAGENT_LAUNCHER   Launcher override (auto, iterm-window, terminal-window, tmux, manual)
  KEEP_SANDBOX        Set to 1 to retain the sandbox after completion

The harness will:
  1. Launch a throwaway sandbox via .agents/bin/subagent_manager.sh launch
  2. Instruct the user to interact with the subagent session
  3. Verify and clean up once the user reports completion
USAGE
}

if [[ ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

SUBAGENT_MANAGER="$ROOT/.agents/bin/subagent_manager.sh"

if [[ ! -x "$SUBAGENT_MANAGER" ]]; then
  echo "process_self_test: subagent manager not found at $SUBAGENT_MANAGER" >&2
  exit 1
fi

if [[ ! -f "$SCOPE_TEMPLATE" ]]; then
  echo "process_self_test: scope template '$SCOPE_TEMPLATE' not found" >&2
  exit 1
fi

# Launch throwaway sandbox
SUBAGENT_RAW=$(SUBAGENT_LANGS=${SUBAGENT_LANGS:-python} "$SUBAGENT_MANAGER" \
  launch --type throwaway --slug process-smoke --scope "$SCOPE_TEMPLATE" --launcher "$SUBAGENT_LAUNCHER")
SUBAGENT_ID=$(printf '%s\n' "$SUBAGENT_RAW" | tail -n1 | tr -d '\r')

if [[ -z "$SUBAGENT_ID" ]]; then
  echo "process_self_test: failed to launch subagent" >&2
  exit 1
fi

echo "$SUBAGENT_RAW" >&2
echo "process_self_test: launched subagent id=$SUBAGENT_ID" >&2
"$SUBAGENT_MANAGER" status --id "$SUBAGENT_ID"

echo
cat <<'INSTRUCT'
An interactive Codex session should now be running in a separate terminal.
Follow the on-screen checklist. When the subagent finishes, return here.
INSTRUCT

read -rp "Type 'done' once the subagent reports completion: " _reply

"$SUBAGENT_MANAGER" status --id "$SUBAGENT_ID"
"$SUBAGENT_MANAGER" verify --id "$SUBAGENT_ID"

if [[ ${KEEP_SANDBOX} -eq 0 ]]; then
  "$SUBAGENT_MANAGER" cleanup --id "$SUBAGENT_ID"
else
  echo "Sandbox retained per KEEP_SANDBOX=1" >&2
fi

echo "process_self_test: complete" >&2
