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

INTERVAL=30
THRESHOLD=90
RUNTIME_THRESHOLD=240
FILTER_ID=""
ITERATIONS=""
RECHECK_DELAY=${MONITOR_RECHECK_DELAY:-15}
NUDGE_DELAY=${MONITOR_NUDGE_DELAY:-10}
NUDGE_MESSAGE=${MONITOR_NUDGE_MESSAGE:-}
NUDGE_ESCAPE=${MONITOR_NUDGE_ESCAPE:-1}
NUDGE_CLEAR=${MONITOR_NUDGE_CLEAR:-1}
KNOWN_STUCK=""
TMUX_BIN=$(command -v tmux || true)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SNAPSHOT_DIR=${MONITOR_SNAPSHOT_DIR:-"$REPO_ROOT/.parallelus/monitor-snapshots"}
MONITOR_DEBUG=${MONITOR_DEBUG:-0}
SEND_KEYS_CMD="$REPO_ROOT/.agents/bin/subagent_send_keys.sh"
TAIL_CMD="$REPO_ROOT/.agents/bin/subagent_tail.sh"
mkdir -p "$SNAPSHOT_DIR"
OVERALL_ALERT=0

capture_snapshot() {
  local id="$1"
  local reason="$2"
  local stage="$3"
  local target="$4"
  [[ -z "$TMUX_BIN" || -z "$target" ]] && return 0
  local timestamp
  timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
  local safe_reason=${reason//[^A-Za-z0-9_-]/-}
  local safe_stage=${stage//[^A-Za-z0-9_-]/-}
  local file="$SNAPSHOT_DIR/${id}--${safe_reason}--${safe_stage}--${timestamp}.log"
  "$TMUX_BIN" capture-pane -p -t "$target" >"$file" 2>/dev/null || true
}

mark_stuck() {
  local id="$1"
  case " $KNOWN_STUCK " in
    *" $id "*) return 0 ;;
  esac
  KNOWN_STUCK="$KNOWN_STUCK $id"
}

clear_stuck() {
  local id="$1"
  local next=""
  for existing in $KNOWN_STUCK; do
    [[ "$existing" == "$id" ]] && continue
    next+=" $existing"
  done
  KNOWN_STUCK="${next# }"
}

is_stuck() {
  local id="$1"
  case " $KNOWN_STUCK " in
    *" $id "*) return 0 ;;
  esac
  return 1
}

get_mtime() {
  local path="$1"
  python3 - "$path" <<'PY'
import os, sys
path = sys.argv[1]
if not path or not os.path.exists(path):
    print(-1)
else:
    print(int(os.path.getmtime(path)))
PY
}

investigate_alerts() {
  local alerts_json="$1"
  local rows_json="$2"
  local unresolved=""
  local field_sep=$'\x1f'

  if [[ -z "$alerts_json" || "$alerts_json" == "{}" ]]; then
    return 0
  fi

  local entry
  local investigations=()
  local investigations_output
  investigations_output=$(python3 - <<'PY' "$alerts_json" "$rows_json"
import json
import sys

alerts = json.loads(sys.argv[1] or "{}")
rows = {row.get("id"): row for row in json.loads(sys.argv[2] or "[]")}
seen = set()
for reason, ids in alerts.items():
    if reason not in {"log", "runtime", "stale"}:
        continue
    for id_ in ids:
        if not id_ or (id_, reason) in seen:
            continue
        seen.add((id_, reason))
        row = rows.get(id_) or {}
        handle = row.get("launcher_handle") or {}
        try:
            parts = [
                id_,
                reason,
                (row.get("log_path") or ""),
                str(row.get("log_seconds") if row.get("log_seconds") is not None else ""),
                str(row.get("runtime_seconds") if row.get("runtime_seconds") is not None else ""),
                (row.get("launcher_kind") or ""),
                (handle.get("pane_id") or ""),
                (handle.get("window_id") or ""),
                (row.get("title") or ""),
            ]
        except Exception:
            continue
        print("\x1f".join(str(part).replace("\x1f", " ") for part in parts))
PY
  ) || true
  if (( MONITOR_DEBUG == 1 )); then
    printf '[monitor-debug] alerts_json=%s\n' "$alerts_json" >&2
    printf '[monitor-debug] investigations_output=%s\n' "$investigations_output" >&2
  fi
  if [[ -n "$investigations_output" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      investigations+=("$entry")
    done <<<"$investigations_output"
  fi

  ((${#investigations[@]} == 0)) && return 0

  local id reason log_path log_seconds runtime_seconds launcher_kind pane_id window_id title
  for entry in "${investigations[@]}"; do
    IFS=$'\x1f' read -r id reason log_path log_seconds runtime_seconds launcher_kind pane_id window_id title <<<"$entry"
    [[ -z "$id" ]] && continue

    local tmux_target=""
    if [[ -n "$TMUX_BIN" ]]; then
      if [[ "$launcher_kind" == "tmux-pane" && -n "$pane_id" ]]; then
        tmux_target="$pane_id"
      elif [[ "$launcher_kind" == "tmux-window" && -n "$window_id" ]]; then
        tmux_target="$window_id"
      fi
    fi
    if (( MONITOR_DEBUG == 1 )); then
      printf '[monitor-debug] evaluate id=%s reason=%s target=%s\n' "$id" "$reason" "$tmux_target" >&2
    fi

    capture_snapshot "$id" "$reason" "pre-check" "$tmux_target"

    local skip_recheck=0
    local rechecked=0
    local before after
    if [[ -n "$log_path" ]]; then
      before=$(get_mtime "$log_path")
      if [[ "$before" -ge 0 ]]; then
        sleep "$RECHECK_DELAY"
        rechecked=1
        after=$(get_mtime "$log_path")
        if [[ "$after" -gt "$before" ]]; then
          echo "[monitor] $id heartbeat recovered after recheck ($reason)."
          clear_stuck "$id"
          skip_recheck=1
        fi
      fi
    fi

    if [[ $skip_recheck -eq 1 ]]; then
      continue
    fi

    local nudged=0
    if [[ -n "$tmux_target" ]]; then
      if is_stuck "$id"; then
        echo "[monitor] $id still flagged ($reason); already nudged."
      else
        if [[ -x "$SEND_KEYS_CMD" && -n "$NUDGE_MESSAGE" ]]; then
          local -a clear_args=()
          if (( NUDGE_CLEAR == 0 )); then
            clear_args+=(--no-clear)
          fi
          if (( MONITOR_DEBUG == 1 )); then
            printf '[monitor-debug] nudge id=%s message=%s target=%s\n' "$id" "$NUDGE_MESSAGE" "$tmux_target" >&2
          fi
          echo "[monitor] $id nudged ($reason) with '$NUDGE_MESSAGE'."
          if (( NUDGE_ESCAPE == 1 )); then
            "$TMUX_BIN" send-keys -t "$tmux_target" Escape >/dev/null 2>&1 || true
          fi
          capture_snapshot "$id" "$reason" "pre-nudge" "$tmux_target"
          local nudge_status=0
          if (( ${#clear_args[@]} > 0 )); then
            if ! "$SEND_KEYS_CMD" --id "$id" --text "$NUDGE_MESSAGE" "${clear_args[@]}"; then
              nudge_status=$?
            fi
          else
            if ! "$SEND_KEYS_CMD" --id "$id" --text "$NUDGE_MESSAGE"; then
              nudge_status=$?
            fi
          fi
          if (( nudge_status == 0 )); then
            nudged=1
            capture_snapshot "$id" "$reason" "post-nudge" "$tmux_target"
          else
            echo "[monitor] $id nudge helper failed; manual intervention required."
            nudged=0
          fi
        else
          echo "[monitor] $id requires manual attention (reason: $reason; nudge helper unavailable)."
          capture_snapshot "$id" "$reason" "manual-attention" "$tmux_target"
          mark_stuck "$id"
          unresolved+=" $id"
          continue
        fi
      fi
    fi

    if [[ -z "$log_path" && "$reason" == "runtime" ]]; then
      # Long runtime without log path; nothing to do besides warn.
      :
    elif [[ -n "$log_path" && $rechecked -eq 0 ]]; then
      # No log file available to recheck; nothing else to do here.
      :
    fi

    if [[ $nudged -eq 1 && -n "$log_path" ]]; then
      sleep "$NUDGE_DELAY"
      after=$(get_mtime "$log_path")
      if [[ "$after" -gt "$before" ]]; then
        echo "[monitor] $id responded after nudge ($reason)."
        clear_stuck "$id"
        capture_snapshot "$id" "$reason" "post-nudge-success" "$tmux_target"
        continue
      fi
    fi

    mark_stuck "$id"
    unresolved+=" $id"
    echo "[monitor] $id requires manual attention (reason: $reason)."
    capture_snapshot "$id" "$reason" "manual-attention" "$tmux_target"
    if [[ -x "$TAIL_CMD" ]]; then
      echo "[monitor] Recent log tail for $id:" >&2
      "$TAIL_CMD" --id "$id" --lines 20 >&2 || true
      echo "[monitor] End log tail for $id." >&2
    fi
  done

  if [[ -n "$unresolved" ]]; then
    echo "[monitor] Outstanding subagents:$unresolved"
    return 1
  fi
  return 0
}

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
formatted=$(MONITOR_TABLE="$output" MONITOR_REGISTRY="$REGISTRY" python3 - "$THRESHOLD" "$RUNTIME_THRESHOLD" <<'PY'
import json
import os
import sys

threshold = int(sys.argv[1])
runtime_threshold = int(sys.argv[2])
table = os.environ.get("MONITOR_TABLE", "")
registry_path = os.environ.get("MONITOR_REGISTRY")
registry_entries = []
if registry_path and os.path.exists(registry_path):
    try:
        with open(registry_path, "r", encoding="utf-8") as fh:
            registry_entries = json.load(fh)
    except Exception:
        registry_entries = []
entry_map = {row.get("id"): row for row in registry_entries if isinstance(row, dict)}
lines = table.splitlines()

if not lines:
    print(table, end="")
    print("@@MONITOR_FLAGS {}", end="")
    print("@@MONITOR_ROWS []", end="")
    print("@@MONITOR_ALERTS {}", end="")
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
rows_payload = []
alerts = {"log": [], "runtime": [], "stale": []}


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
    parts = row.split(None, 9)
    if parts and set(parts[0]) <= {"!", "^", "?"}:
        parts = parts[1:]
    if len(parts) < 9:
        result.append(row)
        continue
    ident = parts[0]
    status = parts[3]
    runtime_str = parts[5]
    log_str = parts[6]
    prefix = ""
    stale = False
    runtime_seconds = parse_mmss(runtime_str)
    log_seconds = parse_mmss(log_str)
    entry = entry_map.get(ident, {})
    sandbox_path = entry.get("path") or ""
    session_log_path = os.path.join(sandbox_path, "subagent.session.jsonl") if sandbox_path else ""
    effective_log_path = ""
    if session_log_path and os.path.exists(session_log_path):
        effective_log_path = session_log_path
    elif entry.get("log_path"):
        effective_log_path = entry.get("log_path")
    rows_payload.append({
        "id": ident,
        "status": status,
        "runtime_seconds": runtime_seconds,
        "log_seconds": log_seconds,
        "log_path": effective_log_path,
        "raw_log_path": entry.get("log_path"),
        "session_log_path": session_log_path if session_log_path and os.path.exists(session_log_path) else "",
        "launcher_kind": entry.get("launcher_kind"),
        "launcher_handle": entry.get("launcher_handle"),
        "deliverables_status": entry.get("deliverables_status"),
        "title": entry.get("window_title"),
    })
    if status == "running":
        if runtime_seconds is not None and runtime_seconds > runtime_threshold:
            prefix += "^"
            runtime_alert = True
            if ident not in alerts["runtime"]:
                alerts["runtime"].append(ident)
        if log_seconds is None:
            stale = True
            stale_alert = True
            if ident not in alerts["stale"]:
                alerts["stale"].append(ident)
        elif log_seconds > threshold:
            prefix += "!"
            log_alert = True
            if ident not in alerts["log"]:
                alerts["log"].append(ident)
    if stale:
        prefix = "?" + prefix
    if prefix:
        result.append(f"{prefix} {row}")
    else:
        result.append(row)

print("\n".join(result))
print("@@MONITOR_FLAGS", json.dumps({"log": log_alert, "runtime": runtime_alert, "stale": stale_alert}))
print("@@MONITOR_ROWS", json.dumps(rows_payload))
print("@@MONITOR_ALERTS", json.dumps(alerts))
PY
)

rows_line=$(grep '^@@MONITOR_ROWS ' <<<"$formatted" || true)
alerts_line=$(grep '^@@MONITOR_ALERTS ' <<<"$formatted" || true)
formatted=$(grep -v '^@@MONITOR_\(FLAGS\|ROWS\|ALERTS\) ' <<<"$formatted" || true)
echo "$formatted"

alerts_json="{}"
rows_json="[]"
[[ -n "$alerts_line" ]] && alerts_json=${alerts_line#@@MONITOR_ALERTS }
[[ -n "$rows_line" ]] && rows_json=${rows_line#@@MONITOR_ROWS }

investigate_alerts "$alerts_json" "$rows_json"
alert_status=$?
if (( alert_status != 0 )); then
  OVERALL_ALERT=1
  if [[ -z "$ITERATIONS" ]]; then
    break
  fi
fi
if [[ -n "$ITERATIONS" && poll_count -ge $ITERATIONS ]]; then
  break
fi
sleep "$INTERVAL"
done

if (( OVERALL_ALERT != 0 )); then
  exit 1
fi
