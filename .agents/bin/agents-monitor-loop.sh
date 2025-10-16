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
formatted=$(MONITOR_TABLE="$output" python3 - "$THRESHOLD" "$RUNTIME_THRESHOLD" <<'PY'
import json
import os
import sys

threshold = int(sys.argv[1])
runtime_threshold = int(sys.argv[2])
table = os.environ.get("MONITOR_TABLE", "")
lines = table.splitlines()

if not lines:
    print(table, end="")
    print("@@MONITOR_FLAGS {}", end="")
    sys.exit(0)

header = lines[0]
separator = lines[1] if len(lines) > 1 else ""
rows = lines[2:]

result = [header]
if separator:
    result.append(separator)

log_alert = False
runtime_alert = False
stale_alert = False


def parse_mmss(value: str):
    value = value.strip()
    if value in ("-", "", "NA"):
        return None
    if ":" not in value:
        return None
    minutes, seconds = value.split(":", 1)
    if not (minutes.isdigit() and seconds.isdigit()):
        return None
    return int(minutes) * 60 + int(seconds)


for row in rows:
    if not row.strip():
        result.append(row)
        continue
    parts = row.split(None, 8)
    if len(parts) < 9:
        result.append(row)
        continue
    status = parts[3]
    runtime_str = parts[5]
    log_str = parts[6]
    prefix = ""
    stale = False
    if status == "running":
        runtime_seconds = parse_mmss(runtime_str)
        if runtime_seconds is not None and runtime_seconds > runtime_threshold:
            prefix += "^"
            runtime_alert = True
        log_seconds = parse_mmss(log_str)
        if log_seconds is None:
            stale = True
            stale_alert = True
        elif log_seconds > threshold:
            prefix += "!"
            log_alert = True
    if stale:
        prefix = "?" + prefix
    if prefix:
        result.append(f"{prefix} {row}")
    else:
        result.append(row)

print("\n".join(result))
print("@@MONITOR_FLAGS", json.dumps({"log": log_alert, "runtime": runtime_alert, "stale": stale_alert}))
PY
)

flags_line=$(grep '^@@MONITOR_FLAGS ' <<<"$formatted" || true)
formatted=$(grep -v '^@@MONITOR_FLAGS ' <<<"$formatted" || true)
echo "$formatted"

log_trigger="false"
runtime_trigger="false"
stale_trigger="false"
if [[ -n "$flags_line" ]]; then
  flags_json=${flags_line#@@MONITOR_FLAGS }
  read -r log_trigger runtime_trigger stale_trigger < <(python3 - "$flags_json" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
def to_flag(key):
    return "true" if data.get(key) else "false"
print(to_flag("log"), to_flag("runtime"), to_flag("stale"))
PY
  )
fi

if [[ "$log_trigger" == "true" ]]; then
  echo "Log heartbeat threshold exceeded for at least one subagent. Exiting monitor loop."
  break
fi
if [[ "$runtime_trigger" == "true" ]]; then
  echo "Runtime threshold exceeded (likely >$RUNTIME_THRESHOLD seconds) for at least one subagent. Exiting monitor loop."
  break
fi
if [[ "$stale_trigger" == "true" ]]; then
  echo "Stale subagent entry detected (log missing or out of heartbeat scope). Exiting monitor loop."
  break
fi
if [[ -n "$ITERATIONS" && poll_count -ge $ITERATIONS ]]; then
  break
fi
sleep "$INTERVAL"
done
