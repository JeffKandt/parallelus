#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REGISTRY_FILE="docs/agents/subagent-registry.json"
SCOPE_TEMPLATE="docs/agents/templates/subagent_scope_template.md"
SANDBOX_ROOT="$ROOT/.parallelus/subagents/sandboxes"
WORKTREE_ROOT="$ROOT/.parallelus/subagents/worktrees"
LAUNCH_HELPER="$ROOT/.agents/bin/launch_subagent.sh"
DEPLOY_HELPER="$ROOT/.agents/bin/deploy_agents_process.sh"
VERIFY_HELPER="$ROOT/.agents/bin/verify_process_run.py"
SESSION_HELPER="$ROOT/.agents/bin/get_current_session_id.sh"
RESUME_HELPER="$ROOT/.agents/bin/resume_in_tmux.sh"
SUBAGENT_LANGS=${SUBAGENT_LANGS:-python}
TMUX_BIN=$(command -v tmux || true)
ROLE_PROMPTS_DIR="$ROOT/.agents/prompts/agent_roles"

usage() {
  cat <<'USAGE'
Usage: subagent_manager.sh <command> [options]
Commands:
  launch   Create a sandbox/worktree and launch a subagent session
  status   List registry entries (optionally filter by --id)
  verify   Validate a completed subagent sandbox/worktree
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
  branch=$(current_branch)
  if [[ "$branch" == "main" ]]; then
    echo "subagent_manager: refuse to run on 'main'. Checkout a feature branch first." >&2
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
import json, sys, os, time
from datetime import datetime

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
handle_values = []

id_width = width_for("ID", id_values, 24, 40)
type_width = width_for("Type", type_values, 10, 14)
slug_width = width_for("Slug", slug_values, 25, 40)
status_width = width_for("Status", status_values, 16, 20)
runtime_width = width_for("Run Time", [], 9, 9)
log_width = width_for("Log Age", [], 9, 9)
handle_width = width_for("Handle", [], 14, 24)
log_header = "Last Log (UTC)"
log_header_width = len(log_header)

row_fmt = (
    f"{{:<{id_width}}} "
    f"{{:<{type_width}}} "
    f"{{:<{slug_width}}} "
    f"{{:<{status_width}}} "
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
    "Run Time",
    "Log Age",
    "Handle",
    log_header,
)
print(header)
print("-" * len(header))
for row in entries:
    log_path = row.get('log_path')
    log_age = '-'
    log_summary = '-'
    runtime = '-'
    handle = '-'
    launched_at = row.get('launched_at')
    if launched_at:
        try:
            launched = datetime.strptime(launched_at, "%Y%m%d-%H%M%S")
            delta = int(max(now - launched.timestamp(), 0))
            minutes, seconds = divmod(delta, 60)
            runtime = f"{minutes:02d}:{seconds:02d}"
        except Exception:
            runtime = '-'
    if log_path and os.path.exists(log_path):
        mtime = os.path.getmtime(log_path)
        delta = int(now - mtime)
        minutes, seconds = divmod(max(delta, 0), 60)
        log_age = f"{minutes:02d}:{seconds:02d}"
        log_summary = datetime.utcfromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S')
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
    print(row_fmt.format(
        row.get('id','-'),
        row.get('type','-'),
        row.get('slug','-'),
        row.get('status','-'),
        runtime,
        log_age,
        handle,
        log_summary,
    ))
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

create_prompt_file() {
  local dest=$1
  local sandbox=$2
  local scope=$3
  local type=$4
  local slug=$5
  local profile=${6:-}
  local role_prompt=${7:-}
  local role_text=""
  local profile_display="default (danger-full-access)"

  if [[ -n "$profile" ]]; then
    profile_display="$profile"
  fi

  if [[ -n "$role_prompt" ]]; then
    local role_file="$ROLE_PROMPTS_DIR/$role_prompt"
    if [[ -f "$role_file" ]]; then
      role_text=$(<"$role_file")
    else
      echo "subagent_manager: role prompt '$role_prompt' not found under $ROLE_PROMPTS_DIR" >&2
    fi
  fi

  cat <<EOF >"$dest"
You are operating inside sandbox: $sandbox
Scope file: $scope
Sandbox type: $type
Codex profile: $profile_display

1. Read AGENTS.md and all referenced docs.
2. Review the scope file, then run \`make bootstrap slug=$slug\` to create the
   feature branch.
3. Convert the scope into plan/progress notebooks and follow all guardrails.
4. Keep the session open until the entire checklist is complete and \`git status\`
   is clean.
5. Immediately after `make read_bootstrap`, **do not pause**—begin reviewing
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

Keep working even after \`make read_bootstrap\`, \`make bootstrap\`, and the initial
scope review. Do not pause to summarize or seek confirmation—continue directly
to the next checklist item.
Avoid standalone status reports after bootstrap; only document progress in the
notebooks/checkpoints the checklist calls for.
---
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

  if [[ -x "$RESUME_HELPER" ]]; then
    if [[ -n "$session_id" ]]; then
      echo "  Command: $RESUME_HELPER $session_id" >&2
    else
      echo "  Command: $RESUME_HELPER" >&2
    fi
  else
    if [[ -n "$session_id" ]]; then
      echo "  Command: tmux new-session -s parallelus -c '$ROOT' 'codex resume $session_id'" >&2
    else
      echo "  Command: tmux new-session -s parallelus -c '$ROOT' 'codex resume <SESSION_ID>'" >&2
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
  local type slug launcher scope_override codex_profile
  type=""
  slug=""
  launcher="auto"
  scope_override=""
  codex_profile=""
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
      --help)
        cat <<'USAGE'
Usage: subagent_manager.sh launch --type {throwaway|worktree} --slug <branch-slug> [--scope FILE] [--launcher MODE] [--profile CODEX_PROFILE]
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
  ensure_tmux_ready "$launcher"

  local timestamp entry_id sandbox scope_path prompt_path log_path
  timestamp=$(date -u +%Y%m%d-%H%M%S)
  entry_id="${timestamp}-${slug}"

  if [[ "$type" == "throwaway" ]]; then
    mkdir -p "$SANDBOX_ROOT"
    sandbox=$(mktemp -d "$SANDBOX_ROOT/${slug}-XXXXXX")
    LANG_FLAGS=()
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      LANG_FLAGS+=("$line")
    done < <(build_lang_flags)
    "$DEPLOY_HELPER" --mode scaffold "${LANG_FLAGS[@]}" --name "$slug" "$sandbox" >&2
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

  scope_path="$sandbox/SUBAGENT_SCOPE.md"
  create_scope_file "$scope_path" "$scope_override"
  prompt_path="$sandbox/SUBAGENT_PROMPT.txt"
  create_prompt_file "$prompt_path" "$sandbox" "$scope_path" "$type" "$slug" "$codex_profile"
  log_path="$sandbox/subagent.log"
  : >"$log_path"

  local entry_json
  entry_json=$(python3 - <<'PY' "$entry_id" "$type" "$slug" "$sandbox" "$scope_path" "$prompt_path" "$log_path" "$launcher" "$timestamp" "$codex_profile") || exit 1
import json
import sys

entry_id, type_, slug, path, scope, prompt, log_path, launcher, timestamp, profile = sys.argv[1:11]
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

print(json.dumps(payload))
PY
  )
  append_registry "$entry_json"

  echo "Launching subagent: id=$entry_id type=$type path=$sandbox" >&2
  local _prev_profile_set=0
  local _prev_profile_value=""
  if [[ "${SUBAGENT_CODEX_PROFILE+x}" == "x" ]]; then
    _prev_profile_set=1
    _prev_profile_value=$SUBAGENT_CODEX_PROFILE
  fi

  if [[ -n "$codex_profile" ]]; then
    export SUBAGENT_CODEX_PROFILE="$codex_profile"
  else
    unset SUBAGENT_CODEX_PROFILE || true
  fi

  run_launch "$launcher" "$sandbox" "$prompt_path" "$type" "$log_path" "$entry_id" || true
  if (( _prev_profile_set )); then
    export SUBAGENT_CODEX_PROFILE="$_prev_profile_value"
  else
    unset SUBAGENT_CODEX_PROFILE || true
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
    echo "subagent_manager cleanup: refusing to remove running sandbox $entry_id (use --force to override)" >&2
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
  if [[ "$launcher_kind" == "tmux-window" && -n "$launcher_window" ]]; then
    tmux kill-window -t "$launcher_window" >/dev/null 2>&1 || true
  elif [[ "$launcher_kind" == "tmux-pane" && -n "$launcher_pane" ]]; then
    tmux kill-pane -t "$launcher_pane" >/dev/null 2>&1 || true
    if [[ -n "$launcher_window" ]]; then
      mapfile -t _remaining < <(tmux list-panes -t "$launcher_window" -F '#{pane_id}' 2>/dev/null || true)
      if (( ${#_remaining[@]} == 0 )); then
        tmux kill-window -t "$launcher_window" >/dev/null 2>&1 || true
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
    cleanup) cmd_cleanup "$@" ;;
    --help|-h) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
