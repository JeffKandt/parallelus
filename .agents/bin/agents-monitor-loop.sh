#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<'EOF'
Usage: agents-monitor-loop.sh [--interval SECONDS] [--threshold SECONDS] [--runtime-threshold SECONDS] [--iterations N] [--id SUBAGENT_ID]

Poll subagent status at the given interval and report when a subagent's log age
or total runtime exceeds the configured thresholds. When the user presses any key
(Ctrl+C), the loop exits.

Options:
  --interval SECONDS         Sleep duration between polls (default: 30)
  --threshold SECONDS        Maximum acceptable log-age before highlighting (default: 90)
  --runtime-threshold SECONDS  Maximum runtime for a subagent before prompting review (default: 240)
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
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
TMUX_HELPER="$REPO_ROOT/.agents/bin/tmux-safe"
if [[ -x "$TMUX_HELPER" ]]; then
  TMUX_BIN="$TMUX_HELPER"
else
  TMUX_BIN=$(command -v tmux || true)
fi
SNAPSHOT_DIR=${MONITOR_SNAPSHOT_DIR:-"$REPO_ROOT/.parallelus/monitor-snapshots"}
MONITOR_DEBUG=${MONITOR_DEBUG:-0}
SEND_KEYS_CMD="$REPO_ROOT/.agents/bin/subagent_send_keys.sh"
TAIL_CMD="$REPO_ROOT/.agents/bin/subagent_tail.sh"
mkdir -p "$SNAPSHOT_DIR"
OVERALL_ALERT=0

AUTO_EXIT_POLLS_RAW=${MONITOR_AUTO_EXIT_STALE_POLLS:-3}
if [[ "$AUTO_EXIT_POLLS_RAW" =~ ^[0-9]+$ ]]; then
  AUTO_EXIT_POLLS=$((10#$AUTO_EXIT_POLLS_RAW))
else
  AUTO_EXIT_POLLS=0
fi
STALE_COUNTS=""

get_stale_count() {
  local key="$1"
  local entry
  for entry in $STALE_COUNTS; do
    if [[ "${entry%%=*}" == "$key" ]]; then
      printf '%s\n' "${entry#*=}"
      return
    fi
  done
  printf '0\n'
}

set_stale_count() {
  local key="$1"
  local value="$2"
  local new_counts=""
  local entry
  local found=0
  for entry in $STALE_COUNTS; do
    if [[ "${entry%%=*}" == "$key" ]]; then
      found=1
      if (( value > 0 )); then
        new_counts+="$key=$value "
      fi
    else
      new_counts+="$entry "
    fi
  done
  if (( !found )) && (( value > 0 )); then
    new_counts+="$key=$value "
  fi
  STALE_COUNTS="${new_counts#" "}"
}

prune_non_running() {
  local new_counts=""
  local entry
  local key
  local lookup=" $* "
  for entry in $STALE_COUNTS; do
    key=${entry%%=*}
    if [[ "$lookup" == *" $key "* ]]; then
      new_counts+="$entry "
    fi
  done
  STALE_COUNTS="${new_counts#" "}"
}

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
            if "$SEND_KEYS_CMD" --id "$id" --text "$NUDGE_MESSAGE" "${clear_args[@]}"; then
              nudge_status=0
            else
              nudge_status=$?
            fi
          else
            if "$SEND_KEYS_CMD" --id "$id" --text "$NUDGE_MESSAGE"; then
              nudge_status=0
            else
              nudge_status=$?
            fi
          fi
          if (( nudge_status == 0 )); then
            nudged=1
            capture_snapshot "$id" "$reason" "post-nudge" "$tmux_target"
          else
            echo "[monitor] $id nudge helper failed (exit $nudge_status); manual intervention required."
            capture_snapshot "$id" "$reason" "nudge-failure" "$tmux_target"
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
  now_display=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
  now_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "--- ${now_display} ---"
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
formatted=$(MONITOR_NOW_ISO="$now_iso" MONITOR_TABLE="$output" MONITOR_REGISTRY="$REGISTRY" python3 - "$THRESHOLD" "$RUNTIME_THRESHOLD" <<'PY'
import datetime
import json
import os
import sys

threshold = int(sys.argv[1])
runtime_threshold = int(sys.argv[2])
table = os.environ.get("MONITOR_TABLE", "")
now_iso = os.environ.get("MONITOR_NOW_ISO")
current_dt = None
if now_iso:
    try:
        current_dt = datetime.datetime.fromisoformat(now_iso.replace("Z", "+00:00"))
    except Exception:
        current_dt = None
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
    meaningful_age = None
    if session_log_path and os.path.exists(session_log_path) and current_dt is not None:
        try:
            with open(session_log_path, "r", encoding="utf-8") as fh:
                for raw_line in fh:
                    raw_line = raw_line.strip()
                    if not raw_line:
                        continue
                    try:
                        event = json.loads(raw_line)
                    except Exception:
                        continue
                    ts = event.get("ts")
                    if not ts:
                        continue
                    kind = (event.get("kind") or "").lower()
                    if kind == "app_event":
                        variant = (event.get("variant") or "").lower()
                        if variant == "committick":
                            continue
                    meaningful_ts = ts
                    try:
                        event_dt = datetime.datetime.fromisoformat(meaningful_ts.replace("Z", "+00:00"))
                        delta = current_dt - event_dt
                        meaningful_age = max(int(delta.total_seconds()), 0)
                    except Exception:
                        meaningful_age = None
        except Exception:
            meaningful_age = None

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
        "meaningful_age_seconds": meaningful_age,
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

auto_exit_candidate=0
auto_exit_ids_str=""
auto_exit_message=""
auto_exit_reason=""
declare -a running_ids=()
declare -a stale_meaningful_ids=()
declare -a deliverable_ready_ids=()
if (( AUTO_EXIT_POLLS > 0 )); then
  state_lines=$(ROWS_JSON="$rows_json" python3 - "$THRESHOLD" <<'PY'
import json
import os
import sys

threshold = int(sys.argv[1])
rows = json.loads(os.environ.get("ROWS_JSON") or "[]")
running = []
stale_meaningful = []
deliverable_ready = []
for row in rows:
    if (row.get("status") or "").lower() != "running":
        continue
    ident = row.get("id")
    if not ident:
        continue
    running.append(ident)
    meaningful = row.get("meaningful_age_seconds")
    if meaningful is None or meaningful > threshold:
        stale_meaningful.append(ident)
    deliverable_status = (row.get("deliverables_status") or "").lower()
    if deliverable_status and deliverable_status not in {"", "-", "waiting", "harvested"}:
        deliverable_ready.append(ident)

print("RUNNING " + " ".join(running))
print("STALE_MEANINGFUL " + " ".join(stale_meaningful))
print("DELIV_READY " + " ".join(deliverable_ready))
PY
  ) || state_lines=""
  while IFS= read -r line; do
    key=${line%% *}
    rest=${line#${key}}
    rest=${rest# }
    case "$key" in
      RUNNING) if [[ -n "$rest" ]]; then read -r -a running_ids <<<"$rest"; else running_ids=(); fi ;;
      STALE_MEANINGFUL) if [[ -n "$rest" ]]; then read -r -a stale_meaningful_ids <<<"$rest"; else stale_meaningful_ids=(); fi ;;
      DELIV_READY) if [[ -n "$rest" ]]; then read -r -a deliverable_ready_ids <<<"$rest"; else deliverable_ready_ids=(); fi ;;
    esac
  done <<<"$state_lines"

  if (( ${#stale_meaningful_ids[@]-0} > 0 )); then
    stale_lookup=" ${stale_meaningful_ids[*]} "
  else
    stale_lookup=" "
  fi
  prune_non_running "${running_ids[@]}"
  for id in "${stale_meaningful_ids[@]-}"; do
    [[ -z "$id" ]] && continue
    current=$(get_stale_count "$id")
    current=$((current + 1))
    set_stale_count "$id" "$current"
  done
  for id in "${running_ids[@]-}"; do
    [[ -z "$id" ]] && continue
    if [[ "$stale_lookup" != *" $id "* ]]; then
      set_stale_count "$id" 0
    fi
  done

  if (( ${#running_ids[@]-0} > 0 )); then
    deliverable_complete=1
    if (( ${#deliverable_ready_ids[@]-0} == 0 )); then
      deliverable_complete=0
    else
      for id in "${running_ids[@]-}"; do
        if [[ " ${deliverable_ready_ids[*]-} " != *" $id "* ]]; then
          deliverable_complete=0
          break
        fi
      done
    fi

    if (( deliverable_complete == 1 )); then
      auto_exit_candidate=1
      auto_exit_ids_str="${deliverable_ready_ids[*]}"
      auto_exit_message="[monitor] Deliverables ready for ${auto_exit_ids_str}; exiting monitor."
      auto_exit_reason="deliverable"
    else
      all_stale=1
      for id in "${running_ids[@]-}"; do
        if [[ "$stale_lookup" != *" $id "* ]]; then
          all_stale=0
          break
        fi
      done
      if (( all_stale == 1 )); then
        ready=1
        exit_ids_formatted=""
        for id in "${running_ids[@]-}"; do
          count=$(get_stale_count "$id")
          if (( count < AUTO_EXIT_POLLS )); then
            ready=0
            break
          fi
          exit_ids_formatted+=" $id(${count})"
        done
        if (( ready == 1 )); then
          auto_exit_candidate=1
          auto_exit_ids_str="${exit_ids_formatted# }"
          auto_exit_message="[monitor] Auto-exit triggered after ${AUTO_EXIT_POLLS} consecutive stale polls: ${auto_exit_ids_str}"
          auto_exit_reason="stale"
        fi
      fi
    fi
  fi
fi

 if (( auto_exit_candidate == 1 )) && [[ "$auto_exit_reason" == "deliverable" ]]; then
  OVERALL_ALERT=0
  [[ -n "$auto_exit_message" ]] && echo "$auto_exit_message"
  break
 fi

investigate_alerts "$alerts_json" "$rows_json"
alert_status=$?
if (( alert_status != 0 )); then
  if (( auto_exit_candidate == 1 )); then
    if [[ "$auto_exit_reason" == "deliverable" ]]; then
      OVERALL_ALERT=0
    else
      OVERALL_ALERT=1
    fi
    [[ -n "$auto_exit_message" ]] && echo "$auto_exit_message"
    break
  fi
  OVERALL_ALERT=1
  if [[ -z "$ITERATIONS" ]]; then
    break
  fi
else
  if (( auto_exit_candidate == 1 )); then
    if [[ "$auto_exit_reason" == "deliverable" ]]; then
      OVERALL_ALERT=0
    else
      OVERALL_ALERT=1
    fi
    [[ -n "$auto_exit_message" ]] && echo "$auto_exit_message"
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
