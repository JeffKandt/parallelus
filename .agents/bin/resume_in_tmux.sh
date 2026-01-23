#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TMUX:-}" && -n "${PARALLELUS_TMUX_SOCKET:-}" ]]; then
  if command -v tmux >/dev/null 2>&1; then
    tmux_env=$(tmux -S "${PARALLELUS_TMUX_SOCKET}" display-message -p '#{socket_path},#{session_id},#{pane_id}' 2>/dev/null || true)
    if [[ -n "${tmux_env:-}" ]]; then
      export TMUX="$tmux_env"
    fi
  fi
fi

usage() {
  cat <<'USAGE'
Usage: resume_in_tmux.sh [OPTIONS] [SESSION_ID]

Resume the specified Codex session (or the most recent one if SESSION_ID is
omitted) inside a tmux session. The default tmux session name is "parallelus";
override with TMUX_MAIN_SESSION.

Options:
  -p, --prompt TEXT   Optional message delivered to Codex after resuming.
  -h, --help          Show this help message.

If already inside tmux, the script runs `codex resume SESSION_ID [PROMPT]` in
the current pane. Otherwise it attaches/creates the target tmux session and
spawns Codex there.

Environment:
  PARALLELUS_CODEX_NO_ALT_SCREEN=1  Pass `--no-alt-screen` to Codex.
USAGE
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -p|--prompt)
      if [[ $# -lt 2 ]]; then
        echo "resume_in_tmux.sh: --prompt requires an argument" >&2
        exit 1
      fi
      PROMPT=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "resume_in_tmux.sh: unknown option $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SESSION_HELPER="$ROOT/.agents/bin/get_current_session_id.sh"
SESSION_NAME=${TMUX_MAIN_SESSION:-parallelus}

session_id=${1:-}
PROMPT=${PROMPT:-"Session resumed inside tmux. Would you like me to re-run the pending subagent launch now?"}

if [[ -z "$session_id" ]]; then
  if [[ -x "$SESSION_HELPER" ]]; then
    if ! session_id=$("$SESSION_HELPER" 2>/dev/null); then
      echo "resume_in_tmux.sh: unable to determine current session id" >&2
      exit 1
    fi
    session_id=$(printf '%s' "$session_id" | head -n1 | tr -d '\r')
  else
    echo "resume_in_tmux.sh: helper $SESSION_HELPER not found" >&2
    exit 1
  fi
fi

if [[ -z "$session_id" ]]; then
  echo "resume_in_tmux.sh: session id is empty" >&2
  exit 1
fi

build_cmd() {
  local cmd=("codex")
  if [[ -n "${PARALLELUS_CODEX_NO_ALT_SCREEN:-}" ]]; then
    cmd+=("--no-alt-screen")
  fi
  cmd+=("resume" "$session_id")
  if [[ -n "$PROMPT" ]]; then
    cmd+=("$PROMPT")
  fi
  printf '%s' "$(printf '%q ' "${cmd[@]}")"
}

if [[ -n "${TMUX:-}" ]]; then
  echo "[info] Already inside tmux (TMUX=$TMUX). Running codex resume $session_id here." >&2
  args=()
  if [[ -n "${PARALLELUS_CODEX_NO_ALT_SCREEN:-}" ]]; then
    args+=("--no-alt-screen")
  fi
  if [[ -n "$PROMPT" ]]; then
    exec codex "${args[@]}" resume "$session_id" "$PROMPT"
  else
    exec codex "${args[@]}" resume "$session_id"
  fi
fi

command_str=$(build_cmd)

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux new-window -t "$SESSION_NAME" -n main-agent -c "$ROOT" "$command_str"
  exec tmux attach-session -t "$SESSION_NAME"
else
  exec tmux new-session -s "$SESSION_NAME" -c "$ROOT" "$command_str"
fi
