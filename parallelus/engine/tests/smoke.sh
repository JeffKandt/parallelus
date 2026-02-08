#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TMP_REPO="$(mktemp -d)"
BARE_REMOTE="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_REPO" "$BARE_REMOTE"
}
trap cleanup EXIT

mkdir -p "$TMP_REPO/parallelus"
cp -R "$ROOT/parallelus/engine" "$TMP_REPO/parallelus/engine"
mkdir -p "$TMP_REPO/docs" "$TMP_REPO/sessions"

(
  cd "$TMP_REPO"
  git init -q
  git config user.name "Agents Smoke"
  git config user.email "smoke@example.com"
  echo "smoke" > README.md
  cat > Makefile <<'MAKE'
include parallelus/engine/make/agents.mk
MAKE
  git add README.md
  git commit -q -m "init"

  git init -q --bare "$BARE_REMOTE"
  git remote add origin "$BARE_REMOTE"
  git branch -m main
  git push -q origin main

  # Detection should report remote-connected and base branch main
  DETECT_OUTPUT=$(parallelus/engine/bin/agents-detect)
  echo "$DETECT_OUTPUT" | grep -q "REPO_MODE=remote-connected"
  echo "$DETECT_OUTPUT" | grep -q "BASE_BRANCH=main"

  # Create feature branch and ensure plan/progress notebooks are scaffolded
  parallelus/engine/bin/agents-ensure-feature smoke
  test -d docs/branches/feature-smoke
  test -f docs/branches/feature-smoke/PLAN.md
  test -f docs/branches/feature-smoke/PROGRESS.md

  # Start a session and capture exports
  eval "$(parallelus/engine/bin/agents-session-start)"
  test -n "${SESSION_ID:-}"
  test -d "${SESSION_DIR:-}"
  session_dir_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${SESSION_DIR:-}")"
  expected_sessions_root="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$TMP_REPO/.parallelus/sessions")"
  case "$session_dir_real" in
    "$expected_sessions_root/"*) ;;
    *)
      echo "expected SESSION_DIR under .parallelus/sessions, got: ${SESSION_DIR:-}" >&2
      exit 1
      ;;
  esac

  # Record a checkpoint
  AGENTS_RETRO_SKIP_VALIDATE=1 parallelus/engine/bin/agents-turn-end "smoke checkpoint"
  grep -q "smoke checkpoint" docs/branches/feature-smoke/PROGRESS.md

  # Archive the branch and ensure ref renamed locally
  parallelus/engine/bin/agents-archive-branch feature/smoke | grep -q "archive/smoke"
  git show-ref --verify --quiet refs/heads/archive/smoke
)

printf "agents smoke test passed\n"
