#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<'EOF'
Usage: agents-monitor-loop.sh [--interval SECONDS] [--threshold SECONDS] [--runtime-threshold SECONDS] [--iterations N] [--id SUBAGENT_ID]

Poll subagent status at the given interval and report when a subagent's log age
or total runtime exceeds the configured thresholds. When the user presses any key
(Ctrl+C), the loop exits.

Options:
  --interval SECONDS         Sleep duration between polls (default: 45)
  --threshold SECONDS        Maximum acceptable log-age before highlighting (default: 180)
  --runtime-threshold SECONDS  Maximum runtime for a subagent before prompting review (default: 600)
  --iterations N             Stop after N polls (default: infinite)
  --id SUBAGENT_ID           Monitor only the specified subagent ID (default: all running)
EOF
}

INTERVAL=45
THRESHOLD=180
RUNTIME_THRESHOLD=600
FILTER_ID=""
ITERATIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL=$2; shift 2 ;;
    --threshold)
      THRESHOLD=$2; shift 2 ;;
    --runtime-threshold)
      RUNTIME_THRESHOLD=$2; shift 2 ;;
    --iterations)
      ITERATIONS=$2; shift 2 ;;
    --id)
      FILTER_ID=$2; shift 2 ;;
    --help)
      show_usage; exit 0 ;;
    *)
      echo "Unknown option $1" >&2
      show_usage >&2
      exit 1 ;;
  esac
done

REGISTRY="docs/agents/subagent-registry.json"
MANAGER_CMD="$(git rev-parse --show-toplevel)/.agents/bin/subagent_manager.sh"
STATUS_CMD=("$MANAGER_CMD" status)
if [[ -n "$FILTER_ID" ]]; then
  STATUS_CMD+=("--id" "$FILTER_ID")
fi

trap 'echo; echo "Exiting monitor loop."' INT

printf "Monitoring subagents (interval=%ss, log-threshold=%ss, runtime-threshold=%ss). Press Ctrl+C to exit." "$INTERVAL" "$THRESHOLD" "$RUNTIME_THRESHOLD"
if [[ -n "$ITERATIONS" ]]; then
  printf " (max %s polls)" "$ITERATIONS"
fi
printf "\n"

poll_count=0
while true; do
  poll_count=$((poll_count + 1))
  now=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
  echo "--- ${now} ---"
  output=$("${STATUS_CMD[@]}")
  if ! grep -q ' running ' <<<"$output"; then
    echo "$output"
    pending_ids=$(python3 - <<'PY' "$REGISTRY" "$FILTER_ID"
import json
import sys

registry_path, filter_id = sys.argv[1:3]
try:
    with open(registry_path, "r", encoding="utf-8") as fh:
        entries = json.load(fh)
except FileNotFoundError:
    entries = []

pending = []
for row in entries:
    if filter_id and row.get("id") != filter_id:
        continue
    deliverables = row.get("deliverables") or []
    if not deliverables:
        continue
    if any((item.get("status") or "pending").lower() != "harvested" for item in deliverables):
        pending.append(row.get("id"))

if pending:
    print("\n".join(pending))
PY
    )
    if [[ -n "$pending_ids" ]]; then
      echo "Deliverables awaiting harvest:"
      while IFS= read -r pending_id; do
        [[ -z "$pending_id" ]] && continue
        echo "  - $pending_id (run: $MANAGER_CMD harvest --id $pending_id)"
      done <<<"$pending_ids"
    fi
    echo "No running subagents detected. Exiting monitor loop."
    break
  fi
formatted=$(awk -v threshold="$THRESHOLD" -v runtime_threshold="$RUNTIME_THRESHOLD" '
  NR<=2 {print; next}
  {
    prefix = ""
    run_seconds = -1
    log_seconds = -1
    stale = 0
    status = $4
    runtime_str = $6
    log_str = $7
    if (status == "running") {
      if (runtime_str ~ /^[0-9]+:[0-9]{2}$/) {
        split(runtime_str, rt, ":")
        run_seconds = rt[1]*60 + rt[2]
        if (run_seconds > runtime_threshold) {
          prefix = prefix "^"
        }
      }
      if (log_str == "-" || log_str == "" || log_str == "NA") {
        stale = 1
      } else if (log_str ~ /^[0-9]+:[0-9]{2}$/) {
        split(log_str, lt, ":")
        log_seconds = lt[1]*60 + lt[2]
        if (log_seconds > threshold) {
          prefix = prefix "!"
        }
      }
    }
    if (stale) {
      prefix = "?" prefix
    }
    if (prefix != "") {
      print prefix " " $0
    } else {
      print $0
    }
  }
' <<<"$output")
echo "$formatted"
if grep -Eq '^(\?|\^)*! ' <<<"$formatted"; then
  echo "Log heartbeat threshold exceeded for at least one subagent. Exiting monitor loop."
  break
fi
if grep -Eq '^\?*\^' <<<"$formatted"; then
  echo "Runtime threshold exceeded (likely >$RUNTIME_THRESHOLD seconds) for at least one subagent. Exiting monitor loop."
  break
fi
if grep -q '^\?' <<<"$formatted"; then
  echo "Stale subagent entry detected (log missing or out of heartbeat scope). Exiting monitor loop."
  break
fi
if [[ -n "$ITERATIONS" && poll_count -ge $ITERATIONS ]]; then
  break
fi
sleep "$INTERVAL"
done
