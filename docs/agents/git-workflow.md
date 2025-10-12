# Git Workflow & Branch Hygiene

This guide covers repository detection, feature-branch guardrails, archival, and
merge closure workflows.

## 1. Repository Mode Detection
Run `make read_bootstrap` (or `.agents/bin/agents-detect`) from the repo root.
The helper emits `KEY=VAL` pairs suitable for `eval`, plus guidance on stderr.

Detection order:
1. If `origin/HEAD` (or `${BASE_REMOTE}/HEAD`) exists, use it to derive the base
   branch.
2. Otherwise fall back to `DEFAULT_BASE` (from `.agents/agentrc`), then
   `main`, `master`, finally the current branch.

Outputs include:
- `REPO_MODE` — `remote-connected` or `detached`.
- `BASE_BRANCH` — default branching point for new work.
- `UNMERGED_REMOTE` / `UNMERGED_LOCAL` — comma-separated lists of branches not
  merged into the base (excluding `archive/**`, `dependabot/**`, `renovate/**`).
- `ORPHANED_NOTEBOOKS` — plan/progress files lingering outside active work.

Immediately open the active branch plan and progress notebooks (`docs/plans/<branch>.md`, `docs/progress/<branch>.md`) so your status summary reflects the latest objectives, TODOs, and blockers noted by previous turns. List the most recent session directories (`ls -1 sessions/ | tail -5`) and seed a fresh `make start_session` if the top entry predates today.

When unmerged branches are reported, pause and choose whether to merge, archive,
prune, or leave as-is. Do not auto-resolve without user direction.

## 2. Feature Branch Creation
Use `make bootstrap slug=<slug>` (wraps `.agents/bin/agents-ensure-feature`).
The helper:
- Refuses to run with a dirty working tree.
- Creates or switches to `feature/<slug>`.
- Scaffolds matching plan/progress notebooks under `docs/plans/` and
  `docs/progress/`.
- Prints status to stderr so the calling shell remains quiet unless there is an
  error.

`slug` should be lower-case, dash-separated. Use `AUTO_BRANCH_SLUG` to pre-seed a
slug across sessions if needed.

## 3. Branch Management & Archival
When `agents-detect` lists unmerged branches, present them to the maintainer and
ask whether to merge or archive. Two main flows:

### Merge (use the helper)
- Run `make merge slug=<slug>` — this wraps pre-merge checks, installs the git
  guard hook, runs `make ci`, and performs a `--no-ff` merge into the base
  branch.
- The helper refuses to run if branch notebooks or progress logs still exist,
  or if the working tree is dirty.

Do **not** run `git merge` directly; the helper is the enforcement mechanism for
the merge-and-close checklist.

Consider merging when:
- Work is complete and aligned with current priorities.
- All tests/lint pass and documentation is current.
- Code review has been completed (if applicable).

### Archive
Use `make archive b=<branch>` (wraps `.agents/bin/agents-archive-branch`):
1. Renames the branch to `${ARCHIVE_NAMESPACE}/...` locally.
2. Pushes the archived branch and removes the original remote ref.
3. Runs `git fetch -p` to prune.

Archived branches remain accessible via `git log archive/<name>` but disappear
from unmerged reports.

Consider archiving when:
- The work was exploratory or requirements have changed.
- The branch contains incomplete work unlikely to finish.
- A more current branch supersedes the effort.

## 4. Branch Discovery & PR Workflows
Helpful commands when triaging remote work:
```bash
git fetch origin --all
git branch -r | grep -E '(pull|pr|codex|feature)'
git show-branch origin/<branch>
git checkout -b pr-<id> origin/<branch>
```
Recognised remote naming patterns include `origin/codex/*`, `origin/feature/*`,
`origin/pull/<id>`, and `origin/<id>`.

## 5. Merge & Close Checklist
Run this checklist whenever the user requests a merge (even casually):
1. Confirm plan/progress notebooks are up to date and committed.
2. Fold notebook updates into canonical docs (`docs/PLAN.md`, `docs/PROGRESS.md`
   via `scripts/stitch_progress_logs.py`) while still on the feature branch.
3. Run validation inside the project venv (`pytest -m "not slow"`, `ruff
   check`, `black --check`).
4. Align local branch name with PR slug before merging exported work.
5. Merge or archive per maintainer guidance; delete notebooks/sessions after
   their content lands.
6. Treat the workspace as back in Recon & Planning once cleanup completes.

## 6. Branch Notebooks & Session Logs
- Never create notebooks/session logs during merge operations; they belong on
  the feature branch.
- If orphaned notebooks are detected on `main`, remove them immediately or fold
  them into canonical docs.
- Always commit branch notebooks and session logs before merging to prevent
  orphaned state.

## 7. Commit Hygiene
- Prefer small narrative commits pairing code with plan/progress updates.
- Subject format: `feat|fix|refactor: <summary>`.
- Doc-only checkpoints: `docs: checkpoint – <summary>`.

## 8. Syncing with the Agent Process Template
- Keep a dedicated `agent-process-template` repository as the upstream source of truth.
- Add it as an extra remote when working in downstream projects:
  ```bash
  git remote add agent-template git@github.com:<org>/agent-process-template.git
  ```
- After validating process changes on a feature branch (e.g., via `make process-e2e-test`), cherry-pick or rebase those commits onto the template repo and open a PR there.
- Tag template releases so downstream projects can pull the update with `git fetch agent-template --tags` followed by a merge or rebase.
- Document the sync step in your branch plan so reviewers know when the template was updated.

Staying disciplined keeps reviewers oriented and avoids merge conflicts.
