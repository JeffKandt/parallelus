# Git Workflow & Branch Hygiene

This guide covers repository detection, feature-branch guardrails, archival, and
merge closure workflows.

## Communication Principles
- Relay outcomes, not commands. When the user asks for work, confirm the intent
  and respond with what you will do ("I'll open a feature branch named ..."),
  not the shell commands that implement it.
- Proactively offer status recaps in plain language so the user can make
  decisions without touching the CLI.
- If the user explicitly requests command-level insight, confirm that they want
  to execute it themselves; otherwise assume you own the operation and simply
  describe progress and results.

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

If the repository includes `.agents/custom/README.md`, read it now and incorporate any project-specific expectations (extra checks, restricted paths, custom adapters) into your plan. Treat those instructions as an extension of this manual.

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

During Recon on `main`, capture near-term ideas in the untracked queue:
`make queue_init` creates `.agents/queue/next-branch.md`, `make queue_show`
prints it, and `make queue_pull` (run immediately after bootstrapping) appends
notes into the new branch plan and project backlog before clearing the scratch
file. The queue template provides two sections:

- `## Next Feature` — bullets earmarked for the upcoming branch plan.
- `## Project Backlog` — bullets (including any `TODO:` notes) appended to
  `docs/PLAN.md` under “Next Focus Areas”. Lines starting with `TODO:` are
  stored verbatim, minus the prefix, so feel free to jot ideas quickly.

Never keep long-term state in the queue; treat it as a temporary inbox and run
`make queue_pull` as soon as the corresponding branch exists.

## 3. Branch Management & Archival
When `agents-detect` lists unmerged branches, present them to the maintainer and
ask whether to merge or archive. Two main flows:

### Merge (use the helper)
- Run `make merge slug=<slug>` — this wraps pre-merge checks, installs the git
  guard hooks, runs `make ci`, and performs a `--no-ff` merge into the base
  branch. The helper also exports `AGENTS_MERGE_SKIP_HOOK_CI=1` so the
  `pre-merge-commit` hook knows tests already passed.
- Merge requests now require a senior-architect review stored in
  `docs/reviews/feature-<slug>-<date>.md`. The report must include
  `Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`, and `Decision: approved`;
  any finding marked `Severity: Blocker` or `Severity: High` blocks the merge
  until addressed, and remaining findings must be acknowledged via
  `AGENTS_MERGE_ACK_REVIEW=1`.
- Execute the senior review via a **synchronous subagent session** using the
  updated `senior_architect` role prompt; populate the configuration header
  (model, sandbox, approval mode) before launch so the review artifact records
  provenance.
- Set `AGENTS_MERGE_FORCE=1` when you must override the guardrail in an
  emergency (document the reason in the progress log), and optionally specify a
  different review path via `AGENTS_MERGE_REVIEW_FILE=...`.
- The helper refuses to run when any branch notebooks are still present (for
  example `docs/plans/feature-*.md` or `docs/progress/feature-*.md`). Before
  deleting them, run `.agents/bin/fold-progress apply` so every timestamped
  entry lands in the canonical docs verbatim—summaries or rewritten blurbs are
  not allowed. The helper also blocks on a dirty working tree.

Do **not** run `git merge` directly; the helper is the enforcement mechanism for
the merge-and-close checklist. If someone tries it anyway, the managed
`pre-merge-commit` hook re-runs `make ci` (unless the helper signalled success)
and blocks the merge when branch notebooks remain.

Consider merging when:
- Work is complete and aligned with current priorities.
- All tests/lint pass and documentation is current.
- Code review has been completed (if applicable).

### Managed hooks
- `install-hooks` (invoked by `make bootstrap`, `make merge`, and the deploy
  script) syncs every file in `.agents/hooks/` into `.git/hooks/`.
- Existing `.git/hooks/*` are preserved as `.agents/hooks/<name>.predeploy.<ts>.bak`
  during overlay, and `install-hooks` creates `.git/hooks/<name>.predeploy.<ts>.bak`
  before rewriting a hook so local customisations can be merged.
- `pre-commit` blocks direct commits to the base branch (override with
  `AGENTS_ALLOW_MAIN_COMMIT=1`) and reminds feature-branch contributors to
  update plan/progress notebooks whenever other files are staged.
- `pre-merge-commit` blocks merges when any branch notebooks linger, CI fails,
  the senior review is missing/incomplete (override with `AGENTS_MERGE_FORCE=1`
  and optionally `AGENTS_MERGE_REVIEW_FILE=...`; acknowledge lower-severity
  findings with `AGENTS_MERGE_ACK_REVIEW=1`), or the latest retrospective report
  for the branch marker has not been committed.
- `post-merge` emits a reminder to rerun `make read_bootstrap` and return to the
  Recon phase on the base branch.
- Overlay deployments prepend an **Overlay Notice** to `AGENTS.md`; audit every
  `.bak` backup produced by the installer, merge or resolve conflicting
  instructions, and document the reconciliation before removing the notice.

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
   via `.agents/bin/fold-progress apply`) while still on the feature branch.
3. Run validation inside the project venv (`pytest -m "not slow"`, `ruff
   check`, `black --check`).
4. Align local branch name with PR slug before merging exported work.
5. Run the retrospective workflow: consult `docs/self-improvement/markers/` to
   confirm the latest marker, launch the Retrospective Auditor, and commit the
   resulting JSON report under `docs/self-improvement/reports/` before merging.
6. Merge or archive per maintainer guidance; delete notebooks/sessions after
   their content lands.
7. Treat the workspace as back in Recon & Planning once cleanup completes.

If you need to make doc-only touch-ups after the senior review is captured, the
merge guardrail now allows additional post-review commits so long as **every**
changed file lives under these benign paths:

- `docs/guardrails/runs/`
- `docs/reviews/`
- `docs/PLAN.md`, `docs/PROGRESS.md`
- `docs/plans/` and `docs/progress/`
- `docs/agents/`

Any other modifications still require rerunning the senior architect review on
the final commit before merging.

## 6. Branch Notebooks & Session Logs
- Never create notebooks/session logs during merge operations; they belong on
  the feature branch.
- If orphaned notebooks are detected on `main`, remove them immediately or fold
  them into canonical docs.
- When folding progress logs, preserve every entry verbatim—run
  `.agents/bin/fold-progress apply` and only edit notebook text before folding
  (never summarise directly inside `docs/PROGRESS.md`).
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
