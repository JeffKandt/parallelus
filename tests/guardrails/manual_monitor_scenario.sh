#!/usr/bin/env bash
# Manual subagent-monitor scenario harness.
#
# Launches a suite of simulated subagents that exercise the hardened
# agents-monitor-loop behaviours: silent workers, slow heartbeats, jobs that
# unblock only after a nudge, failures that stay stuck, and fast failures.
#
# The script seeds the registry with synthetic entries pointing at sandbox
# directories and drives tmux panes that mimic subagent runtime, writing to
# the expected `subagent.log` files and (for success cases) dropping manifest
# artifacts under `deliverables/`.
#
# On completion it validates monitor output to ensure each scenario produced
# the expected signals (nudge success, manual attention, silent completion).

set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REGISTRY="$ROOT/parallelus/manuals/subagent-registry.json"
REGISTRY_BACKUP=$(mktemp)
SANDBOX_ROOT="$ROOT/.parallelus/test-monitor-scenario"
KEEP_SESSION=${KEEP_SESSION:-1}
MONITOR_LOG_PATH=${MONITOR_LOG_PATH:-}
if [[ -n "$MONITOR_LOG_PATH" ]]; then
  MONITOR_LOG="$MONITOR_LOG_PATH"
  : >"$MONITOR_LOG"
else
  MONITOR_LOG=$(mktemp)
fi

INTERVAL=${INTERVAL:-10}
HEARTBEAT_THRESHOLD=${HEARTBEAT_THRESHOLD:-25}
RUNTIME_THRESHOLD=${RUNTIME_THRESHOLD:-60}
ITERATIONS=${ITERATIONS:-60}
RECHECK_DELAY=${RECHECK_DELAY:-5}
NUDGE_DELAY=${NUDGE_DELAY:-3}
NUDGE_MESSAGE=${NUDGE_MESSAGE:-Proceed}
HARNESS_TIMEOUT=${HARNESS_TIMEOUT:-0}

mkdir -p "$SANDBOX_ROOT"
cp "$REGISTRY" "$REGISTRY_BACKUP"
printf '[]\n' >"$REGISTRY"

WINDOW_ID=""
MAIN_PANE=""
RIGHT_STACK_ROOT=""
RIGHT_STACK_PANES=()
CASE_ENTRY_ID=()
CASE_PANE=()
CASE_SANDBOX=()
CASE_DONE=()
CASE_RESULT=()
CASE_DELIVERABLE=()

set_window_option() {
  local window=$1
  local option=$2
  local value=$3
  tmux set-option -w -t "$window" "$option" "$value" >/dev/null 2>&1 || true
}

get_window_option() {
  local window=$1
  local option=$2
  tmux show-option -qv -w -t "$window" "$option" 2>/dev/null || true
}

unset_window_option() {
  local window=$1
  local option=$2
  tmux set-option -u -w -t "$window" "$option" >/dev/null 2>&1 || true
}

enable_pane_labels() {
  local window=$1
  local saved_status
  local saved_format

  saved_status=$(get_window_option "$window" @parallelus_saved_pane_border_status)
  if [[ -z "$saved_status" ]]; then
    saved_status=$(tmux show-option -qv -w -t "$window" pane-border-status 2>/dev/null || true)
    [[ -z "$saved_status" ]] && saved_status="__unset__"
    set_window_option "$window" @parallelus_saved_pane_border_status "$saved_status"
  fi

  saved_format=$(get_window_option "$window" @parallelus_saved_pane_border_format)
  if [[ -z "$saved_format" ]]; then
    saved_format=$(tmux show-option -qv -w -t "$window" pane-border-format 2>/dev/null || true)
    [[ -z "$saved_format" ]] && saved_format="__unset__"
    set_window_option "$window" @parallelus_saved_pane_border_format "$saved_format"
  fi

  tmux set-option -w -t "$window" pane-border-status top >/dev/null 2>&1 || true
  tmux set-option -w -t "$window" pane-border-format " #P #{pane_title} " >/dev/null 2>&1 || true
}

restore_pane_labels() {
  local window=$1
  local saved_status
  local saved_format

  saved_status=$(get_window_option "$window" @parallelus_saved_pane_border_status)
  if [[ -n "$saved_status" ]]; then
    if [[ "$saved_status" == "__unset__" ]]; then
      tmux set-option -u -w -t "$window" pane-border-status >/dev/null 2>&1 || true
    else
      tmux set-option -w -t "$window" pane-border-status "$saved_status" >/dev/null 2>&1 || true
    fi
    unset_window_option "$window" @parallelus_saved_pane_border_status
  fi

  saved_format=$(get_window_option "$window" @parallelus_saved_pane_border_format)
  if [[ -n "$saved_format" ]]; then
    if [[ "$saved_format" == "__unset__" ]]; then
      tmux set-option -u -w -t "$window" pane-border-format >/dev/null 2>&1 || true
    else
      tmux set-option -w -t "$window" pane-border-format "$saved_format" >/dev/null 2>&1 || true
    fi
    unset_window_option "$window" @parallelus_saved_pane_border_format
  fi
}

rebalance_subagent_column() {
  local window_id=$1
  local panes_string=$2
  [[ -z "$panes_string" ]] && return 0
  local -a panes
  IFS=' ' read -r -a panes <<< "$panes_string"
  local pane_count=${#panes[@]}
  ((pane_count == 0)) && return 0

  local -a observed_ids=()
  local -a observed_heights=()
  local pane_id_line pane_height
  while IFS=' ' read -r pane_id_line pane_height; do
    observed_ids+=("$pane_id_line")
    observed_heights+=("$pane_height")
  done < <(tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_height}')

  local -a valid_panes=()
  local total_height=0
  local pane h i
  for pane in "${panes[@]}"; do
    h=0
    for i in "${!observed_ids[@]}"; do
      if [[ "${observed_ids[$i]}" == "$pane" ]]; then
        h=${observed_heights[$i]}
        valid_panes+=("$pane")
        break
      fi
    done
    [[ $h -eq 0 ]] && continue
    total_height=$((total_height + h))
  done
  if (( ${#valid_panes[@]} == 0 )); then
    panes=()
  else
    panes=("${valid_panes[@]}")
  fi
  pane_count=${#panes[@]}
  if ((pane_count == 0 || total_height == 0)); then
    unset_window_option "$window_id" @parallelus_subagent_panes
    unset_window_option "$window_id" @parallelus_subagent_stack_root
    restore_pane_labels "$window_id"
    return 0
  fi
  local sanitized_list="${panes[*]}"
  set_window_option "$window_id" @parallelus_subagent_panes "$sanitized_list"

  local base=$((total_height / pane_count))
  local remainder=$((total_height - base * pane_count))

  local idx=0
  for pane in "${panes[@]}"; do
    local target_height=$base
    if (( idx == pane_count - 1 )); then
      target_height=$((base + remainder))
    fi
    tmux resize-pane -t "$pane" -y "$target_height" >/dev/null 2>&1 || true
    idx=$((idx + 1))
  done
}

cleanup() {
  local status=$?
  if [[ $KEEP_SESSION -eq 0 ]]; then
    for pane in "${CASE_PANE[@]-}"; do
      if [[ -n "$pane" ]]; then
        tmux kill-pane -t "$pane" >/dev/null 2>&1 || true
      fi
    done
    if [[ -n "$WINDOW_ID" ]]; then
      restore_pane_labels "$WINDOW_ID"
      unset_window_option "$WINDOW_ID" @parallelus_subagent_panes
      unset_window_option "$WINDOW_ID" @parallelus_subagent_stack_root
    fi
    RIGHT_STACK_PANES=()
    RIGHT_STACK_ROOT=""
  else
    if [[ -n "${CASE_PANE[*]}" ]]; then
      echo "Subagent panes preserved (IDs: ${CASE_PANE[*]})." >&2
    fi
    echo "When finished, collapse with: tmux kill-pane -a -t $MAIN_PANE" >&2
  fi
  cp "$REGISTRY_BACKUP" "$REGISTRY"
  rm -f "$REGISTRY_BACKUP"
  if [[ -z "$MONITOR_LOG_PATH" ]]; then
    rm -f "$MONITOR_LOG"
  fi
  if [[ $KEEP_SESSION -eq 0 ]]; then
    rm -rf "$SANDBOX_ROOT"
  else
    echo "Sandbox retained at $SANDBOX_ROOT" >&2
  fi
  return $status
}
trap cleanup EXIT

python_append_entry() {
  local entry_json=$1
  python3 - "$REGISTRY" "$entry_json" <<'PY'
import json
import sys

path, payload_json = sys.argv[1:3]
with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
data.append(json.loads(payload_json))
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
PY
}

python_update_status() {
  local id=$1 status=$2 deliverable_state=${3:-}
  python3 - "$REGISTRY" "$id" "$status" "$deliverable_state" <<'PY'
import json
import sys

path, entry_id, status, deliverable_state = sys.argv[1:5]
with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
for row in data:
    if row.get('id') == entry_id:
        row['status'] = status
        if deliverable_state:
            row['deliverables_status'] = deliverable_state
        break
else:
    raise SystemExit(f"entry {entry_id} not found")
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
PY
}

python_expectations() {
  local logfile=$1
  local mapping_json=$2
  python3 - "$logfile" "$mapping_json" <<'PY'
import json
import re
import sys
from pathlib import Path

log_path = sys.argv[1]
mapping = json.loads(sys.argv[2])
lines = Path(log_path).read_text(encoding='utf-8').splitlines()
events = {}
pattern = re.compile(r'^\[monitor\]\s+(\S+)\s+(.*)$')

for line in lines:
    m = pattern.match(line)
    if not m:
        continue
    ident, rest = m.groups()
    rest_lower = rest.lower()
    bucket = events.setdefault(ident, {"nudge": 0, "responded": 0, "manual": 0, "recovered": 0})
    if "attempting nudge" in rest_lower:
        bucket["nudge"] += 1
    if "responded after nudge" in rest_lower:
        bucket["responded"] += 1
    if "requires manual attention" in rest_lower:
        bucket["manual"] += 1
    if "heartbeat recovered" in rest_lower:
        bucket["recovered"] += 1

case_events = {}
for ident, data in events.items():
    case = mapping.get(ident)
    if not case:
        case = ident.split("-", 2)[-1]
    case_events[case] = data

def require(condition, message):
    if not condition:
        raise SystemExit(message)

require(case_events.get("long-sleep", {}).get("manual", 0) == 0,
        "long-sleep should not require manual attention")
require(case_events.get("await-prompt", {}).get("nudge", 0) >= 1,
        "await-prompt should be nudged")
require(case_events.get("await-prompt", {}).get("responded", 0) >= 1,
        "await-prompt should respond after nudge")
require(case_events.get("await-prompt-fail", {}).get("manual", 0) >= 1,
        "await-prompt-fail should require manual attention")
require(case_events.get("await-prompt-fail", {}).get("responded", 0) == 0,
        "await-prompt-fail should not report successful response")
require(case_events.get("stale-log", {}).get("manual", 0) >= 1,
        "stale-log should require manual attention")
require(case_events.get("stale-log", {}).get("nudge", 0) >= 1,
        "stale-log should be nudged")

print("Monitor scenario expectations satisfied.")
PY
}

ensure_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is required for this scenario." >&2
    exit 1
  fi
  if [[ -z "${TMUX:-}" ]]; then
    echo "Run this harness from within a tmux session." >&2
    exit 1
  fi
  WINDOW_ID=$(tmux display-message -p '#{window_id}' 2>/dev/null || true)
  MAIN_PANE=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)
  if [[ -z "$WINDOW_ID" || -z "$MAIN_PANE" ]]; then
    echo "Unable to determine active tmux window/pane." >&2
    exit 1
  fi

  local existing_panes
  existing_panes=$(get_window_option "$WINDOW_ID" @parallelus_subagent_panes)
  if [[ -n "$existing_panes" ]]; then
    rebalance_subagent_column "$WINDOW_ID" "$existing_panes"
    existing_panes=$(get_window_option "$WINDOW_ID" @parallelus_subagent_panes)
    if [[ -n "$existing_panes" ]]; then
      IFS=' ' read -r -a RIGHT_STACK_PANES <<< "$existing_panes"
      RIGHT_STACK_ROOT="${RIGHT_STACK_PANES[0]}"
    else
      RIGHT_STACK_PANES=()
      RIGHT_STACK_ROOT=""
    fi
  fi
}

ensure_tmux

CASE_ORDER=(
  long-sleep
  slow-heartbeat
  await-prompt
  await-prompt-fail
  stale-log
  fast-fail
)

CASE_ENTRY_ID=()
CASE_PANE=()
CASE_SANDBOX=()
CASE_DONE=()
CASE_RESULT=()
CASE_DELIVERABLE=()

timestamp() {
  date -u '+%Y%m%d-%H%M%S'
}

launch_case() {
  local case_name=$1
  local idx=$2
  local id="$(timestamp)-$case_name"
  local sandbox="$SANDBOX_ROOT/$id"
  mkdir -p "$sandbox/deliverables"
  touch "$sandbox/subagent.log"

  local script="$sandbox/run.sh"
  cat >"$script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
LOG="$SANDBOX/subagent.log"
STATUS_FILE="$SANDBOX/.status"
  case "$CASE" in
  long-sleep)
    printf '%s long-sleep start\n' "$(date -u '+%H:%M:%S')" >>"$LOG"
    for i in 1 2; do
      sleep 8
      printf '%s long-sleep heartbeat %d\n' "$(date -u '+%H:%M:%S')" "$i" >>"$LOG"
    done
    sleep 4
    mkdir -p "$SANDBOX/deliverables"
    echo ok-long >"$SANDBOX/deliverables/result.txt"
    printf '{"files":["deliverables/result.txt"]}\n' >"$SANDBOX/deliverables/.manifest"
    touch "$SANDBOX/deliverables/.complete"
    echo success >"$STATUS_FILE"
    ;;
  slow-heartbeat)
    for i in {1..4}; do
      printf '%s heartbeat %d\n' "$(date -u '+%H:%M:%S')" "$i" >>"$LOG"
      sleep 8
    done
    mkdir -p "$SANDBOX/deliverables"
    echo ok-heartbeat >"$SANDBOX/deliverables/result.txt"
    printf '{"files":["deliverables/result.txt"]}\n' >"$SANDBOX/deliverables/.manifest"
    touch "$SANDBOX/deliverables/.complete"
    echo success >"$STATUS_FILE"
    ;;
  await-prompt)
    echo "waiting for prompt" >>"$LOG"
    AWAIT_TIMEOUT=${AWAIT_TIMEOUT:-120}
    if read -r -t "$AWAIT_TIMEOUT" response; then
      if [[ -z "${response:-}" ]]; then
        response="<blank>"
      fi
      printf '%s received nudge: %s\n' "$(date -u '+%H:%M:%S')" "$response" >>"$LOG"
    else
      echo "nudge timed out" >>"$LOG"
      echo failure >"$STATUS_FILE"
      exit 75
    fi
    mkdir -p "$SANDBOX/deliverables"
    echo ok-nudged >"$SANDBOX/deliverables/result.txt"
    printf '{"files":["deliverables/result.txt"]}\n' >"$SANDBOX/deliverables/.manifest"
    touch "$SANDBOX/deliverables/.complete"
    echo success >"$STATUS_FILE"
    ;;
  await-prompt-fail)
    echo "waiting for prompt" >>"$LOG"
    read -r _ || true
    sleep 20
    echo "still blocked" >>"$LOG"
    echo failure >"$STATUS_FILE"
    exit 42
    ;;
  stale-log)
    sleep 5
    echo "progress" >>"$LOG"
    sleep 40
    echo failure >"$STATUS_FILE"
    ;;
  fast-fail)
    echo "fatal error" >>"$LOG"
    echo failure >"$STATUS_FILE"
    exit 1
    ;;
esac
SH
  chmod +x "$script"

  local command="CASE=$case_name SANDBOX=$sandbox bash $script"
  local pane_id
  if (( ${#RIGHT_STACK_PANES[@]} == 0 )); then
    pane_id=$(tmux split-window -h -p 50 -d -t "$MAIN_PANE" -P -F '#{pane_id}' -c "$sandbox" "$command")
    RIGHT_STACK_ROOT="$pane_id"
    RIGHT_STACK_PANES=("$pane_id")
    enable_pane_labels "$WINDOW_ID"
  else
    local last_idx=$(( ${#RIGHT_STACK_PANES[@]} - 1 ))
    local last_pane="${RIGHT_STACK_PANES[$last_idx]}"
    pane_id=$(tmux split-window -v -d -t "$last_pane" -P -F '#{pane_id}' -c "$sandbox" "$command")
    RIGHT_STACK_PANES+=("$pane_id")
  fi
  tmux select-pane -t "$pane_id" -T "$case_name" >/dev/null 2>&1 || true
  tmux select-pane -t "$MAIN_PANE" >/dev/null 2>&1 || true
  local pane_list="${RIGHT_STACK_PANES[*]}"
  set_window_option "$WINDOW_ID" @parallelus_subagent_stack_root "$RIGHT_STACK_ROOT"
  set_window_option "$WINDOW_ID" @parallelus_subagent_panes "$pane_list"
  rebalance_subagent_column "$WINDOW_ID" "$pane_list"
  local window_id="$WINDOW_ID"

  local deliverables_json='None'
  local deliverables_flag=0
  if [[ $case_name == long-sleep || $case_name == slow-heartbeat || $case_name == await-prompt ]]; then
    deliverables_json='[ { "source": "deliverables/result.txt", "target": "deliverables/result.txt", "status": "pending" } ]'
    deliverables_flag=1
  fi

  local entry_json
  entry_json=$(python3 - <<PY
import json
entry = {
    "id": "$id",
    "type": "throwaway",
    "slug": "$case_name",
    "path": "$sandbox",
    "scope_path": "$sandbox/SUBAGENT_SCOPE.md",
    "prompt_path": "$sandbox/SUBAGENT_PROMPT.txt",
    "log_path": "$sandbox/subagent.log",
    "launcher": "tmux-pane",
    "launcher_kind": "tmux-pane",
    "launcher_handle": {"pane_id": "$pane_id", "window_id": "$window_id"},
    "status": "running",
    "launched_at": "$id",
    "window_title": "$case_name"
}
deliverables = $deliverables_json
if deliverables:
    entry["deliverables"] = deliverables
    entry["deliverables_status"] = "pending"
print(json.dumps(entry))
PY
  )
  python_append_entry "$entry_json"

  CASE_ENTRY_ID[$idx]="$id"
  CASE_PANE[$idx]="$pane_id"
  CASE_SANDBOX[$idx]="$sandbox"
  CASE_DONE[$idx]=0
  CASE_RESULT[$idx]=''
  CASE_DELIVERABLE[$idx]=$deliverables_flag
}

for idx in "${!CASE_ORDER[@]}"; do
  launch_case "${CASE_ORDER[$idx]}" "$idx"
done

if [[ $KEEP_SESSION -eq 1 ]]; then
  echo "Subagent panes opened alongside the current pane (main left, subagents right)." >&2
  echo "Use tmux select-pane (e.g., C-b o) to hop between them; panes remain after the harness finishes." >&2
fi

MONITOR_PID=0

(
  cd "$ROOT"
  MONITOR_RECHECK_DELAY=$RECHECK_DELAY MONITOR_NUDGE_DELAY=$NUDGE_DELAY MONITOR_NUDGE_MESSAGE=$NUDGE_MESSAGE \
    "$ROOT/parallelus/engine/bin/agents-monitor-loop.sh" \
    --interval "$INTERVAL" \
    --threshold "$HEARTBEAT_THRESHOLD" \
    --runtime-threshold "$RUNTIME_THRESHOLD" \
    --iterations "$ITERATIONS"
) >"$MONITOR_LOG" 2>&1 &
MONITOR_PID=$!

pending=${#CASE_ORDER[@]}
timeout_hit=0
start_time=$(date +%s)
while (( pending > 0 )); do
  for idx in "${!CASE_ORDER[@]}"; do
    if (( CASE_DONE[$idx] == 1 )); then
      continue
    fi
    sandbox="${CASE_SANDBOX[$idx]}"
    if [[ -f "$sandbox/.status" ]]; then
      CASE_DONE[$idx]=1
      CASE_RESULT[$idx]=$(<"$sandbox/.status")
      if [[ ${CASE_RESULT[$idx]} == success ]]; then
        python_update_status "${CASE_ENTRY_ID[$idx]}" completed pending
      else
        python_update_status "${CASE_ENTRY_ID[$idx]}" failed ""
      fi
      ((pending--))
    fi
  done
  if (( pending > 0 )); then
    sleep 2
    if (( HARNESS_TIMEOUT > 0 )); then
      now=$(date +%s)
      if (( now - start_time >= HARNESS_TIMEOUT )); then
        echo "Harness timeout reached (${HARNESS_TIMEOUT}s); cancelling remaining cases." >&2
        timeout_hit=1
        for idx in "${!CASE_ORDER[@]}"; do
          if (( CASE_DONE[$idx] == 0 )); then
            CASE_DONE[$idx]=1
            CASE_RESULT[$idx]='timeout'
            python_update_status "${CASE_ENTRY_ID[$idx]}" failed ""
          fi
        done
        pending=0
        break
      fi
    fi
  fi
done

if [[ $MONITOR_PID -ne 0 ]]; then
  if (( timeout_hit == 1 )); then
    kill "$MONITOR_PID" >/dev/null 2>&1 || true
  fi
  wait "$MONITOR_PID" 2>/dev/null || true
fi

if (( timeout_hit == 1 )); then
  echo "Scenario aborted after timeout; monitor log saved at $MONITOR_LOG" >&2
  exit 1
fi

mapping_stream=""
for idx in "${!CASE_ORDER[@]}"; do
  id=${CASE_ENTRY_ID[$idx]}
  case_name=${CASE_ORDER[$idx]}
  mapping_stream+="$id\t$case_name\n"
done
mapping_json=$(printf '%b' "$mapping_stream" | python3 <<'PY'
import json
import sys

mapping = {}
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    ident, case = line.split('\t', 1)
    mapping[ident] = case
print(json.dumps(mapping))
PY
)

python_expectations "$MONITOR_LOG" "$mapping_json"

for idx in "${!CASE_ORDER[@]}"; do
  case_name=${CASE_ORDER[$idx]}
  sandbox="${CASE_SANDBOX[$idx]}"
  if [[ ${CASE_DELIVERABLE[$idx]} -eq 1 ]]; then
    [[ -f "$sandbox/deliverables/.complete" ]] || { echo "deliverable missing for $case_name" >&2; exit 1; }
  fi
done

echo "Scenario finished; monitor log saved at $MONITOR_LOG"
