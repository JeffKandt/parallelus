#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TMP_REPO="$(mktemp -d)"
BARE_REMOTE="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_REPO" "$BARE_REMOTE"
}
trap cleanup EXIT

cp -R "$ROOT/.agents" "$TMP_REPO/.agents"
mkdir -p "$TMP_REPO/docs" "$TMP_REPO/sessions"

(
  cd "$TMP_REPO"
  git init -q
  git config user.name "Agents Smoke"
  git config user.email "smoke@example.com"
  echo "smoke" > README.md
  git add README.md
  git commit -q -m "init"

  git init -q --bare "$BARE_REMOTE"
  git remote add origin "$BARE_REMOTE"
  git branch -m main
  git push -q origin main

  # Detection should report remote-connected and base branch main
  DETECT_OUTPUT=$(.agents/bin/agents-detect)
  echo "$DETECT_OUTPUT" | grep -q "REPO_MODE=remote-connected"
  echo "$DETECT_OUTPUT" | grep -q "BASE_BRANCH=main"

  # Create feature branch and ensure plan/progress notebooks are scaffolded
  .agents/bin/agents-ensure-feature smoke
  test -d docs/plans
  test -f docs/plans/feature-smoke.md
  test -f docs/progress/feature-smoke.md

  # Start a session and capture exports
  eval "$(.agents/bin/agents-session-start)"
  test -n "${SESSION_ID:-}"
  test -d "${SESSION_DIR:-}"

  # Record a checkpoint
  AGENTS_RETRO_SKIP_VALIDATE=1 .agents/bin/agents-turn-end "smoke checkpoint"
  grep -q "smoke checkpoint" docs/progress/feature-smoke.md

  # Archive the branch and ensure ref renamed locally
  .agents/bin/agents-archive-branch feature/smoke | grep -q "archive/smoke"
  git show-ref --verify --quiet refs/heads/archive/smoke
)

printf "agents smoke test passed\n"
