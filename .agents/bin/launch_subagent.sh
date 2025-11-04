#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TMUX:-}" && -n "${PARALLELUS_TMUX_SOCKET:-}" ]]; then
  if command -v tmux >/dev/null 2>&1; then
    tmux_env=$(tmux -S "${PARALLELUS_TMUX_SOCKET}" display-message -p '#{socket_path},#{session_id},#{pane_id}' 2>/dev/null || true)
    if [[ -n "${tmux_env:-}" ]]; then
      export TMUX="$tmux_env"
    fi
  fi
fi

print_manual() {
  local path=$1
  local prompt=$2
  local profile_arg=""
  local model_arg=""
  local sandbox_arg=""
  local approval_arg=""
  local config_args=""
  if [[ -n "${SUBAGENT_CODEX_PROFILE:-}" ]]; then
    profile_arg=" --profile ${SUBAGENT_CODEX_PROFILE}"
  fi
  if [[ -n "${SUBAGENT_CODEX_MODEL:-}" ]]; then
    model_arg=" --model ${SUBAGENT_CODEX_MODEL}"
  fi
  local dangerous_args=""
  if [[ -n "${SUBAGENT_CODEX_SANDBOX_MODE:-}" ]]; then
    sandbox_arg=" --sandbox ${SUBAGENT_CODEX_SANDBOX_MODE}"
  else
    dangerous_args=" --dangerously-bypass-approvals-and-sandbox --sandbox danger-full-access"
  fi
  if [[ -n "${SUBAGENT_CODEX_APPROVAL_POLICY:-}" ]]; then
    approval_arg=" --ask-for-approval ${SUBAGENT_CODEX_APPROVAL_POLICY}"
  fi
  if [[ -n "${SUBAGENT_CODEX_CONFIG_OVERRIDES:-}" ]]; then
    config_args=$(python3 - <<'PY' "${SUBAGENT_CODEX_CONFIG_OVERRIDES}"
import json, shlex, sys
data=json.loads(sys.argv[1])
parts=[]
for key, value in data.items():
    parts.append(" -c " + shlex.quote(f"{key}={json.dumps(value)}"))
print("".join(parts))
PY
)
  fi
  cat <<EOF >&2
Unable to auto-launch a terminal for the subagent. Run the following manually:

  cd '$path'
  codex --cd '$path'$profile_arg$model_arg$sandbox_arg$approval_arg$config_args$dangerous_args "$(cat "$prompt")"
EOF
}

create_runner() {
  local path=$1
  local prompt=$2
  local log=$3
  local runner="$path/.parallelus_run_subagent.sh"
  local inner="$path/.parallelus_run_subagent_inner.sh"

  local path_q prompt_q log_q inner_q
  printf -v path_q "%q" "$path"
  printf -v prompt_q "%q" "$prompt"
  printf -v log_q "%q" "$log"
  printf -v inner_q "%q" "$inner"
  local profile_export=""
  local model_export=""
  local sandbox_export=""
  local approval_export=""
  local session_export=""
  local constraints_export=""
  local writes_export=""
  local config_export=""
  if [[ -n "${SUBAGENT_CODEX_PROFILE:-}" ]]; then
    printf -v profile_export 'export SUBAGENT_CODEX_PROFILE=%q\n' "$SUBAGENT_CODEX_PROFILE"
  fi
  if [[ -n "${SUBAGENT_CODEX_MODEL:-}" ]]; then
    printf -v model_export 'export SUBAGENT_CODEX_MODEL=%q\n' "$SUBAGENT_CODEX_MODEL"
  fi
  if [[ -n "${SUBAGENT_CODEX_SANDBOX_MODE:-}" ]]; then
    printf -v sandbox_export 'export SUBAGENT_CODEX_SANDBOX_MODE=%q\n' "$SUBAGENT_CODEX_SANDBOX_MODE"
  fi
  if [[ -n "${SUBAGENT_CODEX_APPROVAL_POLICY:-}" ]]; then
    printf -v approval_export 'export SUBAGENT_CODEX_APPROVAL_POLICY=%q\n' "$SUBAGENT_CODEX_APPROVAL_POLICY"
  fi
  if [[ -n "${SUBAGENT_CODEX_SESSION_MODE:-}" ]]; then
    printf -v session_export 'export SUBAGENT_CODEX_SESSION_MODE=%q\n' "$SUBAGENT_CODEX_SESSION_MODE"
  fi
  if [[ -n "${SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS:-}" ]]; then
    printf -v constraints_export 'export SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS=%q\n' "$SUBAGENT_CODEX_ADDITIONAL_CONSTRAINTS"
  fi
  if [[ -n "${SUBAGENT_CODEX_ALLOWED_WRITES:-}" ]]; then
    printf -v writes_export 'export SUBAGENT_CODEX_ALLOWED_WRITES=%q\n' "$SUBAGENT_CODEX_ALLOWED_WRITES"
  fi
  if [[ -n "${SUBAGENT_CODEX_CONFIG_OVERRIDES:-}" ]]; then
    printf -v config_export 'export SUBAGENT_CODEX_CONFIG_OVERRIDES=%q\n' "$SUBAGENT_CODEX_CONFIG_OVERRIDES"
  fi

  cat <<EOF >"$runner"
#!/usr/bin/env bash
set -euo pipefail
PARALLELUS_WORKDIR=$path_q
PARALLELUS_PROMPT_FILE=$prompt_q
PARALLELUS_LOG_PATH=$log_q
PARALLELUS_INNER=$inner_q

cd "\$PARALLELUS_WORKDIR"
if [[ -x .agents/adapters/python/env.sh ]]; then
  .agents/adapters/python/env.sh >/dev/null 2>&1 || .agents/adapters/python/env.sh
fi
if [[ -f .venv/bin/activate ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi
export PARALLELUS_WORKDIR
export PARALLELUS_PROMPT_FILE
export PARALLELUS_LOG_PATH
export PARALLELUS_ORIG_TERM="\${TERM:-xterm-256color}"
export PARALLELUS_SUPPRESS_TMUX_EXPORT=1
export SUBAGENT=1
if [[ -z "\${CI:-}" ]]; then
  export CI=true
fi
# Capture structured Codex session log alongside the raw TTY transcript.
export CODEX_TUI_RECORD_SESSION=1
export CODEX_TUI_SESSION_LOG_PATH="\$PARALLELUS_WORKDIR/subagent.session.jsonl"
${profile_export}${model_export}${sandbox_export}${approval_export}${session_export}${constraints_export}${writes_export}${config_export}
{
  echo "Launching Codex subagent in \$PARALLELUS_WORKDIR"
  echo "Scope file: \$PARALLELUS_PROMPT_FILE"
  echo "Log file: \$PARALLELUS_LOG_PATH"
  echo ""
} | tee -a "\$PARALLELUS_LOG_PATH"

TERM="\$PARALLELUS_ORIG_TERM" script -qa "\$PARALLELUS_LOG_PATH" "\$PARALLELUS_INNER"
EOF
  chmod +x "$runner"

  cat <<'EOF' >"$inner"
#!/usr/bin/env bash
set -euo pipefail

PROMPT_FILE="${PARALLELUS_PROMPT_FILE:?}"
WORKDIR="${PARALLELUS_WORKDIR:?}"

prompt_content="$(<"$PROMPT_FILE")"

export TERM="${PARALLELUS_ORIG_TERM:-xterm-256color}"
export SUBAGENT=1
if [[ -z "${CI:-}" ]]; then
  export CI=true
fi

args=()

if [[ -n "${SUBAGENT_CODEX_SANDBOX_MODE:-}" ]]; then
  args+=("--sandbox" "${SUBAGENT_CODEX_SANDBOX_MODE}")
else
  args+=(
    "--dangerously-bypass-approvals-and-sandbox"
    "--sandbox" "danger-full-access"
  )
fi

args+=("--cd" "$WORKDIR")

if [[ -n "${SUBAGENT_CODEX_MODEL:-}" ]]; then
  args+=("--model" "${SUBAGENT_CODEX_MODEL}")
fi

if [[ -n "${SUBAGENT_CODEX_APPROVAL_POLICY:-}" ]]; then
  args+=("--ask-for-approval" "${SUBAGENT_CODEX_APPROVAL_POLICY}")
fi

if [[ -n "${SUBAGENT_CODEX_CONFIG_OVERRIDES:-}" ]]; then
  while IFS= read -r kv; do
    args+=("-c" "$kv")
  done < <(python3 - <<'PY' "${SUBAGENT_CODEX_CONFIG_OVERRIDES}"
import json, sys
data=json.loads(sys.argv[1])
for key, value in data.items():
    print(f"{key}={json.dumps(value)}")
PY
)
fi

if [[ -n "${SUBAGENT_CODEX_PROFILE:-}" ]]; then
  args+=("--profile" "${SUBAGENT_CODEX_PROFILE}")
fi

exec codex "${args[@]}" "$prompt_content"
EOF
  chmod +x "$inner"
  echo "$runner"
}

TMUX_SESSION_NAME=""
TMUX_WINDOW_ID=""
TMUX_MAIN_PANE=""

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

resolve_tmux_context() {
  TMUX_SESSION_NAME=""
  TMUX_WINDOW_ID=""
  TMUX_MAIN_PANE=""

  if [[ -n "${TMUX:-}" ]]; then
    TMUX_SESSION_NAME=$(tmux display-message -p '#{session_name}')
    TMUX_WINDOW_ID=$(tmux display-message -p '#{window_id}')
    TMUX_MAIN_PANE=$(tmux display-message -p '#{pane_id}')
  else
    local session_line session_name
    while IFS= read -r session_line; do
      session_name=${session_line%% *}
      local attached=${session_line##* }
      if [[ "$attached" != "0" ]]; then
        TMUX_SESSION_NAME=$session_name
        break
      fi
    done < <(tmux list-sessions -F '#{session_name} #{session_attached}' 2>/dev/null)
    if [[ -z "$TMUX_SESSION_NAME" ]]; then
      TMUX_SESSION_NAME=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -n1)
    fi
    [[ -z "$TMUX_SESSION_NAME" ]] && return 1

    TMUX_WINDOW_ID=$(tmux list-windows -t "$TMUX_SESSION_NAME" -F '#{window_id} #{window_active}' 2>/dev/null | awk '$2 == "1" {print $1; exit}')
    if [[ -z "$TMUX_WINDOW_ID" ]]; then
      TMUX_WINDOW_ID=$(tmux list-windows -t "$TMUX_SESSION_NAME" -F '#{window_id}' 2>/dev/null | head -n1)
    fi
    [[ -z "$TMUX_WINDOW_ID" ]] && return 1

    TMUX_MAIN_PANE=$(tmux list-panes -t "$TMUX_WINDOW_ID" -F '#{pane_id} #{pane_active}' 2>/dev/null | awk '$2 == "1" {print $1; exit}')
    if [[ -z "$TMUX_MAIN_PANE" ]]; then
      TMUX_MAIN_PANE=$(tmux list-panes -t "$TMUX_WINDOW_ID" -F '#{pane_id}' 2>/dev/null | head -n1)
    fi
  fi

  [[ -z "$TMUX_SESSION_NAME" || -z "$TMUX_WINDOW_ID" || -z "$TMUX_MAIN_PANE" ]] && return 1
  return 0
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
  IFS=' ' read -r -a panes <<< "$panes_string"
  local pane_count=${#panes[@]}
  ((pane_count == 0)) && return 0

  local observed_ids=()
  local observed_heights=()
  while IFS=' ' read -r pane_id pane_height; do
    observed_ids+=("$pane_id")
    observed_heights+=("$pane_height")
  done < <(tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_height}')

  local valid_panes=()
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
  panes=("${valid_panes[@]}")
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

launch_iterm() {
  local path=$1
  local runner=$2
  local title=$3
  if ! command -v osascript >/dev/null 2>&1; then
    return 1
  fi
  local result
  result=$(osascript <<OSA
on run
  tell application "iTerm2"
    activate
    set newWindow to (create window with default profile)
    set windowId to id of newWindow
    tell newWindow
      set tabRef to current tab
      set attemptCount to 0
      set targetSession to missing value
      repeat while attemptCount < 40
        try
          set targetSession to (current session of tabRef)
          exit repeat
        on error
          delay 0.05
          set attemptCount to attemptCount + 1
        end try
      end repeat
      if targetSession is missing value then
        error "launch_subagent: failed to obtain current session"
      end if
      tell targetSession
        try
          set name to "$title"
        end try
        set tabTitle to "$title"
        write text "printf '\\\\e]1;" & tabTitle & "\\\\a\\\\e]2;" & tabTitle & "\\\\a'"
        set workDir to "$path"
        set runnerPath to "$runner"
        write text "cd " & quoted form of workDir
        write text "bash " & quoted form of runnerPath
        set sessionId to id of it
      end tell
    end tell
    return (sessionId as string) & "|" & (windowId as string)
  end tell
end run
OSA
  ) || return 1
  local session_id="${result%|*}"
  local window_id="${result#*|}"
  printf '{"launcher":"iterm-window","title":"%s","session_id":"%s","window_id":"%s"}\n' "$title" "$session_id" "$window_id"
}

launch_terminal() {
  local path=$1
  local runner=$2
  local title=$3
  if ! command -v osascript >/dev/null 2>&1; then
    return 1
  fi
  local result
  result=$(osascript <<OSA
on run
  try
    tell application "Terminal"
      activate
      set newTab to do script "bash -lc 'cd \"$path\" && bash \"$runner\"'"
      set custom title of newTab to "$title"
      set tabId to id of newTab
      set windowId to id of window of newTab
      return (tabId as string) & "|" & (windowId as string)
    end tell
  on error errMsg number errNum
    return "error"
  end try
end run
OSA
  ) || return 1
  if [[ "$result" == "error" ]]; then
    return 1
  fi
  local tab_id="${result%|*}"
  local window_id="${result#*|}"
  printf '{"launcher":"terminal-window","title":"%s","tab_id":"%s","window_id":"%s"}\n' "$title" "$tab_id" "$window_id"
}

launch_tmux() {
  local path=$1
  local runner=$2
  local title=$3
  if ! command -v tmux >/dev/null 2>&1; then
    return 1
  fi

  printf -v run_cmd 'bash %q' "$runner"

  local session_name window_id main_pane stack_root pane_list new_pane current_window current_pane
  current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
  current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"

  if resolve_tmux_context; then
    session_name="$TMUX_SESSION_NAME"
    window_id="$TMUX_WINDOW_ID"
    main_pane="$TMUX_MAIN_PANE"
  else
    session_name=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -n1)
    [[ -z "$session_name" ]] && return 1
    window_id=$(tmux list-windows -t "$session_name" -F '#{window_id}' 2>/dev/null | head -n1)
    main_pane=$(tmux list-panes -t "$window_id" -F '#{pane_id}' 2>/dev/null | head -n1)
  fi
  [[ -z "$window_id" || -z "$main_pane" ]] && return 1

  stack_root=$(get_window_option "$window_id" @parallelus_subagent_stack_root)
  pane_list=$(get_window_option "$window_id" @parallelus_subagent_panes)

  if [[ -n "$pane_list" ]]; then
    local existing_ids
    existing_ids=$(tmux list-panes -t "$window_id" -F '#{pane_id}')
    local sanitized=()
    local pane
    for pane in $pane_list; do
      if printf '%s\n' "$existing_ids" | grep -Fxq "$pane"; then
        sanitized+=("$pane")
      fi
    done
    if (( ${#sanitized[@]} == 0 )); then
      pane_list=""
      stack_root=""
      unset_window_option "$window_id" @parallelus_subagent_panes
      unset_window_option "$window_id" @parallelus_subagent_stack_root
    else
      pane_list="${sanitized[*]}"
      stack_root="${sanitized[0]}"
      set_window_option "$window_id" @parallelus_subagent_panes "$pane_list"
      set_window_option "$window_id" @parallelus_subagent_stack_root "$stack_root"
    fi
  fi

  if [[ -z "$stack_root" || -z "$pane_list" ]]; then
    enable_pane_labels "$window_id"
    new_pane=$(tmux split-window -h -p 50 -d -t "$main_pane" -P -F '#{pane_id}' -c "$path" "$run_cmd") || return 1
    stack_root="$new_pane"
    pane_list="$new_pane"
    set_window_option "$window_id" @parallelus_subagent_stack_root "$stack_root"
    set_window_option "$window_id" @parallelus_subagent_panes "$pane_list"
  else
    IFS=' ' read -r -a panes <<< "$pane_list"
    local last_index=$(( ${#panes[@]} - 1 ))
    local last_pane="${panes[$last_index]}"
    new_pane=$(tmux split-window -v -d -t "$last_pane" -P -F '#{pane_id}' -c "$path" "$run_cmd") || return 1
    panes+=("$new_pane")
    pane_list="${panes[*]}"
    set_window_option "$window_id" @parallelus_subagent_panes "$pane_list"
  fi

  if [[ -z "${new_pane:-}" ]]; then
    if [[ -n "$pane_list" ]]; then
      IFS=' ' read -r -a panes <<< "$pane_list"
      new_pane="${panes[$(( ${#panes[@]} - 1 ))]}"
    fi
  fi

  rebalance_subagent_column "$window_id" "$pane_list"

  # Debug cleanup placeholder - removed after verification
  # tmux display-message "DEBUG new_pane=$new_pane"

  tmux select-pane -T "$title" -t "$new_pane" >/dev/null 2>&1 || true
  tmux select-pane -t "$main_pane" >/dev/null 2>&1 || true

  if [[ -n "$current_window" ]]; then
    tmux select-window -t "$current_window" >/dev/null 2>&1 || true
  fi
  if [[ -n "$current_pane" ]]; then
    tmux select-pane -t "$current_pane" >/dev/null 2>&1 || true
  fi

  printf '{"launcher":"tmux-pane","title":"%s","window_id":"%s","pane_id":"%s"}\n' "$title" "$window_id" "$new_pane"
  return 0
}

main() {
  local launcher="auto"
  local path=""
  local prompt=""
  local log=""
  local type=""
  local title=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --launcher) launcher=$2; shift 2;;
      --path) path=$2; shift 2;;
      --prompt) prompt=$2; shift 2;;
      --log) log=$2; shift 2;;
      --type) type=$2; shift 2;;
      --title) title=$2; shift 2;;
      --help)
        cat <<'USAGE'
Usage: launch_subagent.sh --path DIR --prompt FILE [--log FILE] [--launcher MODE]
Launchers: auto, iterm-window, terminal-window, tmux, manual
USAGE
        exit 0;;
      *) echo "launch_subagent: unknown option $1" >&2; exit 1;;
    esac
  done

  if [[ -z "$path" || -z "$prompt" ]]; then
    echo "launch_subagent: --path and --prompt are required" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$log")"
  local runner
  runner=$(create_runner "$path" "$prompt" "${log:-$path/subagent.log}")

  local handle=""

  case $launcher in
    iterm-window)
      handle=$(launch_iterm "$path" "$runner" "$title") || handle=""
      [[ -z "$handle" ]] && print_manual "$path" "$prompt" || printf '%s\n' "$handle" ;;
    terminal-window)
      handle=$(launch_terminal "$path" "$runner" "$title") || handle=""
      [[ -z "$handle" ]] && print_manual "$path" "$prompt" || printf '%s\n' "$handle" ;;
    tmux)
      handle=$(launch_tmux "$path" "$runner" "$title") || handle=""
      [[ -z "$handle" ]] && print_manual "$path" "$prompt" || printf '%s\n' "$handle" ;;
    manual)
      print_manual "$path" "$prompt" ;;
    auto|*)
      handle=$(launch_tmux "$path" "$runner" "$title")
      if [[ -n "$handle" ]]; then
        printf '%s\n' "$handle"
      else
        print_manual "$path" "$prompt"
      fi ;;
  esac
}

main "$@"
