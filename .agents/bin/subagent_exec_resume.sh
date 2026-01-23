#!/usr/bin/env bash
set -euo pipefail

ROOT=$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1
  pwd -P
)
REGISTRY=${SUBAGENT_REGISTRY_FILE:-"$ROOT/docs/agents/subagent-registry.json"}
TMUX_BIN="$ROOT/.agents/bin/tmux-safe"

usage() {
  cat <<'USAGE'
Usage: subagent_exec_resume.sh --id SUBAGENT_ID (--prompt TEXT | --prompt-file FILE) [--launcher tmux|manual]

Resume a subagent that was launched via `codex exec` by reusing the recorded exec
session id (thread_id). This is intended for follow-ups after exec-mode subagents
finish without needing the interactive TUI.

Options:
  --id ID              Subagent registry id (required)
  --prompt TEXT        Prompt to send on resume (single-line recommended)
  --prompt-file FILE   Read prompt text from a file
  --launcher MODE      `tmux` (default) spawns a new pane; `manual` prints the command
USAGE
}

ID=""
PROMPT=""
PROMPT_FILE=""
LAUNCHER="tmux"
RUN_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID=$2; shift 2;;
    --prompt) PROMPT=$2; shift 2;;
    --prompt-file) PROMPT_FILE=$2; shift 2;;
    --launcher) LAUNCHER=$2; shift 2;;
    --run) RUN_MODE=1; shift;;
    --help|-h) usage; exit 0;;
    *) echo "subagent_exec_resume.sh: unknown option $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$ID" ]]; then
  echo "subagent_exec_resume.sh: --id is required" >&2
  usage
  exit 1
fi

if [[ -n "$PROMPT" && -n "$PROMPT_FILE" ]]; then
  echo "subagent_exec_resume.sh: choose --prompt or --prompt-file (not both)" >&2
  exit 1
fi
if [[ -z "$PROMPT" && -z "$PROMPT_FILE" ]]; then
  echo "subagent_exec_resume.sh: --prompt or --prompt-file is required" >&2
  usage
  exit 1
fi

info=$(python3 - "$REGISTRY" "$ID" <<'PY'
import json, sys
registry_path, entry_id = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        path = row.get("path") or ""
        handle = row.get("launcher_handle") or {}
        pane_id = handle.get("pane_id") or ""
        window_id = handle.get("window_id") or ""
        print(path)
        print(pane_id)
        print(window_id)
        break
else:
    sys.exit("subagent_exec_resume.sh: unknown id {}".format(entry_id))
PY
)

SANDBOX_PATH=$(printf '%s\n' "$info" | sed -n '1p')
PANE_ID=$(printf '%s\n' "$info" | sed -n '2p')
WINDOW_ID=$(printf '%s\n' "$info" | sed -n '3p')

SESSION_ID_FILE="$SANDBOX_PATH/subagent.exec_session_id"
if [[ ! -f "$SESSION_ID_FILE" ]]; then
  echo "subagent_exec_resume.sh: missing exec session id file: $SESSION_ID_FILE" >&2
  echo "  Hint: launch the subagent with SUBAGENT_CODEX_EXEC_JSON=1 (or PARALLELUS_CODEX_EXEC_JSON=1)." >&2
  exit 1
fi

SESSION_ID=$(head -n 1 "$SESSION_ID_FILE" | tr -d '\r')
if [[ -z "$SESSION_ID" ]]; then
  echo "subagent_exec_resume.sh: exec session id file is empty: $SESSION_ID_FILE" >&2
  exit 1
fi

prompt_content=""
if [[ -n "$PROMPT_FILE" ]]; then
  prompt_content=$(cat "$PROMPT_FILE")
else
  prompt_content=$PROMPT
fi

prompt_q=$(python3 - <<'PY' "$prompt_content"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)

if [[ "$LAUNCHER" == "manual" ]]; then
  echo "Run the following to resume:"
  echo ""
  echo "  cd $(python3 - <<'PY' "$SANDBOX_PATH"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
) && codex exec resume --json $(python3 - <<'PY' "$SESSION_ID"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
) $prompt_q"
  exit 0
fi

if [[ "$LAUNCHER" == "run" || "$RUN_MODE" -eq 1 ]]; then
  cd "$SANDBOX_PATH"
  events_path="$SANDBOX_PATH/subagent.exec_resume_events.jsonl"
  last_message_path="$SANDBOX_PATH/subagent.last_message.txt"
  mkdir -p "$(dirname "$events_path")"

  # Run resume with JSONL and write:
  # - full JSONL stream -> events_path (append)
  # - last agent_message -> last_message_path
  codex exec resume --json "$SESSION_ID" "$prompt_content" | python3 - "$events_path" "$last_message_path" <<'PY'
import json
import os
import sys

events_path = sys.argv[1]
last_message_path = sys.argv[2]

os.makedirs(os.path.dirname(events_path) or ".", exist_ok=True)

last_text = None
with open(events_path, "ab") as out:
    for raw in sys.stdin.buffer:
        out.write(raw)
        out.flush()
        line = raw.decode("utf-8", "replace").strip()
        if not line:
            continue
        try:
            evt = json.loads(line)
        except Exception:
            continue
        if evt.get("type") != "item.completed":
            continue
        item = evt.get("item") or {}
        if item.get("type") == "agent_message":
            text = item.get("text")
            if text is not None:
                last_text = str(text)
                sys.stdout.write(last_text.rstrip("\n") + "\n")
                sys.stdout.flush()

if last_text is not None:
    with open(last_message_path, "w", encoding="utf-8") as fh:
        fh.write(last_text.rstrip("\n") + "\n")
PY
  exit $?
fi

if [[ "$LAUNCHER" != "tmux" ]]; then
  echo "subagent_exec_resume.sh: unsupported --launcher $LAUNCHER (expected tmux|manual)" >&2
  exit 1
fi

if [[ ! -x "$TMUX_BIN" ]]; then
  echo "subagent_exec_resume.sh: tmux helper missing: $TMUX_BIN" >&2
  exit 1
fi

# Spawn a new pane for the resume (the original exec-mode pane may have exited).
root_q=$(python3 - <<'PY' "$ROOT"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)
session_q=$(python3 - <<'PY' "$SESSION_ID"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)
sandbox_q=$(python3 - <<'PY' "$SANDBOX_PATH"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)
events_q=$(python3 - <<'PY' "$SANDBOX_PATH/subagent.exec_resume_events.jsonl"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)
last_q=$(python3 - <<'PY' "$SANDBOX_PATH/subagent.last_message.txt"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)
filter_q=$(python3 - <<'PY' "$ROOT/.agents/bin/codex_exec_stream_filter.py"
import shlex, sys
print(shlex.quote(sys.argv[1]))
PY
)

cmd="cd $sandbox_q && codex exec resume --json $session_q $prompt_q | python3 $filter_q --mode json --events-path $events_q --last-message-path $last_q"

new_pane=$("$TMUX_BIN" split-window -h -p 50 -d -P -F '#{pane_id}' -t "${WINDOW_ID:-}" -c "$SANDBOX_PATH" "bash -lc $cmd") || {
  echo "subagent_exec_resume.sh: failed to launch tmux pane" >&2
  exit 1
}

"$TMUX_BIN" select-pane -T "resume:$ID" -t "$new_pane" >/dev/null 2>&1 || true

printf '{"launcher":"tmux-pane","window_id":"%s","pane_id":"%s"}\n' "${WINDOW_ID:-}" "$new_pane"
