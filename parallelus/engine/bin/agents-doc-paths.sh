#!/usr/bin/env bash

# Shared docs-path helpers for shell scripts.

parallelus_branch_notebooks_root() {
  local repo_root="$1"
  printf '%s/docs/branches\n' "${repo_root%/}"
}

parallelus_legacy_plan_dir() {
  local repo_root="$1"
  printf '%s/docs/plans\n' "${repo_root%/}"
}

parallelus_legacy_progress_dir() {
  local repo_root="$1"
  printf '%s/docs/progress\n' "${repo_root%/}"
}

parallelus_branch_plan_write_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  printf '%s/%s/PLAN.md\n' "$(parallelus_branch_notebooks_root "$repo_root")" "$slugged_branch"
}

parallelus_branch_progress_write_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  printf '%s/%s/PROGRESS.md\n' "$(parallelus_branch_notebooks_root "$repo_root")" "$slugged_branch"
}

parallelus_branch_plan_legacy_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  printf '%s/%s.md\n' "$(parallelus_legacy_plan_dir "$repo_root")" "$slugged_branch"
}

parallelus_branch_progress_legacy_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  printf '%s/%s.md\n' "$(parallelus_legacy_progress_dir "$repo_root")" "$slugged_branch"
}

parallelus_branch_plan_read_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  local canonical legacy
  canonical="$(parallelus_branch_plan_write_path "$repo_root" "$slugged_branch")"
  legacy="$(parallelus_branch_plan_legacy_path "$repo_root" "$slugged_branch")"
  if [[ -f "$canonical" ]]; then
    printf '%s\n' "$canonical"
  elif [[ -f "$legacy" ]]; then
    printf '%s\n' "$legacy"
  else
    printf '%s\n' "$canonical"
  fi
}

parallelus_branch_progress_read_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  local canonical legacy
  canonical="$(parallelus_branch_progress_write_path "$repo_root" "$slugged_branch")"
  legacy="$(parallelus_branch_progress_legacy_path "$repo_root" "$slugged_branch")"
  if [[ -f "$canonical" ]]; then
    printf '%s\n' "$canonical"
  elif [[ -f "$legacy" ]]; then
    printf '%s\n' "$legacy"
  else
    printf '%s\n' "$canonical"
  fi
}

parallelus_reviews_write_dir() {
  local repo_root="$1"
  printf '%s/docs/parallelus/reviews\n' "${repo_root%/}"
}

parallelus_reviews_legacy_dir() {
  local repo_root="$1"
  printf '%s/docs/reviews\n' "${repo_root%/}"
}

parallelus_reviews_read_dirs() {
  local repo_root="$1"
  local -a candidates=()
  local emitted=$'\n'
  local candidate

  candidates+=("$(parallelus_reviews_write_dir "$repo_root")")
  candidates+=("$(parallelus_reviews_legacy_dir "$repo_root")")

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

parallelus_self_improvement_write_root() {
  local repo_root="$1"
  printf '%s/docs/parallelus/self-improvement\n' "${repo_root%/}"
}

parallelus_self_improvement_legacy_root() {
  local repo_root="$1"
  printf '%s/docs/self-improvement\n' "${repo_root%/}"
}

parallelus_self_improvement_read_roots() {
  local repo_root="$1"
  local -a candidates=()
  local emitted=$'\n'
  local candidate

  candidates+=("$(parallelus_self_improvement_write_root "$repo_root")")
  candidates+=("$(parallelus_self_improvement_legacy_root "$repo_root")")

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

parallelus_marker_write_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  printf '%s/markers/%s.json\n' "$(parallelus_self_improvement_write_root "$repo_root")" "$slugged_branch"
}

parallelus_marker_read_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  local root path
  while IFS= read -r root; do
    path="$root/markers/$slugged_branch.json"
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done < <(parallelus_self_improvement_read_roots "$repo_root")
  parallelus_marker_write_path "$repo_root" "$slugged_branch"
}
