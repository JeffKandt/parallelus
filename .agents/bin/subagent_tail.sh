#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REGISTRY="$ROOT/docs/agents/subagent-registry.json"

usage() {
  cat <<'USAGE'
Usage: subagent_tail.sh --id SUBAGENT_ID [--lines N] [--follow] [--raw]

Stream the latest entries from a subagent log. By default this reads the
structured Codex transcript (subagent.session.jsonl) when available and falls
back to the raw TTY log.

Options:
  --id ID       Subagent registry id (required)
  --lines N     Number of lines to print (default: 80)
  --follow      Follow the file (tail -f behaviour)
  --raw         Force the raw subagent.log transcript instead of JSONL
USAGE
}

ID=""
LINES=80
FOLLOW=0
RAW=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID=$2; shift 2;;
    --lines) LINES=$2; shift 2;;
    --follow) FOLLOW=1; shift;;
    --raw) RAW=1; shift;;
    --help|-h) usage; exit 0;;
    *) echo "subagent_tail.sh: unknown option $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$ID" ]]; then
  echo "subagent_tail.sh: --id is required" >&2
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
        log_path = row.get("log_path") or ""
        print(path)
        print(log_path)
        break
else:
    sys.exit("subagent_tail.sh: unknown id {}".format(entry_id))
PY
)

SANDBOX_PATH=$(printf '%s\n' "$info" | sed -n '1p')
RAW_LOG=$(printf '%s\n' "$info" | sed -n '2p')

SESSION_LOG="$SANDBOX_PATH/subagent.session.jsonl"

target=""
if [[ "$RAW" -eq 0 && -f "$SESSION_LOG" ]]; then
  target="$SESSION_LOG"
else
  target="$RAW_LOG"
fi

if [[ ! -f "$target" ]]; then
  echo "subagent_tail.sh: log file not found: $target" >&2
  exit 1
fi

if [[ "$FOLLOW" -eq 1 ]]; then
  tail -n "$LINES" -f "$target"
else
  tail -n "$LINES" "$target"
fi
