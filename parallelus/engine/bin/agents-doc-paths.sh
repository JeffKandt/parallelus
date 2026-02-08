#!/usr/bin/env bash

# Shared docs-path helpers for shell scripts.

parallelus_branch_notebooks_root() {
  local repo_root="$1"
  printf '%s/docs/branches\n' "${repo_root%/}"
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

parallelus_branch_plan_read_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  parallelus_branch_plan_write_path "$repo_root" "$slugged_branch"
}

parallelus_branch_progress_read_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  parallelus_branch_progress_write_path "$repo_root" "$slugged_branch"
}

parallelus_reviews_write_dir() {
  local repo_root="$1"
  printf '%s/docs/parallelus/reviews\n' "${repo_root%/}"
}

parallelus_reviews_read_dirs() {
  local repo_root="$1"
  parallelus_reviews_write_dir "$repo_root"
}

parallelus_self_improvement_write_root() {
  local repo_root="$1"
  printf '%s/docs/parallelus/self-improvement\n' "${repo_root%/}"
}

parallelus_self_improvement_read_roots() {
  local repo_root="$1"
  parallelus_self_improvement_write_root "$repo_root"
}

parallelus_marker_write_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  printf '%s/markers/%s.json\n' "$(parallelus_self_improvement_write_root "$repo_root")" "$slugged_branch"
}

parallelus_marker_read_path() {
  local repo_root="$1"
  local slugged_branch="$2"
  parallelus_marker_write_path "$repo_root" "$slugged_branch"
}
