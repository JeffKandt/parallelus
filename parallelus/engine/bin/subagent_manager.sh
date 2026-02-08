#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=./agents-doc-paths.sh
. "$ROOT/parallelus/engine/bin/agents-doc-paths.sh"

RAW_TMUX_BIN=$(command -v tmux || true)
TMUX_WRAPPER="$ROOT/parallelus/engine/bin/tmux-safe"
if [[ -x "$TMUX_WRAPPER" && -n "$RAW_TMUX_BIN" ]]; then
  TMUX_BIN="$TMUX_WRAPPER"
else
  TMUX_BIN="$RAW_TMUX_BIN"
fi

if [[ -z "${TMUX:-}" && -n "${PARALLELUS_TMUX_SOCKET:-}" && -n "$TMUX_BIN" ]]; then
    tmux_env=$("$TMUX_BIN" display-message -p '#{socket_path},#{session_id},#{pane_id}' 2>/dev/null || true)
    if [[ -n "${tmux_env:-}" ]]; then
      export TMUX="$tmux_env"
    fi
fi

REGISTRY_FILE=${SUBAGENT_REGISTRY_FILE:-parallelus/manuals/subagent-registry.json}
SCOPE_TEMPLATE="parallelus/manuals/templates/subagent_scope_template.md"
SANDBOX_ROOT="$ROOT/.parallelus/subagents/sandboxes"
WORKTREE_ROOT="$ROOT/.parallelus/subagents/worktrees"
LAUNCH_HELPER="${SUBAGENT_LAUNCH_HELPER:-$ROOT/parallelus/engine/bin/launch_subagent.sh}"
DEPLOY_HELPER="$ROOT/parallelus/engine/bin/deploy_agents_process.sh"
VERIFY_HELPER="$ROOT/parallelus/engine/bin/verify_process_run.py"
RETRO_LOCAL_AUDITOR="$ROOT/parallelus/engine/bin/retro_audit_local.py"
SESSION_HELPER="$ROOT/parallelus/engine/bin/get_current_session_id.sh"
RESUME_HELPER="$ROOT/parallelus/engine/bin/resume_in_tmux.sh"
EXEC_RESUME_HELPER="$ROOT/parallelus/engine/bin/subagent_exec_resume.sh"
MONITOR_HELPER="$ROOT/parallelus/engine/bin/agents-monitor-loop.sh"
SUBAGENT_LANGS=${SUBAGENT_LANGS:-python}
ROLE_PROMPTS_DIR="$ROOT/parallelus/engine/prompts/agent_roles"

usage() {
  cat <<'USAGE'
Usage: subagent_manager.sh <command> [options]
Commands:
  launch   Create a sandbox/worktree and launch a subagent session
  review-preflight
           Serialize retrospective preflight (marker -> failures -> local audit)
           and optionally launch the senior review subagent
  review-preflight-run
           Run review-preflight and, when launch falls back to
           awaiting_manual_launch, execute the generated sandbox runner,
           then harvest+cleanup automatically
  status   List registry entries (optionally filter by --id)
  resume   Resume an exec-mode subagent session (follow-up prompt)
  verify   Validate a completed subagent sandbox/worktree
  abort    Abort a running subagent without deleting its sandbox/worktree
  harvest  Copy recorded deliverables from a sandbox/worktree into the repo
  cleanup  Remove sandbox/worktree and update registry status
USAGE
}

ensure_registry() {
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    mkdir -p "$(dirname "$REGISTRY_FILE")"
    printf '[]\n' >"$REGISTRY_FILE"
  fi
}

build_lang_flags() {
  local flags=()
  local lang
  read -r -a SUBAGENT_LANG_ARRAY <<< "$SUBAGENT_LANGS"
  for lang in "${SUBAGENT_LANG_ARRAY[@]}"; do
    [[ -z "$lang" ]] && continue
    flags+=("--lang" "$lang")
  done
  for item in "${flags[@]}"; do
    printf '%s\n' "$item"
  done
}

tmux_available() {
  if [[ -n "${TMUX:-}" ]]; then
    return 0
  fi
  if [[ -n "$TMUX_BIN" ]] && "$TMUX_BIN" list-sessions >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

is_falsey() {
  local raw=${1:-}
  local lowered
  lowered=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
  case "$lowered" in
    0|false|no|off)
      return 0
      ;;
  esac
  return 1
}

is_enabled() {
  local raw=${1:-}
  [[ -n "$raw" ]] && ! is_falsey "$raw"
}

retro_required() {
  local raw="${AGENTS_REQUIRE_RETRO:-}"
  if [[ -z "$raw" && -f "$ROOT/parallelus/engine/agentrc" ]]; then
    raw=$(awk -F= '
      /^[[:space:]]*AGENTS_REQUIRE_RETRO[[:space:]]*=/ {
        v=$2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        gsub(/^"|"$/, "", v)
        print v
        found=1
        exit
      }
      /^[[:space:]]*REQUIRE_AGENT_CI_AUDITS[[:space:]]*=/ {
        if (legacy == "") {
          legacy=$2
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", legacy)
          gsub(/^"|"$/, "", legacy)
        }
      }
      END {
        if (!found && legacy != "") {
          print legacy
        }
      }
    ' "$ROOT/parallelus/engine/agentrc" || true)
  fi
  if [[ -z "$raw" ]]; then
    raw="1"
  fi
  if is_falsey "$raw"; then
    return 1
  fi
  return 0
}

current_branch() {
  git rev-parse --abbrev-ref HEAD
}

ensure_not_main() {
  local branch
  if [[ "${SUBAGENT_MANAGER_ALLOW_MAIN:-0}" == "1" ]]; then
    return 0
  fi
  branch=$(current_branch)
  if [[ "$branch" == "main" ]]; then
    echo "subagent_manager: refuse to run on 'main'. Checkout a feature branch first." >&2
    exit 1
  fi
}

ensure_clean_worktree() {
  local status_lines
  status_lines="$(git status --porcelain)"
  if [[ -z "$status_lines" ]]; then
    return 0
  fi

  local allowlist_only=1
  local path
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="${line:3}"
    case "$path" in
      docs/parallelus|docs/parallelus/|docs/parallelus/self-improvement|docs/parallelus/self-improvement/*|parallelus/manuals/subagent-registry.json)
        ;;
      *)
        allowlist_only=0
        break
        ;;
    esac
  done <<<"$status_lines"

  if (( allowlist_only == 1 )); then
    return 0
  fi

  echo "subagent_manager: refuse to launch senior-review while the worktree has unstaged changes." >&2
  echo "  Commit, stash, or revert local edits before rerunning." >&2
  exit 1
}

is_doc_only_path() {
  local path=$1
  case "$path" in
    docs/guardrails/runs/*|\
    docs/parallelus/reviews/*|\
    docs/PLAN.md|\
    docs/PROGRESS.md|\
    docs/branches/*|\
    parallelus/manuals/*|\
    docs/parallelus/self-improvement/*)
      return 0 ;;
  esac
  return 1
}

ensure_senior_review_needed() {
  local branch_slug reviewed_commit head_commit latest_review diff_files non_doc_change=0
  branch_slug=${1//\//-}
  head_commit=$2

  latest_review=$(
    python3 - "$ROOT" "$branch_slug" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
branch_slug = sys.argv[2]
candidates = []
for directory in [root / "docs" / "parallelus" / "reviews", root / "docs" / "reviews"]:
    if not directory.exists():
        continue
    for path in directory.glob(f"{branch_slug}-*.md"):
        try:
            candidates.append((path.stat().st_mtime, path))
        except FileNotFoundError:
            continue
if candidates:
    candidates.sort(reverse=True)
    print(candidates[0][1])
PY
  )
  if [[ -z "$latest_review" ]]; then
    return 0
  fi

  reviewed_commit=$(awk -F': ' '$1=="Reviewed-Commit"{print $2; exit}' "$latest_review")
  if [[ -z "$reviewed_commit" ]]; then
    return 0
  fi
  if ! git rev-parse --verify --quiet "$reviewed_commit" >/dev/null; then
    return 0
  fi

  if [[ "$reviewed_commit" == "$head_commit" ]]; then
    echo "subagent_manager: latest review $(basename "$latest_review") already covers commit $head_commit." >&2
    echo "  Re-run the senior architect review only after landing new code changes." >&2
    exit 1
  fi

  if ! diff_files=$(git diff --name-only "$reviewed_commit" "$head_commit" 2>/dev/null); then
    return 0
  fi
  if [[ -z "$diff_files" ]]; then
    echo "subagent_manager: no file changes since reviewed commit $reviewed_commit; reuse the existing review." >&2
    exit 1
  fi

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if ! is_doc_only_path "$path"; then
      non_doc_change=1
      break
    fi
  done <<<"$diff_files"

  if (( ! non_doc_change )); then
    echo "subagent_manager: only doc-only paths changed since the last review (see $(basename "$latest_review"))." >&2
    echo "  Doc-only updates do not require a new senior architect review; skip the launch or add code changes first." >&2
    exit 1
  fi
}

ensure_slug_clean() {
  local slug=$1
  local auto_clean_stale=${2:-0}
  ensure_registry
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    return
  fi

  if [[ "$auto_clean_stale" == "1" ]]; then
    local stale_entries entry_id entry_status entry_path cleaned_count
    cleaned_count=0
    stale_entries=$(python3 - "$REGISTRY_FILE" "$slug" <<'PY'
import json
import sys

registry_path, slug = sys.argv[1:3]
try:
    with open(registry_path, "r", encoding="utf-8") as fh:
        entries = json.load(fh)
except FileNotFoundError:
    sys.exit(0)

for row in entries:
    if row.get("slug") != slug:
        continue
    status = (row.get("status") or "").lower()
    if status != "awaiting_manual_launch":
        continue
    entry_id = row.get("id", "")
    path = row.get("path", "")
    print(f"{entry_id}\t{status}\t{path}")
PY
)
    while IFS=$'\t' read -r entry_id entry_status entry_path; do
      [[ -z "$entry_id" ]] && continue
      if subagent_process_active "$entry_path"; then
        echo "subagent_manager: keeping $entry_id ($entry_status); sandbox process appears active." >&2
        continue
      fi
      echo "subagent_manager: auto-cleaning stale $entry_status entry $entry_id for slug '$slug'." >&2
      cmd_cleanup --id "$entry_id" --force >/dev/null 2>&1 || true
      cleaned_count=$((cleaned_count + 1))
    done <<<"$stale_entries"
    if (( cleaned_count > 0 )); then
      echo "subagent_manager: auto-cleaned $cleaned_count stale awaiting_manual_launch entr$( [[ $cleaned_count -eq 1 ]] && echo "y" || echo "ies" )." >&2
    fi
  fi

  python3 - "$REGISTRY_FILE" "$slug" <<'PY'
import json, sys
registry_path, slug = sys.argv[1:3]
try:
    with open(registry_path, "r", encoding="utf-8") as fh:
        entries = json.load(fh)
except FileNotFoundError:
    sys.exit(0)

blocked = []
for row in entries:
    if row.get("slug") == slug:
        status = (row.get("status") or "").lower()
        if status != "cleaned":
            blocked.append((row.get("id"), status or "unknown"))

if blocked:
    print(
        "subagent_manager: previous runs for slug '{}' are still active; clean them up before launching again.".format(
            slug
        ),
        file=sys.stderr,
    )
    for entry_id, status in blocked:
        print(f"  - {entry_id} (status: {status})", file=sys.stderr)
    print(
        "Hint: run 'parallelus/engine/bin/subagent_manager.sh cleanup --id <id>' once the subagent has finished.",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

subagent_process_active() {
  local sandbox_path=${1:-}
  if [[ -z "$sandbox_path" ]]; then
    return 1
  fi

  ps -Ao command= 2>/dev/null | awk -v path="$sandbox_path" '
    index($0, path) > 0 && ($0 ~ /codex|\.parallelus_run_subagent|script -qa/) { found=1; exit 0 }
    END { exit found ? 0 : 1 }
  '
}

ensure_no_tmux_pane_for_slug() {
  local slug=$1
  if ! tmux_available; then
    return
  fi
  local flagged=0
  while IFS='|' read -r pane_id pane_title; do
    [[ -z "$pane_id" ]] && continue
    [[ -z "$pane_title" ]] && continue
    if [[ "$pane_title" == *"-${slug}" ]]; then
      echo "subagent_manager: tmux pane $pane_id ('$pane_title') from a previous '$slug' run is still open." >&2
      echo "  Close the pane (e.g. tmux kill-pane -t $pane_id) or clean up the subagent before launching again." >&2
      flagged=1
    fi
  done < <("$TMUX_BIN" list-panes -a -F '#{pane_id}|#{pane_title}' 2>/dev/null || true)
  if (( flagged )); then
    exit 1
  fi
}

ensure_audit_ready_for_review() {
  local branch="$1"
  local head_commit="$2"
  local marker_path
  marker_path="$(parallelus_marker_read_path "$ROOT" "${branch//\//-}")"
  if [[ ! -f "$marker_path" ]]; then
    marker_path="$(parallelus_marker_write_path "$ROOT" "${branch//\//-}")"
  fi
  if [[ ! -f "$marker_path" ]]; then
    echo "subagent_manager: run make turn_end to record a marker before the senior review." >&2
    return 1
  fi
  local audit_paths
  audit_paths=$(
    python3 - "$marker_path" "$head_commit" <<'PY'
import json
import sys
from pathlib import Path

marker_path = Path(sys.argv[1])
head_commit = sys.argv[2]
try:
    marker = json.loads(marker_path.read_text())
except Exception as exc:
    print(f"subagent_manager: unable to parse {marker_path}: {exc}", file=sys.stderr)
    sys.exit(2)

marker_ts = marker.get("timestamp")
if not marker_ts:
    print(f"subagent_manager: marker {marker_path} missing timestamp", file=sys.stderr)
    sys.exit(3)
marker_head = marker.get("head")
if not marker_head:
    print(f"subagent_manager: marker {marker_path} missing head", file=sys.stderr)
    sys.exit(4)
if marker_head != head_commit:
    print(
        "subagent_manager: marker head does not match current HEAD for senior review launch "
        f"(marker: {marker_head}, current: {head_commit}). "
        "Run make turn_end and rerun the CI auditor for the current commit before launching senior review.",
        file=sys.stderr,
    )
    sys.exit(5)

branch_slug = marker_path.stem
root = marker_path.parent.parent
report_path = root / "reports" / f"{branch_slug}--{marker_ts}.json"
failures_path = root / "failures" / f"{branch_slug}--{marker_ts}.json"
print(report_path)
print(failures_path)
print(marker_ts)
PY
  ) || return 1
  local report_path failures_path marker_ts
  report_path=$(printf '%s\n' "$audit_paths" | sed -n '1p')
  failures_path=$(printf '%s\n' "$audit_paths" | sed -n '2p')
  marker_ts=$(printf '%s\n' "$audit_paths" | sed -n '3p')
  if [[ ! -f "$report_path" ]]; then
    echo "subagent_manager: missing audit report $report_path; run the CI auditor before the senior review." >&2
    return 1
  fi
  if [[ ! -f "$failures_path" ]]; then
    echo "subagent_manager: missing failures summary $failures_path; run make collect_failures before the senior review." >&2
    return 1
  fi
  python3 - "$report_path" "$branch" "$marker_ts" <<'PY'
import json
import sys

report_path, expected_branch, marker_ts = sys.argv[1:4]
try:
    data = json.loads(open(report_path, "r", encoding="utf-8").read())
except Exception as exc:
    print(f"subagent_manager: unable to parse {report_path}: {exc}", file=sys.stderr)
    sys.exit(6)
branch = data.get("branch")
report_ts = data.get("marker_timestamp")
if branch != expected_branch or report_ts != marker_ts:
    print(
        "subagent_manager: audit report does not match current branch/marker "
        f"(report branch={branch!r}, report marker={report_ts!r}, expected branch={expected_branch!r}, expected marker={marker_ts!r}). "
        "Rerun the CI auditor for the latest marker before launching senior review.",
        file=sys.stderr,
    )
    sys.exit(7)
PY
}

append_registry() {
  local entry_json=$1
  python3 - "$REGISTRY_FILE" "$entry_json" <<'PY'
import json, sys
registry_path, entry_json = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
data.append(json.loads(entry_json))
with open(registry_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
PY
}

update_registry() {
  local entry_id=$1
  local update_snippet=$2
  python3 - "$REGISTRY_FILE" "$entry_id" "$update_snippet" <<'PY'
import json, sys
registry_path, entry_id, update_snippet = sys.argv[1:4]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        exec(update_snippet, {}, {"row": row})
        break
else:
    sys.exit(f"subagent_manager: unknown id {entry_id}")
with open(registry_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
PY
}

get_registry_entry() {
  local entry_id=$1
  python3 - "$REGISTRY_FILE" "$entry_id" <<'PY'
import json, sys
registry_path, entry_id = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        import json as _json
        print(_json.dumps(row))
        break
else:
    sys.exit(f"subagent_manager: unknown id {entry_id}")
PY
}

print_status() {
  local filter_id=${1:-}
python3 - "$REGISTRY_FILE" "$filter_id" <<'PY'
import glob
import hashlib
import json
import os
import sys
import time
from collections import deque
from datetime import datetime, timezone

registry_path, filter_id = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    entries = json.load(fh)
if filter_id:
    entries = [row for row in entries if row.get("id") == filter_id]
if not entries:
    print("No matching subagents.")
    sys.exit(0)

def width_for(header, values, minimum, maximum):
    lengths = [len(header)]
    lengths.extend(len(v) for v in values)
    width = max(lengths)
    width = max(width, minimum)
    if maximum is not None:
        width = min(width, maximum)
    return width

def fingerprint(path: str) -> str:
    if os.path.islink(path):
        return "symlink:" + os.readlink(path)
    if os.path.isdir(path):
        digest = hashlib.sha256()
        for root, dirs, files in os.walk(path):
            dirs.sort()
            files.sort()
            rel_root = os.path.relpath(root, path)
            digest.update(f"D:{rel_root}\n".encode("utf-8", "ignore"))
            for name in files:
                file_path = os.path.join(root, name)
                rel_path = os.path.relpath(file_path, path)
                digest.update(f"F:{rel_path}\n".encode("utf-8", "ignore"))
                with open(file_path, "rb") as fh:
                    for chunk in iter(lambda: fh.read(65536), b""):
                        digest.update(chunk)
        return "dir:" + digest.hexdigest()
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return "file:" + digest.hexdigest()

now = time.time()
id_values = [row.get("id", "-") or "-" for row in entries]
slug_values = [row.get("slug", "-") or "-" for row in entries]
type_values = [row.get("type", "-") or "-" for row in entries]
status_values = [row.get("status", "-") or "-" for row in entries]
deliverable_values = []
registry_modified = False
for row in entries:
    deliverables = row.get("deliverables") or []
    sandbox_path = row.get("path") or ""
    current_meta = (row.get("deliverables_status") or "").strip()
    meta_lower = current_meta.lower()
    if sandbox_path and deliverables:
        for item in deliverables:
            status = (item.get("status") or "pending").lower()
            source_glob = item.get("source_glob")
            if status in {"waiting", "pending"} and source_glob:
                glob_pattern = os.path.join(sandbox_path, source_glob)
                baseline = set(item.get("baseline") or [])
                baseline_fingerprints = item.get("baseline_fingerprints") or {}
                ready = []
                for path in sorted(glob.glob(glob_pattern)):
                    rel = os.path.relpath(path, sandbox_path)
                    if rel not in baseline:
                        ready.append(rel)
                        continue
                    previous = baseline_fingerprints.get(rel)
                    if previous and previous != fingerprint(path):
                        ready.append(rel)
                if ready:
                    if status != "ready" or item.get("ready_files") != ready:
                        item["status"] = "ready"
                        item["ready_files"] = ready
                        registry_modified = True
    statuses = [(item.get("status") or "pending").lower() for item in deliverables]
    desired_meta = ""
    if deliverables:
        all_harvested = statuses and all(state == "harvested" for state in statuses)
        all_complete = statuses and all(state in {"ready", "harvested"} for state in statuses)
        any_progress = any(state in {"ready", "harvested"} for state in statuses)
        if all_harvested:
            desired_meta = "harvested"
        elif all_complete:
            desired_meta = "ready"
        elif any_progress:
            desired_meta = "partial"
        else:
            desired_meta = "waiting" if meta_lower == "waiting" else "pending"
    if desired_meta:
        if desired_meta != meta_lower:
            row["deliverables_status"] = desired_meta
            registry_modified = True
            current_meta = desired_meta
        else:
            current_meta = current_meta or desired_meta
    else:
        if current_meta:
            row["deliverables_status"] = ""
            registry_modified = True
            current_meta = ""
    if current_meta:
        label = current_meta
    elif deliverables:
        pending = any((item.get("status") or "pending").lower() != "harvested" for item in deliverables)
        label = "pending" if pending else "harvested"
    else:
        label = "-"
    deliverable_values.append(label)
handle_values = []

id_width = width_for("ID", id_values, 24, 40)
type_width = width_for("Type", type_values, 10, 14)
slug_width = width_for("Slug", slug_values, 25, 40)
status_width = width_for("Status", status_values, 16, 20)
deliverables_width = width_for("Deliverables", deliverable_values, 12, 18)
runtime_width = width_for("Run Time", [], 9, 9)
log_width = width_for("Log Age", [], 9, 9)
handle_width = width_for("Handle", [], 14, 24)
log_header = "Last Log (UTC)"
log_header_width = len(log_header)


def parse_iso8601(value: str):
    if not value:
        return None
    try:
        if value.endswith("Z"):
            return datetime.fromisoformat(value[:-1]).replace(tzinfo=timezone.utc)
        return datetime.fromisoformat(value)
    except Exception:
        return None


def last_meaningful_event(session_path: str, limit: int = 400):
    if not session_path or not os.path.exists(session_path):
        return None
    try:
        with open(session_path, "r", encoding="utf-8") as fh:
            tail = deque(fh, maxlen=limit)
    except Exception:
        return None
    for raw in reversed(tail):
        raw = raw.strip()
        if not raw:
            continue
        try:
            record = json.loads(raw)
        except Exception:
            continue
        kind = record.get("kind")
        payload = record.get("payload") or {}
        variant = record.get("variant") or payload.get("variant")
        if kind == "app_event" and variant == "CommitTick":
            continue
        ts = record.get("ts")
        ts_dt = parse_iso8601(ts) if ts else None
        if ts_dt:
            return ts_dt
    return None

row_fmt = (
    f"{{:<{id_width}}} "
    f"{{:<{type_width}}} "
    f"{{:<{slug_width}}} "
    f"{{:<{status_width}}} "
    f"{{:<{deliverables_width}}} "
    f"{{:<{runtime_width}}} "
    f"{{:<{log_width}}} "
    f"{{:<{handle_width}}} "
    f"{{:<{log_header_width}}}"
)

header = row_fmt.format(
    "ID",
    "Type",
    "Slug",
    "Status",
    "Deliverables",
    "Run Time",
    "Log Age",
    "Handle",
    log_header,
)
print(header)
print("=" * len(header))
for row in entries:
    log_path = row.get('log_path')
    sandbox_path = row.get('path') or ''
    session_path = os.path.join(sandbox_path, "subagent.session.jsonl") if sandbox_path else ""
    log_age = '-'
    log_summary = '-'
    runtime = '-'
    handle = '-'
    launched_at = row.get('launched_at')
    if launched_at:
        try:
            launched = datetime.strptime(launched_at, "%Y%m%d-%H%M%S").replace(tzinfo=timezone.utc)
            delta = int(max(now - launched.timestamp(), 0))
            minutes, seconds = divmod(delta, 60)
            runtime = f"{minutes:02d}:{seconds:02d}"
        except Exception:
            runtime = '-'
    effective_path = ""
    effective_timestamp = None
    source_label = ""
    session_event = last_meaningful_event(session_path)
    if session_event is not None:
        effective_timestamp = session_event.timestamp()
        effective_path = session_path
        source_label = "[session]"
    else:
        progress_path = row.get("progress_path") or (os.path.join(sandbox_path, "subagent.progress.md") if sandbox_path else "")
        last_message_path = os.path.join(sandbox_path, "subagent.last_message.txt") if sandbox_path else ""
        exec_events_path = os.path.join(sandbox_path, "subagent.exec_events.jsonl") if sandbox_path else ""

        def is_nonempty(path: str) -> bool:
            try:
                return bool(path) and os.path.exists(path) and os.path.getsize(path) > 0
            except Exception:
                return False

        # Prioritise human-readable checkpoints over raw command noise so the
        # monitor loop alerts when the subagent stops narrating progress.
        if is_nonempty(progress_path):
            effective_timestamp = os.path.getmtime(progress_path)
            effective_path = progress_path
            source_label = "[checkpoint]"
        elif is_nonempty(last_message_path):
            effective_timestamp = os.path.getmtime(last_message_path)
            effective_path = last_message_path
            source_label = "[last_message]"
        elif exec_events_path and os.path.exists(exec_events_path):
            effective_timestamp = os.path.getmtime(exec_events_path)
            effective_path = exec_events_path
            source_label = "[exec]"
        elif log_path and os.path.exists(log_path):
            effective_timestamp = os.path.getmtime(log_path)
            effective_path = log_path
            source_label = "[raw]"
        elif log_path:
            effective_path = log_path
    if effective_timestamp is not None:
        delta = int(now - effective_timestamp)
        minutes, seconds = divmod(max(delta, 0), 60)
        log_age = f"{minutes:02d}:{seconds:02d}"
        if source_label == "[session]" and session_event is not None:
            log_summary = session_event.strftime('%Y-%m-%d %H:%M:%S')
        else:
            log_summary = datetime.utcfromtimestamp(effective_timestamp).strftime('%Y-%m-%d %H:%M:%S')
        if source_label:
            log_summary = f"{log_summary} {source_label}"
    launcher_kind = row.get('launcher_kind', '') or ''
    launcher_handle = row.get('launcher_handle') or {}
    title = row.get('window_title') or launcher_handle.get('title') or ''
    if launcher_kind.startswith('tmux'):
        pane_id = launcher_handle.get('pane_id', '')
        window_id = launcher_handle.get('window_id', '')
        bits = [b for b in (pane_id, window_id) if b]
        handle = "/".join(bits) if bits else '-'
    elif launcher_kind == 'iterm-window':
        handle = launcher_handle.get('window_id') or launcher_handle.get('session_id') or '-'
    elif launcher_kind == 'terminal-window':
        handle = launcher_handle.get('tab_id') or launcher_handle.get('window_id') or '-'
    elif launcher_kind:
        handle = launcher_kind
    if title and title != row.get('id'):
        if handle and handle != '-':
            handle = f"{handle}:{title}"
        else:
            handle = title
    deliverable_label = row.get('deliverables_status') or '-'
    if deliverable_label == '-' and (row.get('deliverables') or []):
        pending = any((item.get('status') or 'pending').lower() != 'harvested' for item in row['deliverables'])
        deliverable_label = 'pending' if pending else 'harvested'
    print(row_fmt.format(
        row.get('id','-'),
        row.get('type','-'),
        row.get('slug','-'),
        row.get('status','-'),
        deliverable_label,
        runtime,
        log_age,
        handle,
        log_summary,
    ))

if registry_modified:
    with open(registry_path, "w", encoding="utf-8") as fh:
        json.dump(entries, fh, indent=2)
PY
}

create_scope_file() {
  local dest=$1
  local source=${2:-}
  if [[ -n "$source" ]]; then
    cp "$source" "$dest"
  elif [[ -f "$SCOPE_TEMPLATE" ]]; then
    cp "$SCOPE_TEMPLATE" "$dest"
  else
    cat <<'EOF' >"$dest"
# Subagent Scope

## Context
- Describe the parent feature or purpose.

## Objectives
- [ ] Item 1

## Acceptance Criteria
- Criteria for completion.

## Notes
- Additional guidance.
EOF
  fi
}

print_role_body() {
  local file=$1
  python3 - <<'PY' "$file"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
body = []
delimiter_count = 0
for line in lines:
    if line.strip() == '---':
        delimiter_count += 1
        continue
    if delimiter_count >= 2 or delimiter_count == 0:
        body.append(line)

print("\n".join(body))
PY
}

parse_role_config() {
  local file=$1
  python3 - <<'PY' "$file"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

if not text.startswith('---'):
    print(json.dumps({}))
    sys.exit(0)

parts = text.split('---', 2)
if len(parts) < 3:
    raise SystemExit("subagent_manager: malformed front matter in {}".format(path))

front_matter = parts[1]

import yaml

data = yaml.safe_load(front_matter)
if data is None:
    data = {}

allowed_keys = {
    "model",
    "sandbox_mode",
    "approval_policy",
    "session_mode",
    "additional_constraints",
    "allowed_writes",
    "profile",
    "config_overrides",
    "use_exec",
    "exec_json",
}

unexpected = sorted(set(data.keys()) - allowed_keys)
if unexpected:
    raise SystemExit("subagent_manager: unexpected keys in {}: {}".format(path, ", ".join(unexpected)))

for key in allowed_keys:
    if key in {"allowed_writes", "config_overrides"}:
        data.setdefault(key, {} if key == "config_overrides" else [])
    else:
        data.setdefault(key, None)

print(json.dumps(data))
PY
}

role_config_to_env() {
  local json=$1
  python3 - "$json" <<'PY'
import json
import sys
import shlex

data = json.loads(sys.argv[1]) if sys.argv[1] else {}

mapping = {
    "model": "SUBAGENT_CODEX_MODEL",
    "sandbox_mode": "SUBAGENT_CODEX_SANDBOX_MODE",
    "approval_policy": "SUBAGENT_CODEX_APPROVAL_POLICY",
    "session_mode": "SUBAGENT_CODEX_SESSION_MODE",
    "additional_constraints": "SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS",
    "allowed_writes": "SUBAGENT_CODEX_ALLOWED_WRITES",
    "profile": "SUBAGENT_CODEX_PROFILE",
    "config_overrides": "SUBAGENT_CODEX_CONFIG_OVERRIDES",
    "use_exec": "SUBAGENT_CODEX_USE_EXEC",
    "exec_json": "SUBAGENT_CODEX_EXEC_JSON",
}

for key, env in mapping.items():
    val = data.get(key)
    if val is None or (isinstance(val, str) and val.strip().lower() in {"", "default"}):
        print(f"unset {env} || true")
        continue

    if key == "allowed_writes":
        if isinstance(val, list) and not val:
            print(f"unset {env} || true")
            continue
        rendered = json.dumps(val, separators=(",", ":"))
    elif key == "config_overrides":
        if isinstance(val, dict) and not val:
            print(f"unset {env} || true")
            continue
        rendered = json.dumps(val, separators=(",", ":"))
    else:
        if isinstance(val, bool):
            rendered = "true" if val else "false"
        elif isinstance(val, (int, float)):
            rendered = str(val)
        elif isinstance(val, (list, dict)):
            rendered = json.dumps(val, separators=(",", ":"))
        else:
            rendered = str(val)

    print(f"export {env}={shlex.quote(rendered)}")
PY
}

create_prompt_file() {
  local dest=$1
  local sandbox=$2
  local scope=$3
  local type=$4
  local slug=$5
  local profile=${6:-}
  local role_prompt=${7:-}
  local parent_branch=${8:-}
  local progress_path=${9:-"$sandbox/subagent.progress.md"}
  local expected_commit=${10:-}
  local role_text=""
  local role_config=""
  local profile_display="default (danger-full-access)"
  local effective_role="$role_prompt"
  local role_read_only="false"

  if [[ -n "$role_prompt" ]]; then
    local role_file="$ROLE_PROMPTS_DIR/$role_prompt"
    if [[ ! -f "$role_file" && "$role_prompt" != *.md ]]; then
      if [[ -f "$ROLE_PROMPTS_DIR/${role_prompt}.md" ]]; then
        effective_role="${role_prompt}.md"
        role_file="$ROLE_PROMPTS_DIR/$effective_role"
      fi
    fi
    if [[ -f "$role_file" ]]; then
      role_config=$(parse_role_config "$role_file")
      role_text=$(print_role_body "$role_file")
      while IFS= read -r line; do
        eval "$line"
      done < <(role_config_to_env "$role_config")
      role_read_only=$(python3 - <<'PY' "$role_config"
import json, sys
cfg = json.loads(sys.argv[1]) if sys.argv[1] else {}
allowed = cfg.get("allowed_writes")
if allowed in (None, [], "", {}):
    print("true")
else:
    print("false")
PY
)
    else
      echo "subagent_manager: role prompt '$role_prompt' not found under $ROLE_PROMPTS_DIR" >&2
    fi
  else
    effective_role=""
  fi

  if [[ -z "$profile" && -n "${SUBAGENT_CODEX_PROFILE:-}" ]]; then
    profile="$SUBAGENT_CODEX_PROFILE"
  fi

  if [[ -n "$profile" ]]; then
    profile_display="$profile"
  fi

  local role_name="${effective_role##*/}"
  local branch_slug="${parent_branch//\//-}"
  if [[ -z "$branch_slug" ]]; then
    branch_slug="<branch>"
  fi
  if [[ -z "$parent_branch" ]]; then
    parent_branch="<branch>"
  fi
  if [[ -z "$expected_commit" ]]; then
    expected_commit="<commit>"
  fi

  local instructions
  if [[ "$role_name" == "continuous_improvement_auditor" || "$role_name" == "continuous_improvement_auditor.md" ]]; then
    read -r -d '' instructions <<EOF || true
1. Read AGENTS.md and parallelus/engine/prompts/agent_roles/continuous_improvement_auditor.md to confirm guardrails.
2. Pin context before auditing: ensure branch is '${parent_branch}' and HEAD is '${expected_commit}'. If either differs, run 'git checkout --quiet ${parent_branch}' and 'git reset --quiet --hard ${expected_commit}'.
3. Review docs/parallelus/self-improvement/markers/${branch_slug}.json (or migrated fallback marker path) to capture the marker timestamp and referenced plan/progress files for ${parent_branch}.
4. Gather evidence without modifying tracked files: inspect git status, git diff, notebooks, and recent command output that reflect the current state of ${parent_branch}.
5. Review the failures summary at docs/parallelus/self-improvement/failures/<branch>--<marker>.json when present and include mitigations for each failed tool call.
6. Emit a JSON object matching the auditor schema (branch, marker_timestamp, summary, issues[], follow_ups[]). Reference concrete evidence for every issue; if no issues exist, return an empty issues array.
7. Stay read-only—do not run make bootstrap or alter tracked files. If command output is noisy or stalls, prioritize marker + failures + notebook evidence and finish promptly.
EOF
  elif [[ "$role_read_only" == "true" ]]; then
    read -r -d '' instructions <<EOF || true
1. Read AGENTS.md and the role prompt to confirm constraints.
2. Pin context before review: ensure branch is '${parent_branch}' and HEAD is '${expected_commit}'. If either differs, run 'git checkout --quiet ${parent_branch}' and 'git reset --quiet --hard ${expected_commit}'.
3. Stay read-only: do not run make bootstrap or edit code/notebooks; your deliverable lives under docs/parallelus/reviews/.
4. Run 'make read_bootstrap' to capture context, then review the branch state (diffs, plan/progress notebooks, logs) for ${parent_branch}.
5. Draft the review in docs/parallelus/reviews/ using the provided template; cite concrete evidence for each finding.
6. Ensure the final review metadata explicitly targets this context: Reviewed-Branch=${parent_branch}, Reviewed-Commit=${expected_commit}.
7. When the write-up is complete, leave the Codex pane open and wait for the main agent to harvest the review—no cleanup inside the sandbox is required.
EOF
	  else
	    read -r -d '' instructions <<EOF || true
	1. Read AGENTS.md and all referenced docs.
	2. Review the scope file, then run 'make bootstrap slug=${slug}' to create the
	   feature branch.
	3. Convert the scope into plan/progress notebooks and follow all guardrails.
	4. Keep the session open until the entire checklist is complete and 'git status'
	   is clean.
	5. Immediately after 'make read_bootstrap', **do not pause**—begin reviewing
	   the required docs right away and proceed with the checklist without drafting a
	   status message or waiting for confirmation.
	6. Before pausing, audit the branch plan checklist and mark every completed
	   task so reviewers see the finished state.
	7. Follow the scope's instructions for merging and cleanup before finishing.
	8. Leave a detailed summary in the progress notebook before exiting.
	9. Maintain a lightweight checkpoint log at '${progress_path}' (also available as
	   \$SUBAGENT_PROGRESS_PATH). After each meaningful work unit, append 1–3 short
	   bullets: what you did, why, and what's next. Keep it brief, human-readable,
	   and free of secrets. This file is used for mid-flight monitoring.
	
		   Example (recommended):
			     printf -- "- %s\n" "$(date -u +%H:%MZ) <what> — <why> — <next>" >> "\$SUBAGENT_PROGRESS_PATH"
			10. You already have approval to run commands. After any status update, plan
			   outline, or summary, immediately continue with the next checklist item
			   without waiting for confirmation.
	11. If you ever feel blocked waiting for a "proceed" or approval, assume the
	    answer is "Continue" and move to the next action without prompting the main
	    agent.
---

Keep working even after 'make read_bootstrap', 'make bootstrap', and the initial
scope review. Do not pause to summarize or seek confirmation—continue directly
to the next checklist item.
Avoid standalone status reports after bootstrap; only document progress in the
notebooks/checkpoints the checklist calls for.
---
EOF
  fi

  local overrides_section=""
  local overrides_list=()
  if [[ -n "${SUBAGENT_CODEX_MODEL:-}" ]]; then
    overrides_list+=("Model: ${SUBAGENT_CODEX_MODEL}")
  fi
  if [[ -n "${SUBAGENT_CODEX_SANDBOX_MODE:-}" ]]; then
    overrides_list+=("Sandbox: ${SUBAGENT_CODEX_SANDBOX_MODE}")
  fi
  if [[ -n "${SUBAGENT_CODEX_APPROVAL_POLICY:-}" ]]; then
    overrides_list+=("Approval policy: ${SUBAGENT_CODEX_APPROVAL_POLICY}")
  fi
  if [[ -n "${SUBAGENT_CODEX_SESSION_MODE:-}" ]]; then
    overrides_list+=("Session mode: ${SUBAGENT_CODEX_SESSION_MODE}")
  fi
  if [[ -n "${SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS:-}" ]]; then
    overrides_list+=("Additional constraints: ${SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS}")
  fi
  if [[ -n "${SUBAGENT_CODEX_ALLOWED_WRITES:-}" ]]; then
    overrides_list+=("Allowed writes: ${SUBAGENT_CODEX_ALLOWED_WRITES}")
  fi
  if [[ -n "${SUBAGENT_CODEX_CONFIG_OVERRIDES:-}" ]]; then
    overrides_list+=("Config overrides: ${SUBAGENT_CODEX_CONFIG_OVERRIDES}")
  fi

  if (( ${#overrides_list[@]} )); then
    overrides_section=$'Role overrides:\n'
    for item in "${overrides_list[@]}"; do
      overrides_section+=" - ${item}\n"
    done
    overrides_section+=$'\n'
  fi

	  cat <<EOF >"$dest"
	You are operating inside sandbox: $sandbox
	Scope file: $scope
	Sandbox type: $type
	Codex profile: $profile_display
	Checkpoint log: $progress_path
	$overrides_section

$instructions
EOF

  if [[ -n "$role_text" ]]; then
    {
      echo
      echo "# Role-specific guidance"
      echo "$role_text"
    } >>"$dest"
  fi

  if [[ "$type" == "worktree" ]]; then
    cat <<'EOF' >>"$dest"

Worktree note: do not merge into the primary branch. Leave the worktree ready
for review so the main agent can decide on follow-up actions.
EOF
  fi
}

ensure_tmux_ready() {
  local launcher=$1
  # Auto launcher can safely fall back to manual launch instructions.
  if [[ "$launcher" == "manual" || "$launcher" == "auto" ]]; then
    return 0
  fi
  if tmux_available; then
    return 0
  fi
  if [[ -z "$TMUX_BIN" ]]; then
    echo "subagent_manager: tmux not installed (tmux binary not found)." >&2
    echo "  Install tmux (e.g. brew install tmux) or use --launcher manual." >&2
    exit 1
  fi

  echo "subagent_manager: tmux session not detected; unable to launch subagent automatically." >&2
  echo "  Please close the current Codex window. When you're ready, run the command below to let me take over inside tmux." >&2

  local session_id=""
  if [[ -x "$SESSION_HELPER" ]]; then
    if session_id=$("$SESSION_HELPER"); then
      session_id=$(printf '%s' "$session_id" | head -n1 | tr -d '\r')
      if [[ -n "$session_id" ]]; then
        echo "  Current Codex session id: $session_id" >&2
      fi
    else
      echo "  Unable to determine current Codex session id (helper failed)." >&2
    fi
  else
    echo "  Helper $SESSION_HELPER not found or not executable." >&2
  fi

  local tmux_cmd="tmux"
  if [[ -n "$TMUX_BIN" ]]; then
    tmux_cmd="$TMUX_BIN"
  fi

  if [[ -x "$RESUME_HELPER" ]]; then
    if [[ -n "$session_id" ]]; then
      echo "  Command: $RESUME_HELPER $session_id" >&2
    else
      echo "  Command: $RESUME_HELPER" >&2
    fi
  else
    if [[ -n "$session_id" ]]; then
      echo "  Command: $tmux_cmd new-session -s parallelus -c '$ROOT' 'codex resume $session_id'" >&2
    else
      echo "  Command: $tmux_cmd new-session -s parallelus -c '$ROOT' 'codex resume <SESSION_ID>'" >&2
    fi
  fi

  echo "  Once tmux is running, just tell me and I'll relaunch the subagent for you." >&2
  exit 1
}

run_launch() {
  local launcher=$1
  local sandbox=$2
  local prompt=$3
  local type=$4
  local log_path=$5
  local entry_id=$6
  local launch_json=""
  if [[ ! -x "$LAUNCH_HELPER" ]]; then
    echo "launch helper $LAUNCH_HELPER not found; run manually:" >&2
    echo "cd '$sandbox' && codex --cd '$sandbox' \"$(cat "$prompt")\"" >&2
    return 1
  fi
  launch_json=$("$LAUNCH_HELPER" --launcher "$launcher" --path "$sandbox" --prompt "$prompt" --log "$log_path" --type "$type" --title "$entry_id" 2>/dev/null) || true
  if [[ -n "$launch_json" ]]; then
    python3 - "$REGISTRY_FILE" "$entry_id" "$launch_json" <<'PY'
import json, sys
registry_path, entry_id, payload_json = sys.argv[1:4]
payload = json.loads(payload_json)
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        row["launcher_kind"] = payload.get("launcher", "")
        row["window_title"] = payload.get("title", "")
        row["launcher_handle"] = payload
        break
else:
    sys.exit(f"subagent_manager: unknown id {entry_id}")
with open(registry_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
PY
    return 0
  fi
  return 1
}

cmd_review_preflight() {
  local launcher auditor_mode skip_launch auto_clean_stale
  launcher="auto"
  auditor_mode="local"
  skip_launch=0
  auto_clean_stale=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --launcher)
        launcher=$2; shift 2 ;;
      --auditor-mode)
        auditor_mode=$2; shift 2 ;;
      --no-launch)
        skip_launch=1; shift ;;
      --auto-clean-stale)
        auto_clean_stale=1; shift ;;
      --help)
        cat <<'USAGE'
Usage: subagent_manager.sh review-preflight [--launcher MODE] [--auditor-mode local] [--no-launch] [--auto-clean-stale]

Runs a serialized retrospective preflight:
  1) parallelus/engine/bin/retro-marker
  2) parallelus/engine/bin/collect_failures.py
  3) parallelus/engine/bin/retro_audit_local.py
  4) parallelus/engine/bin/verify-retrospective

By default it then launches the senior architect review subagent.
Use --no-launch to stop after preflight artifact generation.
Use --auto-clean-stale to clean stale awaiting_manual_launch entries for slug
senior-review when no sandbox process appears active.
USAGE
        return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done

  if [[ "$auditor_mode" != "local" ]]; then
    echo "subagent_manager review-preflight: unsupported auditor mode '$auditor_mode' (supported: local)" >&2
    return 1
  fi
  if [[ ! -x "$RETRO_LOCAL_AUDITOR" ]]; then
    echo "subagent_manager review-preflight: missing local auditor helper $RETRO_LOCAL_AUDITOR" >&2
    return 1
  fi

  ensure_not_main
  local branch head
  branch=$(git rev-parse --abbrev-ref HEAD)
  head=$(git rev-parse HEAD)

  if retro_required; then
    echo "review-preflight: recording marker for $branch@$head" >&2
    "$ROOT/parallelus/engine/bin/retro-marker"

    echo "review-preflight: collecting failures (must run after marker; do not parallelize)" >&2
    "$ROOT/parallelus/engine/bin/collect_failures.py"

    echo "review-preflight: generating marker-matched retrospective report (local commit-aware mode)" >&2
    "$RETRO_LOCAL_AUDITOR"

    echo "review-preflight: verifying retrospective linkage" >&2
    "$ROOT/parallelus/engine/bin/verify-retrospective"
  else
    echo "review-preflight: AGENTS_REQUIRE_RETRO=0; skipping retrospective preflight pipeline." >&2
  fi

  if (( skip_launch == 1 )); then
    echo "review-preflight: complete (launch skipped)" >&2
    return 0
  fi

  if (( auto_clean_stale == 1 )); then
    SUBAGENT_AUTOCLEAN_STALE=1 cmd_launch --type throwaway --slug senior-review --role senior_architect --launcher "$launcher"
  else
    cmd_launch --type throwaway --slug senior-review --role senior_architect --launcher "$launcher"
  fi
}

cmd_review_preflight_run() {
  local preflight_output entry_id entry_status entry_path runner_path
  preflight_output=$(cmd_review_preflight "$@")
  if [[ -n "$preflight_output" ]]; then
    printf '%s\n' "$preflight_output"
  fi

  entry_id=$(printf '%s\n' "$preflight_output" | tail -n1 | tr -d '\r' | xargs || true)
  if [[ -z "$entry_id" ]]; then
    echo "review-preflight-run: no launch id returned (likely --no-launch); nothing else to run." >&2
    return 0
  fi

  local entry_meta
  entry_meta=$(python3 - "$REGISTRY_FILE" "$entry_id" <<'PY'
import json
import sys

registry_path, entry_id = sys.argv[1:3]
with open(registry_path, "r", encoding="utf-8") as fh:
    rows = json.load(fh)

for row in rows:
    if row.get("id") == entry_id:
        print(row.get("status", ""))
        print(row.get("path", ""))
        break
else:
    raise SystemExit(f"review-preflight-run: unknown registry id {entry_id}")
PY
  ) || return 1

  entry_status=$(printf '%s\n' "$entry_meta" | sed -n '1p')
  entry_path=$(printf '%s\n' "$entry_meta" | sed -n '2p')
  if [[ "$entry_status" != "awaiting_manual_launch" ]]; then
    echo "review-preflight-run: entry $entry_id status is '$entry_status'; skipping manual fallback wrapper." >&2
    return 0
  fi

  runner_path="$entry_path/.parallelus_run_subagent.sh"
  if [[ ! -x "$runner_path" ]]; then
    echo "review-preflight-run: manual launcher missing or not executable: $runner_path" >&2
    return 1
  fi

  echo "review-preflight-run: running manual launcher for $entry_id" >&2
  "$runner_path"

  cmd_harvest --id "$entry_id"
  cmd_cleanup --id "$entry_id"
}

cmd_launch() {
  local type slug launcher scope_override codex_profile role_prompt
  local -a deliverables_specs=()
  type=""
  slug=""
  launcher="auto"
  scope_override=""
  codex_profile=""
  role_prompt=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --type)
        type=$2; shift 2 ;;
      --slug)
        slug=$2; shift 2 ;;
      --scope)
        scope_override=$2; shift 2 ;;
      --launcher)
        launcher=$2; shift 2 ;;
      --profile)
        codex_profile=$2; shift 2 ;;
      --role)
        role_prompt=$2; shift 2 ;;
      --deliverable)
        deliverables_specs+=("$2"); shift 2 ;;
      --help)
        cat <<'USAGE'
Usage: subagent_manager.sh launch --type {throwaway|worktree} --slug <branch-slug> [--scope FILE] [--launcher MODE] [--profile CODEX_PROFILE] [--role ROLE_PROMPT] [--deliverable SRC[:DEST]]...

Environment:
  PARALLELUS_CODEX_USE_TUI=1  Opt in to the interactive Codex TUI (default is `codex exec`).
                              Use the TUI only when you need interactive, in-session exploration.
USAGE
        return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done

  if [[ -z "$type" || -z "$slug" ]]; then
    echo "subagent_manager launch: --type and --slug are required" >&2
    return 1
  fi
  if [[ "$type" != "throwaway" && "$type" != "worktree" ]]; then
    echo "subagent_manager launch: unsupported type '$type'" >&2
    return 1
  fi

  ensure_not_main
  ensure_registry
  ensure_slug_clean "$slug" "${SUBAGENT_AUTOCLEAN_STALE:-0}"
  ensure_tmux_ready "$launcher"
  ensure_no_tmux_pane_for_slug "$slug"

  local parent_branch
  parent_branch=$(current_branch)

  local normalized_role="$role_prompt"
  if [[ -n "$role_prompt" && "$role_prompt" != *.md && -f "$ROLE_PROMPTS_DIR/${role_prompt}.md" ]]; then
    normalized_role="${role_prompt}.md"
  fi

	  local timestamp entry_id sandbox scope_path prompt_path log_path progress_path
  local current_branch current_commit
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  current_commit=$(git rev-parse HEAD)
  timestamp=$(date -u +%Y%m%d-%H%M%S)
  entry_id="${timestamp}-${slug}"

  if [[ "$normalized_role" == "senior_architect.md" || "$slug" == "senior-review" ]]; then
    ensure_audit_ready_for_review "$current_branch" "$current_commit"
    ensure_clean_worktree
    ensure_senior_review_needed "$current_branch" "$current_commit"
  fi

  if [[ "$type" == "throwaway" ]]; then
    mkdir -p "$SANDBOX_ROOT"
    sandbox=$(mktemp -d "$SANDBOX_ROOT/${slug}-XXXXXX")
    git clone --no-hardlinks --local "$ROOT" "$sandbox" >/dev/null 2>&1
    (
      cd "$sandbox"
      git fetch --quiet >/dev/null 2>&1 || true
      git checkout --quiet "$current_commit" >/dev/null 2>&1 || {
        git checkout --quiet -B "$current_branch" "$current_commit" >/dev/null 2>&1
      }
      git reset --quiet --hard "$current_commit" >/dev/null
      git submodule update --init --recursive >/dev/null 2>&1 || true
    )
  else
    mkdir -p "$WORKTREE_ROOT"
    sandbox="$WORKTREE_ROOT/$slug"
    if [[ -d "$sandbox" ]]; then
      echo "subagent_manager: worktree path $sandbox already exists" >&2
      return 1
    fi
    if git rev-parse --verify "$slug" >/dev/null 2>&1; then
      git worktree add "$sandbox" "$slug"
    else
      git worktree add "$sandbox" -b "$slug"
    fi
  fi

  local tracked_env_vars=(
    SUBAGENT_CODEX_PROFILE
    SUBAGENT_CODEX_MODEL
    SUBAGENT_CODEX_SANDBOX_MODE
    SUBAGENT_CODEX_APPROVAL_POLICY
    SUBAGENT_CODEX_SESSION_MODE
    SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS
    SUBAGENT_CODEX_ALLOWED_WRITES
    SUBAGENT_CODEX_CONFIG_OVERRIDES
    SUBAGENT_CODEX_USE_EXEC
    SUBAGENT_CODEX_EXEC_JSON
  )
  local restore_env_cmds=()
  for _var in "${tracked_env_vars[@]}"; do
    if [[ "${!_var+x}" == "x" ]]; then
      printf -v _cmd 'export %s=%q' "$_var" "${!_var}"
    else
      _cmd="unset $_var || true"
    fi
    restore_env_cmds+=("$_cmd")
  done

  scope_path="$sandbox/SUBAGENT_SCOPE.md"
  local scope_template_source=""
  if [[ -z "$scope_override" ]]; then
    if [[ "$normalized_role" == "senior_architect.md" || "$slug" == "senior-review" ]]; then
      scope_template_source="$ROOT/parallelus/manuals/templates/senior_architect_scope.md"
    elif [[ "$normalized_role" == "continuous_improvement_auditor.md" || "$slug" == "ci-audit" ]]; then
      scope_template_source="$ROOT/parallelus/manuals/templates/ci_audit_scope.md"
    fi
  fi
  create_scope_file "$scope_path" "${scope_override:-$scope_template_source}"
  python3 - <<'PY' "$scope_path" "$parent_branch" "$current_commit"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
parent_branch = sys.argv[2]
current_commit = sys.argv[3]
marker_branch = parent_branch.replace('/', '-')
marker_path = f"docs/parallelus/self-improvement/markers/{marker_branch}.json"
failures_path = f"docs/parallelus/self-improvement/failures/{marker_branch}--<marker-timestamp>.json"
review_path = f"docs/parallelus/reviews/{marker_branch}-<YYYY-MM-DD>.md"
marker_full = Path(marker_path)
if marker_full.exists():
    try:
        data = json.loads(marker_full.read_text(encoding="utf-8"))
        ts = data.get("timestamp")
        if ts:
            failures_path = str(marker_full.parent.parent / "failures" / f"{marker_branch}--{ts}.json")
    except Exception:
        pass

text = path.read_text(encoding="utf-8")
placeholders = {
    "{{PARENT_BRANCH}}": parent_branch,
    "{{MARKER_PATH}}": marker_path,
    "{{FAILURES_PATH}}": failures_path,
    "{{TARGET_COMMIT}}": current_commit,
    "{{REVIEW_PATH}}": review_path,
}
for key, value in placeholders.items():
    if key in text:
        text = text.replace(key, value)
path.write_text(text, encoding="utf-8")
PY
  progress_path="$sandbox/subagent.progress.md"
  : >"$progress_path"
  prompt_path="$sandbox/SUBAGENT_PROMPT.txt"
  create_prompt_file "$prompt_path" "$sandbox" "$scope_path" "$type" "$slug" "$codex_profile" "$normalized_role" "$parent_branch" "$progress_path" "$current_commit"
  log_path="$sandbox/subagent.log"
  : >"$log_path"

  if [[ -z "$codex_profile" && -n "${SUBAGENT_CODEX_PROFILE:-}" ]]; then
    codex_profile="$SUBAGENT_CODEX_PROFILE"
  fi

  # Default to exec-mode for subagents to improve transcript quality and machine-readable monitoring.
  # Opt out by setting PARALLELUS_CODEX_USE_TUI=1 (or explicitly unsetting SUBAGENT_CODEX_USE_EXEC).
  if [[ "$normalized_role" == "continuous_improvement_auditor.md" || "$slug" == "ci-audit" ]]; then
    # CI auditor runs are stable in text mode and avoid JSON parse-warning noise in long transcripts.
    if [[ -z "${SUBAGENT_CODEX_USE_EXEC+x}" ]]; then
      export SUBAGENT_CODEX_USE_EXEC=1
    fi
    if [[ -z "${SUBAGENT_CODEX_EXEC_JSON+x}" ]]; then
      export SUBAGENT_CODEX_EXEC_JSON=0
    fi
  fi
  if ! is_enabled "${PARALLELUS_CODEX_USE_TUI:-}" && [[ -z "${SUBAGENT_CODEX_USE_EXEC+x}" ]]; then
    export SUBAGENT_CODEX_USE_EXEC=1
  fi
  if ! is_enabled "${PARALLELUS_CODEX_USE_TUI:-}" && is_enabled "${SUBAGENT_CODEX_USE_EXEC:-}" && [[ -z "${SUBAGENT_CODEX_EXEC_JSON+x}" ]]; then
    export SUBAGENT_CODEX_EXEC_JSON=1
  fi

  local entry_json
  local deliverables_payload="[]"
  local senior_review_meta=""
  if ((${#deliverables_specs[@]})); then
    deliverables_payload=$(python3 - <<'PY' "${deliverables_specs[@]}"
import json
import sys
from pathlib import PurePosixPath

def validate(spec: str) -> str:
    if not spec:
        raise SystemExit("subagent_manager launch: empty deliverable spec")
    if spec.startswith('/'):
        raise SystemExit(f"subagent_manager launch: deliverable must be relative, got {spec}")
    path = PurePosixPath(spec)
    if any(part == '..' for part in path.parts):
        raise SystemExit(f"subagent_manager launch: deliverable must stay within sandbox, got {spec}")
    return path.as_posix()

items = []
args = sys.argv[1:]
for raw in args:
    raw = raw.strip()
    if not raw:
        continue
    if ':' in raw:
        source, target = raw.split(':', 1)
    else:
        source, target = raw, raw
    source = validate(source)
    target = validate(target)
    items.append({
        "source": source,
        "target": target,
        "status": "pending"
    })

print(json.dumps(items))
PY
    ) || return 1
  fi
  if [[ "$normalized_role" == "senior_architect.md" || "$slug" == "senior-review" ]]; then
    senior_review_meta=$(python3 - <<'PY' "$sandbox" "$parent_branch"
import glob
import hashlib
import json
import os
import sys

def fingerprint(path: str) -> str:
    if os.path.islink(path):
        return "symlink:" + os.readlink(path)
    if os.path.isdir(path):
        digest = hashlib.sha256()
        for root, dirs, files in os.walk(path):
            dirs.sort()
            files.sort()
            rel_root = os.path.relpath(root, path)
            digest.update(f"D:{rel_root}\n".encode("utf-8", "ignore"))
            for name in files:
                file_path = os.path.join(root, name)
                rel_path = os.path.relpath(file_path, path)
                digest.update(f"F:{rel_path}\n".encode("utf-8", "ignore"))
                with open(file_path, "rb") as fh:
                    for chunk in iter(lambda: fh.read(65536), b""):
                        digest.update(chunk)
        return "dir:" + digest.hexdigest()
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return "file:" + digest.hexdigest()

sandbox = sys.argv[1]
parent_branch = sys.argv[2]
branch_slug = parent_branch.replace('/', '-')
pattern = f"docs/parallelus/reviews/{branch_slug}-*.md"
glob_pattern = os.path.join(sandbox, pattern)
baseline = []
baseline_fingerprints = {}
for path in sorted(glob.glob(glob_pattern)):
    rel = os.path.relpath(path, sandbox)
    baseline.append(rel)
    baseline_fingerprints[rel] = fingerprint(path)
print(json.dumps({
    "source_glob": pattern,
    "baseline": baseline,
    "baseline_fingerprints": baseline_fingerprints,
}))
PY
    ) || return 1
  fi
  if [[ -n "$senior_review_meta" ]]; then
    deliverables_payload=$(python3 - <<'PY' "$deliverables_payload" "$senior_review_meta"
import json
import sys

existing = json.loads(sys.argv[1] or "[]")
meta = json.loads(sys.argv[2] or "{}")
if meta:
    deliverable = {
        "id": "senior-review-report",
        "kind": "review_markdown",
        "source_glob": meta.get("source_glob"),
        "baseline": meta.get("baseline") or [],
        "baseline_fingerprints": meta.get("baseline_fingerprints") or {},
        "status": "waiting",
    }
    existing.append(deliverable)
print(json.dumps(existing))
PY
    ) || return 1
  fi
  entry_json=$(
    python3 - "$entry_id" "$type" "$slug" "$sandbox" "$scope_path" "$prompt_path" "$log_path" "$progress_path" "$launcher" "$timestamp" "$codex_profile" "$normalized_role" "$deliverables_payload" "$current_branch" "$current_commit" "${SUBAGENT_CI_AUDIT_TIMEOUT_SECONDS:-600}" <<'PY'
import json
import sys

(
    entry_id,
    type_,
    slug,
    path,
    scope,
    prompt,
    log_path,
    progress_path,
    launcher,
    timestamp,
    profile,
    role_prompt,
    deliverables_json,
    source_branch,
    source_commit,
    ci_audit_timeout_raw,
) = sys.argv[1:17]

payload = {
    "id": entry_id,
    "type": type_,
    "slug": slug,
    "path": path,
    "scope_path": scope,
    "prompt_path": prompt,
    "log_path": log_path,
    "progress_path": progress_path,
    "launcher": launcher,
    "status": "pending_launch",
    "launched_at": timestamp,
    "window_title": "",
    "launcher_kind": "",
    "launcher_handle": None,
}
if profile:
    payload["codex_profile"] = profile
if role_prompt:
    payload["role_prompt"] = role_prompt
if deliverables_json:
    deliverables = json.loads(deliverables_json)
    if deliverables:
        payload["deliverables"] = deliverables
        statuses = {((item.get("status") or "pending").lower()) for item in deliverables}
        if statuses and statuses <= {"waiting"}:
            payload["deliverables_status"] = "waiting"
        else:
            payload["deliverables_status"] = "pending"
if source_commit:
    payload["source_commit"] = source_commit
if source_branch:
    payload["source_branch"] = source_branch

is_ci_auditor = False
role_name = (role_prompt or "").strip()
if role_name:
    normalized = role_name.lower()
    if normalized in {"continuous_improvement_auditor", "continuous_improvement_auditor.md"}:
        is_ci_auditor = True
if slug in {"ci-audit", "continuous-improvement-auditor"}:
    is_ci_auditor = True
if is_ci_auditor:
    try:
        timeout_seconds = int(str(ci_audit_timeout_raw).strip() or "600")
    except Exception:
        timeout_seconds = 600
    if timeout_seconds <= 0:
        timeout_seconds = 600
    payload["timeout_seconds"] = timeout_seconds

print(json.dumps(payload))
PY
  ) || exit 1
  append_registry "$entry_json"

  echo "Launching subagent: id=$entry_id type=$type path=$sandbox" >&2
  if [[ -n "$codex_profile" ]]; then
    export SUBAGENT_CODEX_PROFILE="$codex_profile"
  fi

  if run_launch "$launcher" "$sandbox" "$prompt_path" "$type" "$log_path" "$entry_id"; then
    update_registry "$entry_id" "row['status'] = 'running'"
  else
    update_registry "$entry_id" "row['status'] = 'awaiting_manual_launch'"
    echo "Subagent not auto-launched; status set to awaiting_manual_launch." >&2
  fi

  for _cmd in "${restore_env_cmds[@]}"; do
    eval "$_cmd"
  done
  if [[ -x "$MONITOR_HELPER" ]]; then
    echo "Monitor with: $MONITOR_HELPER --id $entry_id" >&2
    echo "Wait for the monitor loop to exit cleanly before running subagent_manager.sh cleanup." >&2
  fi
  if ((${#deliverables_specs[@]})); then
    echo "Harvest deliverables with: $0 harvest --id $entry_id" >&2
  fi
  echo "$entry_id"
}

cmd_status() {
  local filter_id=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id)
        filter_id=$2; shift 2 ;;
      --help)
        echo "Usage: subagent_manager.sh status [--id ID]"; return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done
  ensure_registry
  print_status "$filter_id"
}

cmd_verify() {
  local entry_id=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id)
        entry_id=$2; shift 2 ;;
      --help)
        echo "Usage: subagent_manager.sh verify --id ID"; return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done
  if [[ -z "$entry_id" ]]; then
    echo "subagent_manager verify: --id required" >&2
    return 1
  fi
  ensure_registry
  local entry_json path type
  entry_json=$(get_registry_entry "$entry_id")
  path=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['path'])" "$entry_json")
  type=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['type'])" "$entry_json")

  if [[ "$type" == "throwaway" ]]; then
    "$VERIFY_HELPER" --repo "$path"
    update_registry "$entry_id" "row['status'] = 'verified'"
  else
    if [[ -n $(git -C "$path" status --short) ]]; then
      echo "subagent_manager: worktree $path is not clean" >&2
      exit 1
    fi
    update_registry "$entry_id" "row['status'] = 'ready_for_merge'"
  fi
  echo "Verified $entry_id ($type)"
}

cmd_resume() {
  local entry_id=""
  local prompt=""
  local prompt_file=""
  local launcher="tmux"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)
        entry_id=$2; shift 2 ;;
      --prompt)
        prompt=$2; shift 2 ;;
      --prompt-file)
        prompt_file=$2; shift 2 ;;
      --launcher)
        launcher=$2; shift 2 ;;
      --help)
        cat <<'USAGE'
Usage: subagent_manager.sh resume --id ID (--prompt TEXT | --prompt-file FILE) [--launcher tmux|manual]

Resume a subagent launched via `codex exec` by sending a follow-up prompt using
the recorded exec session id (thread_id).
USAGE
        return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done
  if [[ -z "$entry_id" ]]; then
    echo "subagent_manager resume: --id required" >&2
    return 1
  fi
  if [[ -z "$prompt" && -z "$prompt_file" ]]; then
    echo "subagent_manager resume: --prompt or --prompt-file required" >&2
    return 1
  fi
  if [[ -n "$prompt" && -n "$prompt_file" ]]; then
    echo "subagent_manager resume: choose --prompt or --prompt-file (not both)" >&2
    return 1
  fi
  if [[ ! -x "$EXEC_RESUME_HELPER" ]]; then
    echo "subagent_manager resume: exec resume helper missing: $EXEC_RESUME_HELPER" >&2
    return 1
  fi
  local args=(--id "$entry_id" --launcher "$launcher")
  if [[ -n "$prompt" ]]; then
    args+=(--prompt "$prompt")
  else
    args+=(--prompt-file "$prompt_file")
  fi
  "$EXEC_RESUME_HELPER" "${args[@]}"
}

cmd_harvest() {
  local entry_id=""
  local dest_root="$ROOT"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id)
        entry_id=$2; shift 2 ;;
      --dest)
        dest_root=$2; shift 2 ;;
      --help)
        cat <<'USAGE'
Usage: subagent_manager.sh harvest --id ID [--dest DIR]

Copy deliverables recorded for the specified subagent into the current repo.
By default, deliverables land at the repo root; use --dest to override (must
remain within the repo tree).
USAGE
        return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done
  if [[ -z "$entry_id" ]]; then
    echo "subagent_manager harvest: --id required" >&2
    return 1
  fi

  ensure_registry
  local entry_json
  entry_json=$(get_registry_entry "$entry_id") || return 1

  local dest_root_abs
  dest_root_abs=$(python3 - <<'PY' "$dest_root" "$ROOT"
import os
import sys

dest = os.path.realpath(os.path.expanduser(sys.argv[1]))
root = os.path.realpath(sys.argv[2])
if not dest.startswith(root):
    raise SystemExit("subagent_manager harvest: destination must be inside the repository root")
os.makedirs(dest, exist_ok=True)
print(dest)
PY
  ) || return 1

  local harvest_payload
  harvest_payload=$(python3 - <<'PY' "$entry_json" "$dest_root_abs"
import glob
import hashlib
import json
import os
import shutil
import sys
import time
from typing import Dict, List

entry = json.loads(sys.argv[1])
dest_root = os.path.normpath(sys.argv[2])
sandbox_root = os.path.normpath(entry.get("path", ""))
if not sandbox_root:
    raise SystemExit("subagent_manager harvest: registry entry missing sandbox path")
source_branch = entry.get("source_branch") or ""
source_commit = entry.get("source_commit") or ""

deliverables: List[dict] = entry.get("deliverables") or []
if not deliverables:
    raise SystemExit("subagent_manager harvest: no deliverables recorded for this subagent")

copied: List[str] = []
sandbox_root_with_sep = sandbox_root + os.sep
dest_root_with_sep = dest_root + os.sep

def fingerprint(path: str) -> str:
    if os.path.islink(path):
        return "symlink:" + os.readlink(path)
    if os.path.isdir(path):
        digest = hashlib.sha256()
        for root, dirs, files in os.walk(path):
            dirs.sort()
            files.sort()
            rel_root = os.path.relpath(root, path)
            digest.update(f"D:{rel_root}\n".encode("utf-8", "ignore"))
            for name in files:
                file_path = os.path.join(root, name)
                rel_path = os.path.relpath(file_path, path)
                digest.update(f"F:{rel_path}\n".encode("utf-8", "ignore"))
                with open(file_path, "rb") as fh:
                    for chunk in iter(lambda: fh.read(65536), b""):
                        digest.update(chunk)
        return "dir:" + digest.hexdigest()
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return "file:" + digest.hexdigest()

def read_review_metadata(path: str) -> Dict[str, str]:
    keys = {"Reviewed-Branch", "Reviewed-Commit", "Decision"}
    out: Dict[str, str] = {}
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            for raw in fh:
                if ":" not in raw:
                    continue
                key, value = raw.split(":", 1)
                key = key.strip()
                if key in keys and key not in out:
                    out[key] = value.strip()
                if len(out) == len(keys):
                    break
    except OSError as exc:
        raise SystemExit(f"subagent_manager harvest: unable to read review metadata from {path}: {exc}") from exc
    return out

def validate_review_context(path: str) -> None:
    if not source_branch and not source_commit:
        return
    metadata = read_review_metadata(path)
    reviewed_branch = metadata.get("Reviewed-Branch", "")
    reviewed_commit = metadata.get("Reviewed-Commit", "")
    decision = metadata.get("Decision", "").strip().lower()
    if not reviewed_branch or not reviewed_commit:
        raise SystemExit(
            "subagent_manager harvest: senior review deliverable missing Reviewed-Branch/Reviewed-Commit metadata"
        )
    if source_commit and reviewed_commit != source_commit:
        raise SystemExit(
            "subagent_manager harvest: review commit mismatch "
            f"(expected {source_commit}, got {reviewed_commit})"
        )
    if source_branch and reviewed_branch not in {source_branch, f"origin/{source_branch}"}:
        raise SystemExit(
            "subagent_manager harvest: review branch mismatch "
            f"(expected {source_branch}, got {reviewed_branch})"
        )
    if decision and decision not in {"approved", "changes_requested", "needs_changes"}:
        raise SystemExit(
            "subagent_manager harvest: senior review deliverable has unexpected Decision value "
            f"'{metadata.get('Decision', '')}'"
        )

for item in deliverables:
    status = (item.get("status") or "pending").lower()
    source_rel = item.get("source")
    source_glob = item.get("source_glob")
    baseline = set(item.get("baseline") or [])
    baseline_fingerprints = item.get("baseline_fingerprints") or {}
    ready_files = item.get("ready_files") or []
    targets: List[str] = []

    if status == "harvested":
        continue

    if source_rel:
        targets.append((source_rel, item.get("target") or source_rel))
    elif source_glob:
        matches = []
        glob_pattern = os.path.join(sandbox_root, source_glob)
        if ready_files:
            matches = list(ready_files)
        else:
            for path in sorted(glob.glob(glob_pattern)):
                rel = os.path.relpath(path, sandbox_root)
                if rel not in baseline:
                    matches.append(rel)
                    continue
                previous = baseline_fingerprints.get(rel)
                if previous and previous != fingerprint(path):
                    matches.append(rel)
                    continue
        for rel in matches:
            targets.append((rel, item.get("target") or rel))
        if not matches:
            # No new files yet; leave status as-is so the monitor keeps waiting.
            continue
    else:
        continue

    for source_rel_path, target_rel in targets:
        source_path = os.path.normpath(os.path.join(sandbox_root, source_rel_path))
        target_path = os.path.normpath(os.path.join(dest_root, target_rel))
        if not (source_path == sandbox_root or source_path.startswith(sandbox_root_with_sep)):
            raise SystemExit(f"subagent_manager harvest: deliverable source escapes sandbox: {source_rel_path}")
        if not (target_path == dest_root or target_path.startswith(dest_root_with_sep)):
            raise SystemExit(f"subagent_manager harvest: deliverable target escapes repo: {target_rel}")
        if not os.path.exists(source_path):
            raise SystemExit(f"subagent_manager harvest: deliverable not found: {source_rel_path}")
        if item.get("id") == "senior-review-report":
            validate_review_context(source_path)

        target_parent = os.path.dirname(target_path)
        if target_parent:
            os.makedirs(target_parent, exist_ok=True)

        if os.path.isdir(source_path):
            shutil.copytree(source_path, target_path, dirs_exist_ok=True)
        else:
            shutil.copy2(source_path, target_path)

        copied.append(target_rel)

    if targets:
        item["status"] = "harvested"
        item["harvested_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        item["target_path"] = targets[-1][1]
        if source_glob:
            baseline.update(source_rel_path for source_rel_path, _ in targets)
            item["baseline"] = sorted(baseline)
            for source_rel_path, _ in targets:
                source_path = os.path.normpath(os.path.join(sandbox_root, source_rel_path))
                if os.path.exists(source_path):
                    baseline_fingerprints[source_rel_path] = fingerprint(source_path)
            item["baseline_fingerprints"] = baseline_fingerprints
        if "ready_files" in item:
            item.pop("ready_files", None)

payload = {
    "deliverables": deliverables,
    "copied": copied,
}
if all((d.get("status") or "pending").lower() == "harvested" for d in deliverables):
    payload["deliverables_status"] = "harvested"
elif any((d.get("status") or "pending").lower() == "harvested" for d in deliverables):
    payload["deliverables_status"] = "partial"
else:
    payload["deliverables_status"] = "pending"

print(json.dumps(payload))
PY
  ) || return 1

  local copied_targets
  copied_targets=$(python3 - <<'PY' "$REGISTRY_FILE" "$entry_id" "$harvest_payload"
import json
import sys

registry_path, entry_id, payload_json = sys.argv[1:4]
payload = json.loads(payload_json)
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        row["deliverables"] = payload.get("deliverables", [])
        status = payload.get("deliverables_status")
        if status:
            row["deliverables_status"] = status
        break
else:
    raise SystemExit(f"subagent_manager harvest: unknown id {entry_id}")
with open(registry_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)

copied = payload.get("copied", [])
print("\n".join(copied))
PY
  ) || return 1

  if [[ -n "$copied_targets" ]]; then
    echo "Harvested deliverables:" >&2
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "  - $line" >&2
    done <<<"$copied_targets"
  else
    echo "No pending deliverables to harvest for $entry_id." >&2
  fi
}

close_launcher_handle() {
  local launcher_kind=$1
  local launcher_window=$2
  local launcher_pane=$3
  local entry_id=$4
  if [[ -z "$TMUX_BIN" ]]; then
    return 0
  fi
  if [[ "$launcher_kind" == "tmux-window" && -n "$launcher_window" ]]; then
    "$TMUX_BIN" kill-window -t "$launcher_window" >/dev/null 2>&1 || true
  elif [[ "$launcher_kind" == "tmux-pane" && -n "$launcher_pane" ]]; then
    "$TMUX_BIN" kill-pane -t "$launcher_pane" >/dev/null 2>&1 || true
    if [[ -n "$launcher_window" ]]; then
      mapfile -t _remaining < <("$TMUX_BIN" list-panes -t "$launcher_window" -F '#{pane_id}' 2>/dev/null || true)
      if (( ${#_remaining[@]} == 0 )); then
        "$TMUX_BIN" kill-window -t "$launcher_window" >/dev/null 2>&1 || true
      fi
    fi
  else
    # Fallback: if registry metadata is missing, kill any tmux pane whose title
    # matches the entry id.
    while IFS='|' read -r pane_id pane_title; do
      [[ -z "$pane_id" || -z "$pane_title" ]] && continue
      if [[ "$pane_title" == "$entry_id" ]]; then
        "$TMUX_BIN" kill-pane -t "$pane_id" >/dev/null 2>&1 || true
      fi
    done < <("$TMUX_BIN" list-panes -a -F '#{pane_id}|#{pane_title}' 2>/dev/null || true)
  fi
}

cmd_abort() {
  local entry_id=""
  local reason="manual"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id)
        entry_id=$2; shift 2 ;;
      --reason)
        reason=$2; shift 2 ;;
      --help)
        echo "Usage: subagent_manager.sh abort --id ID [--reason REASON]"; return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done
  if [[ -z "$entry_id" ]]; then
    echo "subagent_manager abort: --id required" >&2
    return 1
  fi
  ensure_registry
  local entry_json status launcher_kind launcher_window launcher_pane status_value
  entry_json=$(get_registry_entry "$entry_id")
  status=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('status',''))" "$entry_json")
  launcher_kind=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('launcher_kind',''))" "$entry_json")
  launcher_window=$(python3 -c "import json,sys; e=json.loads(sys.argv[1]); h=e.get('launcher_handle') or {}; print(h.get('window_id',''))" "$entry_json")
  launcher_pane=$(python3 -c "import json,sys; e=json.loads(sys.argv[1]); h=e.get('launcher_handle') or {}; print(h.get('pane_id',''))" "$entry_json")
  status_value=$(python3 -c "import re,sys; r=(sys.argv[1] or 'manual').strip().lower(); n=re.sub(r'[^a-z0-9]+','_',r).strip('_') or 'manual'; print(f'aborted_{n}')" "$reason")
  if [[ "$status" == "cleaned" ]]; then
    echo "subagent_manager abort: entry $entry_id already cleaned." >&2
    return 1
  fi

  close_launcher_handle "$launcher_kind" "$launcher_window" "$launcher_pane" "$entry_id"
  python3 - "$REGISTRY_FILE" "$entry_id" "$status_value" "$reason" <<'PY'
import json
import sys
import time

registry_path, entry_id, status_value, reason = sys.argv[1:5]
with open(registry_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
for row in data:
    if row.get("id") == entry_id:
        row["status"] = status_value
        row["aborted_reason"] = reason
        row["aborted_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        break
else:
    raise SystemExit(f"subagent_manager abort: unknown id {entry_id}")
with open(registry_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
PY
  echo "Aborted $entry_id (reason=$reason)"
}

cmd_cleanup() {
  local entry_id=""
  local force=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id)
        entry_id=$2; shift 2 ;;
      --force)
        force=1; shift ;;
      --help)
        echo "Usage: subagent_manager.sh cleanup --id ID [--force]"; return 0 ;;
      *)
        echo "Unknown option $1" >&2; return 1 ;;
    esac
  done
  if [[ -z "$entry_id" ]]; then
    echo "subagent_manager cleanup: --id required" >&2
    return 1
  fi
  ensure_registry
  local entry_json path type slug status launcher_kind launcher_window launcher_pane
  entry_json=$(get_registry_entry "$entry_id")
  path=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['path'])" "$entry_json")
  type=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['type'])" "$entry_json")
  slug=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['slug'])" "$entry_json")
  status=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('status',''))" "$entry_json")
  launcher_kind=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('launcher_kind',''))" "$entry_json")
  launcher_window=$(python3 -c "import json,sys; e=json.loads(sys.argv[1]); h=e.get('launcher_handle') or {}; print(h.get('window_id',''))" "$entry_json")
  launcher_pane=$(python3 -c "import json,sys; e=json.loads(sys.argv[1]); h=e.get('launcher_handle') or {}; print(h.get('pane_id',''))" "$entry_json")
  local pending_deliverables
  pending_deliverables=$(python3 - "$entry_json" <<'PY'
import json
import sys

entry = json.loads(sys.argv[1])
items = entry.get("deliverables") or []
for idx, item in enumerate(items, start=1):
    status = (item.get("status") or "pending").lower()
    if status == "harvested":
        continue
    label = (
        item.get("id")
        or item.get("source_glob")
        or item.get("source")
        or f"deliverable-{idx}"
    )
    print(f"{label}:{status}")
PY
  )

  if [[ $force -eq 0 && "$status" == "running" ]]; then
    echo "subagent_manager cleanup: refusing to remove running sandbox $entry_id." >&2
    if [[ -x "$MONITOR_HELPER" ]]; then
      echo "  Run $MONITOR_HELPER --id $entry_id and wait for it to exit (subagent finished) before cleaning up." >&2
    fi
    echo "  Re-run with --force only if you are certain the subagent has stopped." >&2
    return 1
  fi
  if [[ $force -eq 0 && -n "$pending_deliverables" ]]; then
    echo "subagent_manager cleanup: refusing to remove sandbox $entry_id while deliverables remain unharvested." >&2
    echo "  Harvest pending deliverables first:" >&2
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "  - $line" >&2
    done <<<"$pending_deliverables"
    echo "  Run '$0 harvest --id $entry_id' and retry cleanup, or use --force to acknowledge data loss risk." >&2
    return 1
  fi

  if [[ "$type" == "throwaway" ]]; then
    rm -rf "$path"
  else
    git worktree remove --force "$path"
    if git rev-parse --verify "$slug" >/dev/null 2>&1; then
      git branch -D "$slug" >/dev/null 2>&1 || true
    fi
  fi
  update_registry "$entry_id" "row['status'] = 'cleaned'"
  close_launcher_handle "$launcher_kind" "$launcher_window" "$launcher_pane" "$entry_id"
  echo "Cleaned $entry_id ($type)"
}

main() {
  local cmd=${1:-}
  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi
  shift
  cd "$ROOT"
  case "$cmd" in
    launch) cmd_launch "$@" ;;
    review-preflight) cmd_review_preflight "$@" ;;
    review-preflight-run) cmd_review_preflight_run "$@" ;;
    status) cmd_status "$@" ;;
    resume) cmd_resume "$@" ;;
    verify) cmd_verify "$@" ;;
    abort) cmd_abort "$@" ;;
    harvest) cmd_harvest "$@" ;;
    cleanup) cmd_cleanup "$@" ;;
    --help|-h) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
