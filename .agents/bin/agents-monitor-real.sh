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
fi

REAL_INTERVAL=${REAL_INTERVAL:-15}
REAL_THRESHOLD=${REAL_THRESHOLD:-30}
REAL_RUNTIME=${REAL_RUNTIME:-1800}
REAL_RECHECK=${REAL_RECHECK:-5}
REAL_NUDGE_DELAY=${REAL_NUDGE_DELAY:-5}
REAL_NUDGE_MESSAGE=${REAL_NUDGE_MESSAGE:-"Proceed"}

SCENARIOS=(
  interactive-success
  slow-progress
  hung-failure
)

declare -A EXPECT_DELIVERABLE=(
  [interactive-success]=1
)

declare -A EXPECT_SUCCESS=(
  [interactive-success]=1
  [slow-progress]=0
  [hung-failure]=0
)

declare -a ENTRY_IDS=()
declare -A ENTRY_SCENARIO=()

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

launch_scenario() {
  local scenario=$1
  local scope_template="$TEMPLATE_SCOPE_DIR/${scenario}.md"
  local script_template="$TEMPLATE_SCRIPT_DIR/${scenario}.sh"
  if [[ ! -f "$scope_template" ]]; then
    echo "Missing scope template for $scenario: $scope_template" >&2
    exit 1
  fi
  if [[ ! -f "$script_template" ]]; then
    echo "Missing script template for $scenario: $script_template" >&2
    exit 1
  fi

  local slug="real-${scenario}"
  local deliverable_args=()
  if [[ ${EXPECT_DELIVERABLE[$scenario]:-0} -eq 1 ]]; then
    deliverable_args+=(--deliverable "deliverables/result.txt")
  fi

  local entry_id
  entry_id=$("$SUBAGENT_MANAGER" launch --type throwaway --slug "$slug" --scope "$scope_template" "${deliverable_args[@]}") || {
    echo "Failed to launch scenario $scenario" >&2
    exit 1
  }

  ENTRY_IDS+=("$entry_id")
  ENTRY_SCENARIO["$entry_id"]="$scenario"
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
  local scenario=${ENTRY_SCENARIO[$entry_id]}
  local sandbox log_path
  sandbox=$(get_entry_field "$entry_id" "path")
  log_path=$(get_entry_field "$entry_id" "log_path")

  local deliverable_ok=1
  if [[ ${EXPECT_DELIVERABLE[$scenario]:-0} -eq 1 ]]; then
    if [[ ! -f "$sandbox/deliverables/.complete" || ! -f "$sandbox/deliverables/result.txt" ]]; then
      deliverable_ok=0
    fi
  else
    if [[ -f "$sandbox/deliverables/.complete" || -f "$sandbox/deliverables/result.txt" ]]; then
      deliverable_ok=0
    fi
  fi

  local expected_success=${EXPECT_SUCCESS[$scenario]:-0}
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
    if [[ -n "$log_path" && -f "$log_path" ]]; then
      echo "---- log tail for $scenario ($entry_id) ----" >&2
      tail -n 20 "$log_path" >&2 || true
      echo "---- end log tail ----" >&2
    fi
  fi

  if [[ $actual_success -eq 1 && ${EXPECT_DELIVERABLE[$scenario]:-0} -eq 1 ]]; then
    "$SUBAGENT_MANAGER" harvest --id "$entry_id" >/dev/null || summary="$summary (harvest reported an issue)"
  fi

  printf '%s\n' "$summary"
  if [[ $actual_success -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}

main() {
  local failures=0
  for scenario in "${SCENARIOS[@]}"; do
    launch_scenario "$scenario"
  done

  monitor_loop

  for entry_id in "${ENTRY_IDS[@]}"; do
    if ! evaluate_scenario "$entry_id"; then
      failures=$((failures + 1))
    fi
  done

  if (( failures > 0 )); then
    echo "Real monitor harness: $failures scenario(s) failed. Inspect logs above." >&2
    return 1
  fi
  return 0
}

main "$@"
