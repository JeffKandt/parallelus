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
Usage: get_current_session_id.sh [options]

Options:
  -n, --count N    Number of recent session IDs to list (default: 1)
      --paths      Include the full session log file path in output
      --timestamps Include modification timestamps in output (implies --paths)
  -h, --help       Show this help message and exit

By default the script prints only the most recent session ID detected under
~/.codex/sessions. Increase --count to show additional recent sessions.
USAGE
}

count=1
show_paths=0
show_timestamps=0
in_tmux=0

if [[ -n "${TMUX:-}" ]]; then
  in_tmux=1
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--count)
      if [[ $# -lt 2 ]]; then
        echo "get_current_session_id.sh: --count requires an argument" >&2
        exit 1
      fi
      count=$2
      shift 2
      ;;
    --paths)
      show_paths=1
      shift
      ;;
    --timestamps)
      show_paths=1
      show_timestamps=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "get_current_session_id.sh: unknown option $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ $count =~ ^[0-9]+$ ]] || [[ $count -le 0 ]]; then
  echo "get_current_session_id.sh: --count must be a positive integer" >&2
  exit 1
fi

python3 - "$count" "$show_paths" "$show_timestamps" <<'PY'
import sys
from pathlib import Path
from datetime import datetime
import re

count = int(sys.argv[1])
show_paths = bool(int(sys.argv[2]))
show_timestamps = bool(int(sys.argv[3]))

root = Path.home() / '.codex' / 'sessions'
if not root.exists():
    print('No sessions found under ~/.codex/sessions', file=sys.stderr)
    sys.exit(1)

files = sorted(
    root.glob('**/*.jsonl'),
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)

if not files:
    print('No session log files found', file=sys.stderr)
    sys.exit(1)

uuid_pattern = re.compile(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', re.IGNORECASE)

rows = []
for path in files[:count]:
    match = uuid_pattern.search(path.name)
    if not match:
        continue
    session_id = match.group(1)
    ts = datetime.fromtimestamp(path.stat().st_mtime)
    rows.append((session_id, ts, path))

if not rows:
    print('No session IDs matched expected pattern', file=sys.stderr)
    sys.exit(1)

if count == 1 and not show_paths and not show_timestamps:
    print(rows[0][0])
else:
    for session_id, ts, path in rows:
        parts = [session_id]
        if show_timestamps:
            parts.append(ts.strftime('%Y-%m-%d %H:%M:%S'))
        if show_paths:
            parts.append(str(path))
        print('  '.join(parts))
PY

status=$?
if [[ $status -ne 0 ]]; then
  exit $status
fi

if [[ $in_tmux -eq 1 ]]; then
  echo "[info] Detected TMUX session (TMUX=$TMUX). Subagents can launch in panes immediately." >&2
else
  echo "[info] TMUX not detected. Plan to exit the current Codex process and resume this session inside tmux before spawning subagents." >&2
fi
