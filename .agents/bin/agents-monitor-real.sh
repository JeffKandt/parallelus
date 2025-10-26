#!/usr/bin/env bash
set -euo pipefail

# Real Codex monitor harness.
# Launches deterministic real-mode scenarios, monitors them with shortened
# thresholds, inspects deliverables/transcripts, and force-cleans sandboxes.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"

REGISTRY="$ROOT/docs/agents/subagent-registry.json"
SUBAGENT_MANAGER="$ROOT/.agents/bin/subagent_manager.sh"
TEMPLATE_SCOPE_DIR="$ROOT/tests/guardrails/real_monitor/scopes"
TEMPLATE_SCRIPT_DIR="$ROOT/tests/guardrails/real_monitor/scripts"

if [[ ${HARNESS_MODE:-} != "real" ]]; then
  echo "agents-monitor-real.sh: set HARNESS_MODE=real to run this harness." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "agents-monitor-real.sh: 'codex' CLI not found; install credentials/config first." >&2
  exit 1
fi

for required_dir in "$TEMPLATE_SCOPE_DIR" "$TEMPLATE_SCRIPT_DIR"; do
  if [[ ! -d "$required_dir" ]]; then
    echo "agents-monitor-real.sh: missing template directory $required_dir" >&2
    exit 1
  fi
done

REAL_INTERVAL=${REAL_INTERVAL:-15}
REAL_THRESHOLD=${REAL_THRESHOLD:-30}
REAL_RUNTIME=${REAL_RUNTIME:-1800}
REAL_RECHECK=${REAL_RECHECK:-5}
REAL_NUDGE_DELAY=${REAL_NUDGE_DELAY:-5}
REAL_NUDGE_MESSAGE=${REAL_NUDGE_MESSAGE:-"Proceed"}
KEEP_SANDBOX=${KEEP_SANDBOX:-0}

SCENARIOS=(
  interactive-success
  slow-progress
  hung-failure
)

ENTRY_IDS=()
ENTRY_SCENARIOS=()
ENTRY_TYPES=()

scenario_requires_deliverable() {
  case "$1" in
    interactive-success) echo 1 ;;
    *) echo 0 ;;
  esac
}

scenario_expected_success() {
  case "$1" in
    interactive-success) echo 1 ;;
    slow-progress|hung-failure) echo 0 ;;
    *) echo 0 ;;
  esac
}

scenario_slug() {
  printf 'real-%s\n' "$1"
}

get_entry_field() {
  local entry_id=$1
  local field=$2
  python3 - "$REGISTRY" "$entry_id" "$field" <<'PY'
import json, sys
registry_path, entry_id, field = sys.argv[1:4]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        value = row
        for part in field.split("."):
            if isinstance(value, dict):
                value = value.get(part)
            else:
                value = None
                break
        if value is None:
            value = ""
        print(value)
        break
else:
    print("")
PY
}

has_running_entries() {
  python3 - "$REGISTRY" "${ENTRY_IDS[@]}" <<'PY'
import json, sys
registry_path = sys.argv[1]
ids = set(sys.argv[2:])
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") in ids and row.get("status") == "running":
        sys.exit(0)
sys.exit(1)
PY
  return $?
}

get_entry_status() {
  local entry_id=$1
  get_entry_field "$entry_id" "status"
}

get_deliverables_status() {
  local entry_id=$1
  get_entry_field "$entry_id" "deliverables_status"
}

require_scenario_ready() {
  local scenario=$1
  local slug
  slug=$(scenario_slug "$scenario")
  python3 - "$REGISTRY" "$slug" <<'PY' || return 1
import json
import sys

path, slug = sys.argv[1:3]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = []

running = []
stale = []
for row in data:
    if row.get("slug") != slug:
        continue
    status = (row.get("status") or "").lower()
    if status == "running":
        running.append(row.get("id") or "")
    else:
        stale.append((row.get("id") or "", status))

if running:
    print(f"running:{','.join(filter(None, running))}")
    sys.exit(2)

if stale:
    print("stale:" + ",".join(f"{id_}:{status}" for id_, status in stale if id_))

PY
  local result=$?
  if (( result == 2 )); then
    echo "agents-monitor-real.sh: scenario '$scenario' already running (see registry output above)." >&2
    return 1
  fi
  return 0
}

record_entry() {
  local entry_id=$1
  local scenario=$2
  local entry_json
  entry_json=$(python3 - "$REGISTRY" "$entry_id" <<'PY'
import json, sys
path, entry_id = sys.argv[1:3]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        print(json.dumps(row))
        break
PY
  )
  local type=""
  if [[ -n "$entry_json" ]]; then
    type=$(python3 -c "import json,sys;print(json.loads(sys.argv[1]).get('type',''))" "$entry_json")
  fi
  ENTRY_IDS+=("$entry_id")
  ENTRY_SCENARIOS+=("$scenario")
  ENTRY_TYPES+=("$type")
}

launch_scenario() {
  local scenario=$1
  if ! require_scenario_ready "$scenario"; then
    exit 1
  fi
  local template_key=${scenario//-/_}
  local scope_template="$TEMPLATE_SCOPE_DIR/${template_key}.md"
  local script_template="$TEMPLATE_SCRIPT_DIR/${template_key}.sh"
  if [[ ! -f "$scope_template" ]]; then
    echo "Missing scope template for $scenario: $scope_template" >&2
    exit 1
  fi
  if [[ ! -f "$script_template" ]]; then
    echo "Missing script template for $scenario: $script_template" >&2
    exit 1
  fi

  local slug="real-${scenario}"
  local -a deliverable_args=()
  if [[ $(scenario_requires_deliverable "$scenario") -eq 1 ]]; then
    deliverable_args+=(--deliverable "deliverables/result.txt")
  fi

  local entry_id
  if (( ${#deliverable_args[@]} )); then
    entry_id=$("$SUBAGENT_MANAGER" launch --type throwaway --slug "$slug" --scope "$scope_template" "${deliverable_args[@]}") || {
      echo "Failed to launch scenario $scenario" >&2
      exit 1
    }
  else
    entry_id=$("$SUBAGENT_MANAGER" launch --type throwaway --slug "$slug" --scope "$scope_template") || {
      echo "Failed to launch scenario $scenario" >&2
      exit 1
    }
  fi

  record_entry "$entry_id" "$scenario"
}

monitor_loop() {
  while true; do
    MONITOR_RECHECK_DELAY=$REAL_RECHECK \
    MONITOR_NUDGE_DELAY=$REAL_NUDGE_DELAY \
    MONITOR_NUDGE_MESSAGE="$REAL_NUDGE_MESSAGE" \
      make monitor_subagents ARGS="--interval $REAL_INTERVAL --threshold $REAL_THRESHOLD --runtime-threshold $REAL_RUNTIME" >/dev/null
    if ! has_running_entries; then
      break
    fi
    echo "Monitor exited while subagents still running; restarting..." >&2
    sleep 2
  done
}

evaluate_scenario() {
  local entry_id=$1
  local scenario=$2
  local sandbox log_path
  sandbox=$(get_entry_field "$entry_id" "path")
  log_path=$(get_entry_field "$entry_id" "log_path")

  local deliverable_ok=1
  if [[ $(scenario_requires_deliverable "$scenario") -eq 1 ]]; then
    if [[ ! -f "$sandbox/deliverables/.complete" || ! -f "$sandbox/deliverables/result.txt" ]]; then
      deliverable_ok=0
    fi
  else
    if [[ -f "$sandbox/deliverables/.complete" || -f "$sandbox/deliverables/result.txt" ]]; then
      deliverable_ok=0
    fi
  fi

  local expected_success
  expected_success=$(scenario_expected_success "$scenario")
  local actual_success=1
  local summary=""

  if [[ $expected_success -eq 1 && $deliverable_ok -eq 1 ]]; then
    summary="[$scenario] deliverables present; marked success."
  elif [[ $expected_success -eq 0 && $deliverable_ok -eq 1 ]]; then
    summary="[$scenario] unexpected deliverable present."
    actual_success=0
  elif [[ $expected_success -eq 1 && $deliverable_ok -eq 0 ]]; then
    summary="[$scenario] expected deliverable missing."
    actual_success=0
  else
    summary="[$scenario] failure scenario behaved as expected."
  fi

  if [[ $actual_success -eq 0 ]]; then
    if [[ -x "$ROOT/.agents/bin/subagent_tail.sh" ]]; then
      echo "---- transcript tail for $scenario ($entry_id) ----" >&2
      "$ROOT/.agents/bin/subagent_tail.sh" --id "$entry_id" --lines 40 >&2 || true
      echo "---- end transcript ----" >&2
    elif [[ -n "$log_path" && -f "$log_path" ]]; then
      echo "---- log tail for $scenario ($entry_id) ----" >&2
      tail -n 20 "$log_path" >&2 || true
      echo "---- end log tail ----" >&2
    fi
  fi

  if [[ $actual_success -eq 1 && $(scenario_requires_deliverable "$scenario") -eq 1 ]]; then
    "$SUBAGENT_MANAGER" harvest --id "$entry_id" >/dev/null || summary="$summary (harvest reported an issue)"
  fi

  printf '%s\n' "$summary"
  if [[ $actual_success -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}

finalize_entries() {
  local idx rc=0
  for idx in "${!ENTRY_IDS[@]}"; do
    local entry_id="${ENTRY_IDS[$idx]}"
    local scenario="${ENTRY_SCENARIOS[$idx]}"
    local entry_type="${ENTRY_TYPES[$idx]}"
    local status
    status=$(get_entry_status "$entry_id")
    if [[ "$status" == "running" || -z "$status" ]]; then
      echo "[reconcile] $entry_id still marked '$status'. Leaving for manual follow-up." >&2
      rc=1
      continue
    fi

    local expect_deliverable
    expect_deliverable=$(scenario_requires_deliverable "$scenario")
    if [[ "$expect_deliverable" -eq 1 ]]; then
      local deliverable_status
      deliverable_status=$(get_deliverables_status "$entry_id")
      if [[ "${deliverable_status,,}" != "harvested" ]]; then
        if ! "$SUBAGENT_MANAGER" harvest --id "$entry_id" >/dev/null; then
          echo "[reconcile] Harvest failed for $entry_id; leaving sandbox untouched." >&2
          rc=1
          continue
        fi
      fi
    fi

    if [[ "$entry_type" == "throwaway" ]]; then
      if ! "$SUBAGENT_MANAGER" verify --id "$entry_id" >/dev/null; then
        echo "[reconcile] Verify failed for $entry_id; leaving sandbox untouched." >&2
        rc=1
        continue
      fi
    fi

    if (( KEEP_SANDBOX == 1 )); then
      echo "[reconcile] KEEP_SANDBOX=1; skipping cleanup for $entry_id."
    else
      if ! "$SUBAGENT_MANAGER" cleanup --id "$entry_id" >/dev/null; then
        echo "[reconcile] Cleanup failed for $entry_id; manual cleanup required." >&2
        rc=1
      fi
    fi
  done
  return "$rc"
}

main() {
  local failures=0
  for scenario in "${SCENARIOS[@]}"; do
    launch_scenario "$scenario"
  done

  monitor_loop

  local idx reconcile_failures=0
  for idx in "${!ENTRY_IDS[@]}"; do
    local entry_id="${ENTRY_IDS[$idx]}"
    local scenario="${ENTRY_SCENARIOS[$idx]}"
    if ! evaluate_scenario "$entry_id" "$scenario"; then
      failures=$((failures + 1))
    fi
  done

  if ! finalize_entries; then
    reconcile_failures=1
  fi

  if (( failures > 0 )); then
    echo "Real monitor harness: $failures scenario(s) failed. Inspect logs above." >&2
  fi
  if (( reconcile_failures > 0 )); then
    echo "Real monitor harness: cleanup/verification issues detected; see messages above." >&2
  fi
  if (( failures > 0 || reconcile_failures > 0 )); then
    return 1
  fi
  return 0
}

main "$@"
