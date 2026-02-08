#!/usr/bin/env bash

# Shared session-path resolution helpers for shell scripts.

parallelus_sessions_write_root() {
  local repo_root="$1"
  printf '%s/.parallelus/sessions\n' "${repo_root%/}"
}

parallelus_normalize_repo_path() {
  local repo_root="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    return 0
  fi

  if [[ "$value" == /* ]]; then
    printf '%s\n' "${value%/}"
    return 0
  fi

  local rel="${value#./}"
  printf '%s/%s\n' "${repo_root%/}" "${rel%/}"
}

parallelus_sessions_read_roots() {
  local repo_root="$1"
  local configured_root="${2:-}"
  local -a candidates=()
  local emitted=$'\n'
  local candidate

  candidates+=("$(parallelus_sessions_write_root "$repo_root")")

  if [[ -n "$configured_root" ]]; then
    candidates+=("$(parallelus_normalize_repo_path "$repo_root" "$configured_root")")
  fi

  for candidate in "${candidates[@]}"; do
    candidate="${candidate%/}"
    [[ -z "$candidate" ]] && continue
    if [[ "$emitted" == *$'\n'"$candidate"$'\n'* ]]; then
      continue
    fi
    emitted+="$candidate"$'\n'
    printf '%s\n' "$candidate"
  done
}

parallelus_resolve_session_dir() {
  local repo_root="$1"
  local session_id="$2"
  local configured_root="${3:-}"
  local root

  while IFS= read -r root; do
    if [[ -d "$root/$session_id" ]]; then
      printf '%s\n' "$root/$session_id"
      return 0
    fi
  done < <(parallelus_sessions_read_roots "$repo_root" "$configured_root")

  printf '%s/%s\n' "$(parallelus_sessions_write_root "$repo_root")" "$session_id"
}
