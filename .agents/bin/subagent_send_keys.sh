#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REGISTRY="$ROOT/docs/agents/subagent-registry.json"
TMUX_HELPER="$ROOT/.agents/bin/tmux-safe"
if [[ -x "$TMUX_HELPER" ]]; then
  TMUX_BIN="$TMUX_HELPER"
else
  TMUX_BIN=$(command -v tmux || true)
fi

usage() {
  cat <<'USAGE'
Usage: subagent_send_keys.sh --id SUBAGENT_ID --text "Proceed" [--no-clear]

Send a line of text to the Codex subagent pane using the safe bracketed-paste
sequence. The default behaviour clears the current prompt (Ctrl+U) before
pasting and presses Enter after the text.

Options:
  --id ID        Subagent registry id (required)
  --text STRING  Text to send (required)
  --no-clear     Do not send Ctrl+U before pasting
USAGE
}

ID=""
TEXT=""
CLEAR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID=$2; shift 2;;
    --text) TEXT=$2; shift 2;;
    --no-clear) CLEAR=0; shift;;
    --help|-h) usage; exit 0;;
    *) echo "subagent_send_keys.sh: unknown option $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$TMUX_BIN" ]]; then
  echo "subagent_send_keys.sh: tmux not found" >&2
  exit 1
fi

if [[ -z "$ID" || -z "$TEXT" ]]; then
  echo "subagent_send_keys.sh: --id and --text are required" >&2
  usage
  exit 1
fi

pane_id=$(python3 - "$REGISTRY" "$ID" <<'PY'
import json, sys
registry_path, entry_id = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        handle = row.get("launcher_handle") or {}
        pane = handle.get("pane_id")
        if not pane:
            window = handle.get("window_id")
            if window:
                print(window)
        else:
            print(pane)
        break
else:
    sys.exit("subagent_send_keys.sh: unknown id {}".format(entry_id))
PY
)

if [[ -z "$pane_id" ]]; then
  echo "subagent_send_keys.sh: no tmux pane recorded for $ID" >&2
  exit 1
fi

if (( CLEAR == 1 )); then
  "$TMUX_BIN" send-keys -t "$pane_id" C-u >/dev/null 2>&1 || true
fi
"$TMUX_BIN" send-keys -t "$pane_id" Escape "[200~" >/dev/null 2>&1 || true
"$TMUX_BIN" send-keys -t "$pane_id" -- "$TEXT" >/dev/null 2>&1 || true
"$TMUX_BIN" send-keys -t "$pane_id" Escape "[201~" >/dev/null 2>&1 || true
"$TMUX_BIN" send-keys -t "$pane_id" Enter >/dev/null 2>&1 || true
