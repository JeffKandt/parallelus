#!/usr/bin/env bash
set -euo pipefail

# Real Codex monitor harness.
# Launches deterministic real-mode scenarios, monitors them with shortened
# thresholds, inspects deliverables/transcripts, and force-cleans sandboxes.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_ROOT="$ROOT"
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

usage() {
  cat <<'USAGE'
Usage: agents-monitor-real.sh --scenario NAME [--scenario NAME ...] [options]

Run deterministic real-mode monitor scenarios. Each invocation should focus on
one scenario so the operator can capture post-mortem evidence before cleanup.

Options:
  --scenario NAME    Run the specified scenario (interactive-success,
                     slow-progress, hung-failure). Repeatable.
  --all              Run every available scenario (legacy batch mode).
  --reconcile        After the run, harvest/verify deliverables but leave
                     sandboxes in place for manual inspection.
  --cleanup          Harvest/verify AND clean sandboxes (legacy behaviour).
  --help             Show this message.

Environment overrides:
  REAL_INTERVAL, REAL_THRESHOLD, REAL_RUNTIME, REAL_RECHECK,
  REAL_NUDGE_DELAY, REAL_NUDGE_MESSAGE, KEEP_SANDBOX
USAGE
}

REAL_INTERVAL=${REAL_INTERVAL:-15}
REAL_THRESHOLD=${REAL_THRESHOLD:-30}
REAL_RUNTIME=${REAL_RUNTIME:-1800}
REAL_RECHECK=${REAL_RECHECK:-5}
REAL_NUDGE_DELAY=${REAL_NUDGE_DELAY:-5}
REAL_NUDGE_MESSAGE=${REAL_NUDGE_MESSAGE:-}
KEEP_SANDBOX=${KEEP_SANDBOX:-1}

SCENARIOS=()
REQUESTED_SCENARIOS=()
RUN_ALL=0
AUTO_RECONCILE=0
AUTO_CLEANUP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      [[ $# -lt 2 ]] && { echo "agents-monitor-real.sh: --scenario requires a value" >&2; exit 1; }
      REQUESTED_SCENARIOS+=("$2")
      shift 2
      ;;
    --all)
      RUN_ALL=1
      shift
      ;;
    --reconcile)
      AUTO_RECONCILE=1
      shift
      ;;
    --cleanup)
      AUTO_RECONCILE=1
      AUTO_CLEANUP=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "agents-monitor-real.sh: unknown option $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if (( RUN_ALL )); then
  SCENARIOS=(interactive-success slow-progress hung-failure)
else
  SCENARIOS=("${REQUESTED_SCENARIOS[@]}")
fi

if ((${#SCENARIOS[@]} == 0)); then
  echo "agents-monitor-real.sh: specify at least one --scenario or pass --all." >&2
  usage >&2
  exit 1
fi

validate_scenario_name() {
  case "$1" in
    interactive-success|slow-progress|hung-failure) return 0 ;;
    *)
      echo "agents-monitor-real.sh: unsupported scenario '$1'" >&2
      return 1 ;;
  esac
}

for scenario in "${SCENARIOS[@]}"; do
  validate_scenario_name "$scenario" || exit 1
done

if (( AUTO_CLEANUP == 1 )); then
  KEEP_SANDBOX=0
fi

ENTRY_IDS=()
ENTRY_SCENARIOS=()
ENTRY_TYPES=()
ENTRY_SUMMARIES=()
SCENARIO_REPORTS=()
SESSION_TRANSCRIPT_TOOL="$ROOT/.agents/bin/subagent_session_to_transcript.py"

cleanup_on_signal() {
  local status=$?
  echo "agents-monitor-real.sh: caught signal, leaving subagents running:" >&2
  if ((${#ENTRY_IDS[@]} == 0)); then
    echo "  (no subagents launched yet)" >&2
  else
    local i
    for i in "${!ENTRY_IDS[@]}"; do
      printf '  - %s (%s)\n' "${ENTRY_IDS[$i]}" "${ENTRY_SCENARIOS[$i]}" >&2
    done
  fi
  exit 130
}

trap cleanup_on_signal INT TERM

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
  ENTRY_SUMMARIES+=("")
}

entry_index() {
  local needle=$1
  local i
  for i in "${!ENTRY_IDS[@]}"; do
    if [[ "${ENTRY_IDS[$i]}" == "$needle" ]]; then
      echo "$i"
      return 0
    fi
  done
  echo "-1"
  return 1
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
  local monitor_args
  while true; do
    monitor_args="--interval $REAL_INTERVAL --threshold $REAL_THRESHOLD --runtime-threshold $REAL_RUNTIME"
    if ((${#ENTRY_IDS[@]} > 0)); then
      local entry_id
      for entry_id in "${ENTRY_IDS[@]}"; do
        monitor_args+=" --id $entry_id"
      done
    fi
    local monitor_output monitor_status
    set +e
    monitor_output=$(
      MONITOR_RECHECK_DELAY=$REAL_RECHECK \
      MONITOR_NUDGE_DELAY=$REAL_NUDGE_DELAY \
      MONITOR_NUDGE_MESSAGE="$REAL_NUDGE_MESSAGE" \
        make monitor_subagents ARGS="$monitor_args" 2>&1
    )
    monitor_status=$?
    set -e
    [[ -n "$monitor_output" ]] && echo "$monitor_output"
    if (( monitor_status != 0 )); then
      echo "Monitor reported outstanding subagents (exit $monitor_status); stopping loop for manual intervention." >&2
      break
    fi
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
  local sandbox log_path session_log
  sandbox=$(get_entry_field "$entry_id" "path")
  log_path=$(get_entry_field "$entry_id" "log_path")
  session_log="$sandbox/subagent.session.jsonl"

  local deliverable_present=0
  if [[ $(scenario_requires_deliverable "$scenario") -eq 1 ]]; then
    if [[ -f "$sandbox/deliverables/.complete" && -f "$sandbox/deliverables/result.txt" ]]; then
      deliverable_present=1
    fi
  else
    if [[ -f "$sandbox/deliverables/.complete" || -f "$sandbox/deliverables/result.txt" ]]; then
      deliverable_present=1
    fi
  fi

  local expected_success
  expected_success=$(scenario_expected_success "$scenario")
  local actual_success=1
  local summary=""
  local next_steps=""

  if [[ $expected_success -eq 1 && $deliverable_present -eq 1 ]]; then
    summary="[$scenario] deliverables present; marked success."
  elif [[ $expected_success -eq 0 && $deliverable_present -eq 1 ]]; then
    summary="[$scenario] unexpected deliverable present."
    actual_success=0
  elif [[ $expected_success -eq 1 && $deliverable_present -eq 0 ]]; then
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

  local requires_deliverable
  requires_deliverable=$(scenario_requires_deliverable "$scenario")

  if (( AUTO_RECONCILE == 1 )); then
    if [[ $actual_success -eq 1 && $requires_deliverable -eq 1 ]]; then
      if ! "$SUBAGENT_MANAGER" harvest --id "$entry_id" >/dev/null; then
        summary="$summary (harvest reported an issue)"
        actual_success=0
      else
        summary="$summary Harvested deliverables."
      fi
    fi
  else
    if [[ $requires_deliverable -eq 1 ]]; then
      next_steps="Deliverable available at $sandbox/deliverables/ (run 'subagent_manager.sh harvest --id $entry_id' after review)."
    fi
  fi

  if [[ "$scenario" == "interactive-success" && -f "$session_log" ]]; then
    if ! python3 - "$session_log" <<'PY'
import json, sys
path = sys.argv[1]
ready_phrase = "[interactive] Ready for reviewer confirmation (type EXACT ACK to continue)."
ready_found = False
with open(path, "r", encoding="utf-8") as fh:
    for raw in fh:
        raw = raw.strip()
        if not raw:
            continue
        try:
            record = json.loads(raw)
        except Exception:
            continue
        payload = record.get("payload") or {}
        msg = payload.get("msg") or {}
        text = msg.get("text") or ""
        if not text and isinstance(msg.get("content"), list):
            text = "".join(part.get("text", "") for part in msg["content"] if isinstance(part, dict))
        if ready_phrase in text:
            ready_found = True
            break
if ready_found:
    sys.exit(0)
sys.exit(1)
PY
    then
      summary="$summary Ready message missing from transcript."
      actual_success=0
    fi
    if python3 - "$session_log" <<'PY'
import json, sys
path = sys.argv[1]
for line in open(path, "r", encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        record = json.loads(line)
    except Exception:
        continue
    payload = record.get("payload") or {}
    msg = payload.get("msg") or {}
    command = msg.get("command") or ""
    if not command:
        continue
    normalised = command.strip().lower()
    # Flag if the subagent itself typed ACK (or similar) at the prompt.
    if normalised in {"ack", "\"ack\"", "'ack'"}:
        sys.exit(1)
    if normalised.startswith("printf") and "ack" in normalised:
        sys.exit(1)
    if "printf" not in normalised and "ack" in normalised and "send_keys" not in normalised:
        sys.exit(1)
sys.exit(0)
PY
    then
      :
    else
      summary="$summary Interactive scenario auto-acknowledged itself (expected parent agent to send ACK)."
      actual_success=0
    fi
    if ! python3 - "$session_log" <<'PY'
import json, sys
path = sys.argv[1]
ack_token = "ACK"
ack_seen = False
with open(path, "r", encoding="utf-8") as fh:
    for raw in fh:
        raw = raw.strip()
        if not raw:
            continue
        try:
            record = json.loads(raw)
        except Exception:
            continue
        payload = record.get("payload") or {}
        msg = payload.get("msg") or {}
        text = msg.get("text") or ""
        if not text and isinstance(msg.get("content"), list):
            text = "".join(part.get("text", "") for part in msg["content"] if isinstance(part, dict))
        if text.strip() == ack_token:
            ack_seen = True
            break
if ack_seen:
    sys.exit(0)
sys.exit(1)
PY
    then
      summary="$summary ACK response from main agent not detected in transcript."
      actual_success=0
    fi
  fi

  if (( AUTO_RECONCILE == 0 )); then
    next_steps="${next_steps:-Sandbox preserved for post-mortem review.}"
  fi

  if [[ -n "$next_steps" ]]; then
    summary="$summary $next_steps"
  fi

  printf '%s\n' "$summary"
  SCENARIO_REPORTS+=("$summary")
  local entry_idx
  entry_idx=$(entry_index "$entry_id") || true
  if [[ "$entry_idx" != "-1" ]]; then
    ENTRY_SUMMARIES[$entry_idx]="$summary"
  fi
  if [[ $actual_success -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}

archive_entry() {
  local entry_id=$1
  local scenario=$2
  local summary=$3
  local sandbox
  sandbox=$(get_entry_field "$entry_id" "path")
  if [[ -z "$sandbox" || ! -d "$sandbox" ]]; then
    echo "[archive] Sandbox missing for $entry_id; skipping artifact capture." >&2
    return 1
  fi

  local run_dir="$ROOT/docs/guardrails/runs/${entry_id}"
  mkdir -p "$run_dir"

  if [[ -f "$sandbox/subagent.session.jsonl" ]]; then
    cp "$sandbox/subagent.session.jsonl" "$run_dir/session.jsonl"
    if [[ -x "$SESSION_TRANSCRIPT_TOOL" ]]; then
      if ! "$SESSION_TRANSCRIPT_TOOL" "$sandbox/subagent.session.jsonl" --output "$run_dir/transcript.md"; then
        echo "[archive] Failed to generate transcript for $entry_id." >&2
      fi
    fi
  else
    echo "[archive] session.jsonl missing for $entry_id." >&2
  fi

  if [[ -f "$sandbox/subagent.log" ]]; then
    cp "$sandbox/subagent.log" "$run_dir/subagent.log"
  fi

  if [[ -d "$sandbox/deliverables" ]]; then
    mkdir -p "$run_dir/deliverables"
    if ! cp -R "$sandbox/deliverables/." "$run_dir/deliverables/"; then
      echo "[archive] Failed to copy deliverables for $entry_id." >&2
      return 1
    fi
  fi

  cat >"$run_dir/summary.md" <<EOF
# Subagent Run Summary
- Scenario: $scenario
- Entry ID: $entry_id
- Archived At (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')

${summary}
EOF
  return 0
}

finalize_entries() {
  if (( AUTO_RECONCILE == 0 )); then
    echo "[reconcile] Automatic harvest/cleanup disabled; leaving sandboxes for manual review." >&2
    return 0
  fi
  local idx rc=0
  local current_head
  current_head=$(git rev-parse HEAD)
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

    if (( AUTO_CLEANUP == 0 )); then
      echo "[reconcile] Cleanup disabled; leaving $entry_id sandbox in place."
      continue
    fi

    local review_targets
    review_targets=$(python3 - "$REGISTRY" "$entry_id" <<'PY'
import json, sys
registry_path, entry_id = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        for deliverable in row.get("deliverables") or []:
            target = deliverable.get("target_path") or deliverable.get("target") or ""
            if target.startswith("docs/reviews/"):
                print(target)
        break
PY
    ) || true
    if [[ -n "$review_targets" ]]; then
      local review_file=""
      while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue
        if [[ -f "$candidate" ]]; then
          review_file="$candidate"
          break
        elif [[ -f "$REPO_ROOT/$candidate" ]]; then
          review_file="$REPO_ROOT/$candidate"
          break
        fi
      done <<< "$review_targets"
      if [[ -z "$review_file" ]]; then
        echo "[reconcile] Review report for $entry_id not found at $review_targets." >&2
        rc=1
        continue
      fi
      local review_commit
      review_commit=$(grep -i '^Reviewed-Commit:' "$review_file" | head -n1 | sed -E 's/Reviewed-Commit:[[:space:]]*//I')
      review_commit=${review_commit// /}
      if [[ -z "$review_commit" ]]; then
        echo "[reconcile] Review report $review_file is missing Reviewed-Commit." >&2
        rc=1
        continue
      fi
      if [[ "$review_commit" != "$current_head" ]]; then
        echo "[reconcile] Review $review_file covers $review_commit but branch HEAD is $current_head. Re-run the review." >&2
        rc=1
        continue
      fi
    fi

    if [[ "$entry_type" == "throwaway" ]]; then
      if ! "$SUBAGENT_MANAGER" verify --id "$entry_id" >/dev/null; then
        echo "[reconcile] Verify failed for $entry_id; leaving sandbox untouched." >&2
        rc=1
        continue
      fi
    fi

    local entry_idx
    entry_idx=$(entry_index "$entry_id") || true
    local summary_text=""
    if [[ "$entry_idx" != "-1" ]]; then
      summary_text=${ENTRY_SUMMARIES[$entry_idx]}
    fi
    if ! archive_entry "$entry_id" "$scenario" "$summary_text"; then
      rc=1
      continue
    fi

    if ! "$SUBAGENT_MANAGER" cleanup --id "$entry_id" >/dev/null; then
      echo "[reconcile] Cleanup failed for $entry_id; manual cleanup required." >&2
      rc=1
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
  if ((${#SCENARIO_REPORTS[@]} > 0)); then
    echo ""
    echo "Scenario summaries:"
    local report
    for report in "${SCENARIO_REPORTS[@]}"; do
      echo " - $report"
    done
  fi
  trap - INT TERM
  if (( failures > 0 || reconcile_failures > 0 )); then
    return 1
  fi
  return 0
}

main "$@"
