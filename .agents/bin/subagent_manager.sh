#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

RAW_TMUX_BIN=$(command -v tmux || true)
TMUX_WRAPPER="$ROOT/.agents/bin/tmux-safe"
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

REGISTRY_FILE="docs/agents/subagent-registry.json"
SCOPE_TEMPLATE="docs/agents/templates/subagent_scope_template.md"
SANDBOX_ROOT="$ROOT/.parallelus/subagents/sandboxes"
WORKTREE_ROOT="$ROOT/.parallelus/subagents/worktrees"
LAUNCH_HELPER="$ROOT/.agents/bin/launch_subagent.sh"
DEPLOY_HELPER="$ROOT/.agents/bin/deploy_agents_process.sh"
VERIFY_HELPER="$ROOT/.agents/bin/verify_process_run.py"
SESSION_HELPER="$ROOT/.agents/bin/get_current_session_id.sh"
RESUME_HELPER="$ROOT/.agents/bin/resume_in_tmux.sh"
MONITOR_HELPER="$ROOT/.agents/bin/agents-monitor-loop.sh"
SUBAGENT_LANGS=${SUBAGENT_LANGS:-python}
ROLE_PROMPTS_DIR="$ROOT/.agents/prompts/agent_roles"

usage() {
  cat <<'USAGE'
Usage: subagent_manager.sh <command> [options]
Commands:
  launch   Create a sandbox/worktree and launch a subagent session
  status   List registry entries (optionally filter by --id)
  verify   Validate a completed subagent sandbox/worktree
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
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "subagent_manager: refuse to launch senior-review while the worktree has unstaged changes." >&2
    echo "  Commit, stash, or revert local edits before rerunning." >&2
    exit 1
  fi
}

is_doc_only_path() {
  local path=$1
  case "$path" in
    docs/guardrails/runs/*|\
    docs/reviews/*|\
    docs/PLAN.md|\
    docs/PROGRESS.md|\
    docs/plans/*|\
    docs/progress/*|\
    docs/agents/*|\
    docs/self-improvement/*)
      return 0 ;;
  esac
  return 1
}

ensure_senior_review_needed() {
  local branch_slug reviewed_commit head_commit latest_review diff_files non_doc_change=0
  branch_slug=${1//\//-}
  head_commit=$2

  latest_review=$(ls -1t "$ROOT/docs/reviews/${branch_slug}-"*.md 2>/dev/null | head -n1 || true)
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
  ensure_registry
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    return
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
        "Hint: run '.agents/bin/subagent_manager.sh cleanup --id <id>' once the subagent has finished.",
        file=sys.stderr,
    )
    sys.exit(1)
PY
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
                matches = [os.path.relpath(path, sandbox_path) for path in sorted(glob.glob(glob_pattern))]
                baseline = set(item.get("baseline") or [])
                ready = [rel for rel in matches if rel not in baseline]
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

  local instructions
  if [[ "$role_name" == "continuous_improvement_auditor" || "$role_name" == "continuous_improvement_auditor.md" ]]; then
    read -r -d '' instructions <<EOF || true
1. Read AGENTS.md and .agents/prompts/agent_roles/continuous_improvement_auditor.md to confirm guardrails.
2. Review docs/self-improvement/markers/${branch_slug}.json to capture the marker timestamp and referenced plan/progress files for ${parent_branch}.
3. Gather evidence without modifying the workspace: inspect git status, git diff, notebooks, and recent command output that reflect the current state of ${parent_branch}.
4. Emit a JSON object matching the auditor schema (branch, marker_timestamp, summary, issues[], follow_ups[]). Reference concrete evidence for every issue; if no issues exist, return an empty issues array.
5. Stay read-only—do not run make bootstrap or alter files. Print the JSON report and exit.
EOF
  elif [[ "$role_read_only" == "true" ]]; then
    read -r -d '' instructions <<EOF || true
1. Read AGENTS.md and the role prompt to confirm constraints.
2. Stay read-only: do not run make bootstrap or edit code/notebooks; your deliverable lives under docs/reviews/.
3. Run 'make read_bootstrap' to capture context, then review the branch state (diffs, plan/progress notebooks, logs) for ${parent_branch}.
4. Draft the review in docs/reviews/ using the provided template; cite concrete evidence for each finding.
5. When the write-up is complete, leave the Codex pane open and wait for the main agent to harvest the review—no cleanup inside the sandbox is required.
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
9. You already have approval to run commands. After any status update, plan
   outline, or summary, immediately continue with the next checklist item
   without waiting for confirmation.
10. If you ever feel blocked waiting for a "proceed" or approval, assume the
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
  if [[ "$launcher" == "manual" ]]; then
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
    return 0
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
  fi
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
  ensure_slug_clean "$slug"
  ensure_tmux_ready "$launcher"
  ensure_no_tmux_pane_for_slug "$slug"

  local parent_branch
  parent_branch=$(current_branch)

  local normalized_role="$role_prompt"
  if [[ -n "$role_prompt" && "$role_prompt" != *.md && -f "$ROLE_PROMPTS_DIR/${role_prompt}.md" ]]; then
    normalized_role="${role_prompt}.md"
  fi

  local timestamp entry_id sandbox scope_path prompt_path log_path
  local current_branch current_commit
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  current_commit=$(git rev-parse HEAD)
  timestamp=$(date -u +%Y%m%d-%H%M%S)
  entry_id="${timestamp}-${slug}"

  if [[ "$normalized_role" == "senior_architect.md" || "$slug" == "senior-review" ]]; then
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
  create_scope_file "$scope_path" "$scope_override"
  python3 - <<'PY' "$scope_path" "$parent_branch"
import sys
from pathlib import Path

path = Path(sys.argv[1])
parent_branch = sys.argv[2]
marker_branch = parent_branch.replace('/', '-')
marker_path = f"docs/self-improvement/markers/{marker_branch}.json"

text = path.read_text(encoding="utf-8")
if "{{PARENT_BRANCH}}" in text or "{{MARKER_PATH}}" in text:
    text = text.replace("{{PARENT_BRANCH}}", parent_branch)
    text = text.replace("{{MARKER_PATH}}", marker_path)
    path.write_text(text, encoding="utf-8")
PY
  prompt_path="$sandbox/SUBAGENT_PROMPT.txt"
  create_prompt_file "$prompt_path" "$sandbox" "$scope_path" "$type" "$slug" "$codex_profile" "$normalized_role" "$parent_branch"
  log_path="$sandbox/subagent.log"
  : >"$log_path"

  if [[ -z "$codex_profile" && -n "${SUBAGENT_CODEX_PROFILE:-}" ]]; then
    codex_profile="$SUBAGENT_CODEX_PROFILE"
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
import json
import os
import sys

sandbox = sys.argv[1]
parent_branch = sys.argv[2]
branch_slug = parent_branch.replace('/', '-')
pattern = f"docs/reviews/{branch_slug}-*.md"
glob_pattern = os.path.join(sandbox, pattern)
baseline = []
for path in sorted(glob.glob(glob_pattern)):
    baseline.append(os.path.relpath(path, sandbox))
print(json.dumps({
    "source_glob": pattern,
    "baseline": baseline,
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
        "status": "waiting",
    }
    existing.append(deliverable)
print(json.dumps(existing))
PY
    ) || return 1
  fi
  entry_json=$(
    python3 - "$entry_id" "$type" "$slug" "$sandbox" "$scope_path" "$prompt_path" "$log_path" "$launcher" "$timestamp" "$codex_profile" "$normalized_role" "$deliverables_payload" "$current_commit" <<'PY'
import json
import sys
import shlex

entry_id, type_, slug, path, scope, prompt, log_path, launcher, timestamp, profile, role_prompt, deliverables_json, source_commit = sys.argv[1:14]
payload = {
    "id": entry_id,
    "type": type_,
    "slug": slug,
    "path": path,
    "scope_path": scope,
    "prompt_path": prompt,
    "log_path": log_path,
    "launcher": launcher,
    "status": "running",
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

print(json.dumps(payload))
PY
  ) || exit 1
  append_registry "$entry_json"

  echo "Launching subagent: id=$entry_id type=$type path=$sandbox" >&2
  if [[ -n "$codex_profile" ]]; then
    export SUBAGENT_CODEX_PROFILE="$codex_profile"
  fi

  run_launch "$launcher" "$sandbox" "$prompt_path" "$type" "$log_path" "$entry_id" || true

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
import json
import os
import shutil
import sys
import time
from typing import List

entry = json.loads(sys.argv[1])
dest_root = os.path.normpath(sys.argv[2])
sandbox_root = os.path.normpath(entry.get("path", ""))
if not sandbox_root:
    raise SystemExit("subagent_manager harvest: registry entry missing sandbox path")

deliverables: List[dict] = entry.get("deliverables") or []
if not deliverables:
    raise SystemExit("subagent_manager harvest: no deliverables recorded for this subagent")

copied: List[str] = []
sandbox_root_with_sep = sandbox_root + os.sep
dest_root_with_sep = dest_root + os.sep

for item in deliverables:
    status = (item.get("status") or "pending").lower()
    source_rel = item.get("source")
    source_glob = item.get("source_glob")
    baseline = set(item.get("baseline") or [])
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
                if rel in baseline:
                    continue
                matches.append(rel)
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
        if source_glob and baseline:
            baseline.update(source_rel_path for source_rel_path, _ in targets)
            item["baseline"] = sorted(baseline)
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
  IFS=$'\n' read -r launcher_kind launcher_window launcher_pane < <(python3 - "$entry_json" <<'PY'
import json, sys
entry = json.loads(sys.argv[1])
handle = entry.get("launcher_handle") or {}
print(entry.get("launcher_kind", ""))
print(handle.get("window_id", ""))
print(handle.get("pane_id", ""))
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

  if [[ "$type" == "throwaway" ]]; then
    rm -rf "$path"
  else
    git worktree remove --force "$path"
    if git rev-parse --verify "$slug" >/dev/null 2>&1; then
      git branch -D "$slug" >/dev/null 2>&1 || true
    fi
  fi
  update_registry "$entry_id" "row['status'] = 'cleaned'"
  if [[ -n "$TMUX_BIN" ]]; then
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
    fi
  fi
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
    status) cmd_status "$@" ;;
    verify) cmd_verify "$@" ;;
    harvest) cmd_harvest "$@" ;;
    cleanup) cmd_cleanup "$@" ;;
    --help|-h) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
