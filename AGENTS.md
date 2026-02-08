# Parallelus Agent Core Guardrails

This document is mandatory reading at the start of every session. Record in the
branch progress notebook that you reviewed it before running any project
commands beyond `make read_bootstrap`.

You must also read `PROJECT_AGENTS.md` (or `AGENTS.project.md`) at the start of
every session if it exists and record that acknowledgement in the progress log.

> **Project-specific guardrails:** Do **not** customize this file directly.
> Place project-specific policies in `PROJECT_AGENTS.md` (or `AGENTS.project.md`)
> and keep this file upstream-managed so upgrades can safely overwrite it.

## 1. Purpose & Usage
- Internalise these guardrails during Recon & Planning; they apply to every
  turn regardless of scope.
- Every mitigation must become a durable, versioned artifact that ships with the
  repository (e.g. `parallelus/engine` tooling, `parallelus/manuals` runbooks, automated setup,
  tests/linters). Branch-only notes, local shell hacks, or tribal knowledge are
  not acceptable mitigations.
- Operational manuals live under `parallelus/manuals/manuals/`. Only consult them when
  a gate below fires. Do **not** pre-emptively open every manual; wait until a
  gate is triggered, then read just the manual(s) required for that task and
  capture the acknowledgement in the progress log before proceeding.
- Users delegate intent; you own execution, cleanup, and reporting. Never assume
  the user will run shell commands on your behalf.
- Communicate in terms of outcomes, not implementation details. When the user
  requests an action, acknowledge it, confirm any missing context, and explain
  what you will do. Do not instruct the user to run commands; translate their
  intent into concrete steps you perform and report back in plain language.
- If the repository provides `parallelus/engine/custom/README.md`, read **that file** once
  before deviating from the defaults. Only follow links or manuals it explicitly
  references; do not sweep the rest of `parallelus/engine/` unless the custom README tells
  you to. Treat those project notes as extensions layered on top of Parallelus
  core and integrate them alongside the standard guardrails.
- If this file starts with an **Overlay Notice**, reconcile every `.bak`
  backup created during deployment, merge conflicting instructions into the new
  guardrails, document the outcome in the branch plan, then remove the notice.

## 2. Session Cadence & Core Checklists

### Recon & Planning (read-only)
- Start every session with `eval "$(make start_session)"`, which enables session
  logging and runs `make read_bootstrap`. Direct `make read_bootstrap` is blocked
  unless logging is active. Report repo mode, branch, remotes, and
  orphaned notebooks before continuing. Echo the complete branch snapshot table
  (names plus action guidance) back to the user—do not elide or summarise the
  entries.
- Open the active plan and progress notebooks
  (`docs/branches/<slug>/PLAN.md`, `docs/branches/<slug>/PROGRESS.md`) or
  confirm they do not exist yet (legacy pre-migration notebooks may still exist
  under `docs/plans/<branch>.md` and `docs/progress/<branch>.md`).
- If the tmux environment changed (new machine, updated launcher), reread
  `parallelus/manuals/manuals/tmux-setup.md` before continuing to confirm sockets and
  binaries align with Parallelus expectations.
- List recent `sessions/` entries. If none match today (2025-10-12), seed a new
  session with `SESSION_PROMPT="..." eval "$(make start_session)"` **before** leaving
  Recon & Planning.
- Inspect repo state, answer questions, plan next moves. Do not edit tracked
  files or run bootstrap helpers during this phase.

### Transition to Editing (trigger once you intend to modify tracked files)
1. Ensure the Recon checklist above is complete.
2. Create or switch to a feature branch via `make bootstrap slug=<slug>`; never
   edit directly on `main`.
3. Export `SESSION_PROMPT` (optional) and run `eval "$(make start_session)"` to capture
   turn context. Session logs are mandatory; `make start_session` enables
   `./.parallelus/sessions/<ID>/console.log` logging by default and
   `make turn_end` will fail if the log is empty.
4. Update the branch plan/progress notebooks with current objectives before
   editing code or docs.
5. Run required environment diagnostics (see Operational Gates for details) and
   log results in the progress notebook.
6. Commit the bootstrap artifacts once the branch is staged for real work.
  (Bootstrap syncs managed git hooks into `.git/hooks`; do not delete them.)

### Active Execution & Validation
- Keep audible alerts active: fire `parallelus/engine/bin/agents-alert` **before** any
  approval pause and after each work block (>5 s) before handing control back.
- Update branch plan/progress notebooks after meaningful work units. Treat
  `➜ checkpoint` markers as mandatory commit points.
- Expect the managed `pre-commit` hook to remind you about plan/progress updates
  when committing feature work; treat warnings as action items, not noise.
- Before launching a senior architect review, ensure the canonical progress log
  (`docs/PROGRESS.md`) contains a concrete summary—no placeholders, TODO markers,
  or "pending" text.
- Use `parallelus/engine/bin/agents-rebase-continue` (aliases `git-rebase-continue` / `grc`)
  to resume rebases without triggering interactive editors.
- Once a senior architect review is captured, avoid history rewrites (rebase, amend,
  reset) on that branch. Apply follow-up commits instead; doc-only commits are
  automatically tolerated by the merge guardrails.
- Direct commits to the base branch are blocked; set `AGENTS_ALLOW_MAIN_COMMIT=1`
  only for emergencies, and record the rationale in the progress log.
- When subagents are active, maintain the monitor loop per the Subagent manual.
- Stay within the requested scope; defer speculative refactors unless directed.
- Senior architect review is mandatory before merging: capture the signed-off
  report under `docs/parallelus/reviews/<branch>-<date>.md`
  (`Reviewed-Branch`,
  `Reviewed-Commit`, `Reviewed-On`, `Decision: approved`, no `Severity:
  Blocker/High`, and acknowledge other findings via
  `AGENTS_MERGE_ACK_REVIEW`). Default profile values live in
  the prompt’s YAML front matter (defaults defined at the top of
  `parallelus/engine/prompts/agent_roles/senior_architect.md`).
- Before launching a senior architect review, confirm the latest review file
  already references the current `HEAD`; the launcher now refuses to rerun when
  the review is current or only doc-only tweaks have landed since the last
  approval.
- Capture or refresh the senior architect review *after* the final commit on
  the feature branch; if additional commits are required, regenerate the review
  so `Reviewed-Commit` matches `HEAD` before attempting to merge.
- Launch the senior architect review subagent **only after** staging/committing
  the work under review and pushing it to the feature branch; reviews operate on
  the committed state, not local working tree changes.
- Run the senior architect review via the provided subagent launcher (see
  `parallelus/manuals/manuals/senior-architect.md`) so the canonical prompt executes
  in an isolated tmux pane.

### Turn-End & Session Wrap
- If a new request arrives after the previous conversation has been idle, run
  `make turn_end m="..."` first to close the earlier turn before starting new
  work.
- Use `make turn_end m="summary"` to append structured updates before replying
  on an active turn; the helper updates progress logs, plan notebooks, session
  summary, and `meta.json` in one step.
- Continuous-improvement audits are temporarily suspended at merge time; if you
  must bypass the retrospective check, set `AGENTS_MERGE_SKIP_RETRO=1` along with
  `AGENTS_MERGE_SKIP_RETRO_REASON="<why>"`. The merge helper records a skip log under
  `.parallelus/retro-skip-logs/` (next to the repo) for follow-up, and a TODO exists to
  reinstate the guardrail.
- Before folding branch notebooks into canonical logs, run
  `make turn_end m="summary"` (or another checkpoint note) so the latest marker
  lands in `docs/parallelus/self-improvement/markers/` (legacy
  `docs/self-improvement/markers/` is still read during migration); the folding
  helper now enforces this requirement.
- Ensure progress logs capture the latest state, session metadata is current,
  and the working tree is either clean or holds only intentional changes noted
  in the progress log. Avoid committing unless the maintainer instructs you to.
- Do not merge or archive unless the maintainer explicitly asks.
- Before the senior architect review, launch the Continuous Improvement Auditor
  prompt (see `parallelus/engine/prompts/agent_roles/continuous_improvement_auditor.md`) using the latest
  marker. The auditor responds with JSON; save it to
  `docs/parallelus/self-improvement/reports/<branch>--<marker-timestamp>.json`
  and carry TODOs into the branch plan. Marker + failures + audit must run
  sequentially (never in parallel). For headless/manual-launch environments,
  prefer `make senior_review_preflight_run ARGS="--auto-clean-stale"` so
  stale `awaiting_manual_launch` review entries are auto-cleaned when no
  sandbox process appears active; use `make senior_review_preflight
  ARGS="--auto-clean-stale"` for launch-only behavior.

## 3. Command Quick Reference
- `make read_bootstrap` – detect repo mode, base branch, branch hygiene.
- `make bootstrap slug=<slug>` – create/switch feature branch and seed notebooks.
- `SESSION_PROMPT="..." eval "$(make start_session)"` – initialise session artifacts and logging.
- `make turn_end m="summary"` – checkpoint plan/progress + session meta.
- `make ci` – run lint, tests, and smoke suite inside the configured adapters.
- `make senior_review_preflight` – run serialized retrospective preflight and launch senior review.
- `make senior_review_preflight_run` – run preflight + manual-launch fallback + harvest/cleanup wrapper (preferred for headless/manual-launch setups).
- `parallelus/engine/bin/agents-rebase-continue` – continue a rebase without invoking an interactive editor.

## 4. Operational Gates (Read-on-Trigger Manuals)
- **Subagents:** Before launching or monitoring subagents (e.g.
  `make monitor_subagents`, `subagent_manager ...`), read
  `parallelus/manuals/subagent-session-orchestration.md` and log the acknowledgement.
  Senior architect reviews are executed inside subagents, so when one is
  requested you must review this manual (even if you've read it earlier in the
  session) and record the acknowledgement in the progress log before continuing.
  Note: subagents default to `codex exec` for better tmux capture/tailing; opt in
  to the interactive TUI only when needed via `PARALLELUS_CODEX_USE_TUI=1`.
- **Merge / Archive / Remote triage:** Prior to running `make merge`,
  `make archive`, or evaluating unmerged branches, revisit
  `parallelus/manuals/git-workflow.md`. Merge requests now require an approved senior
  architect review staged under
  `docs/parallelus/reviews/<branch>-<date>.md` *and* a committed retrospective
  report covering the latest marker; overrides use `AGENTS_MERGE_FORCE=1` (and
  `AGENTS_MERGE_ACK_REVIEW=1` where applicable) and must be documented in the
  progress log.
- **Environment & Platform diagnostics:** If environment parity is in question
  (CI, Codex Cloud, headless shells), review `parallelus/manuals/runtime-matrix.md` and
  run the diagnostics described there.
- **Language adapters & integrations:** When enabling or maintaining Python or
  Node tooling—or when Codex integration behaviour changes—consult the manuals
  under `parallelus/manuals/adapters/` and `parallelus/manuals/integrations/`.
- A directory index lives at `parallelus/manuals/manuals/README.md`; update it when new
  manuals are introduced.

## 5. Accountability
- You own final quality. Run the necessary checks, review diffs, and confirm
  guardrails before asking to merge.
- Record interventions (e.g., subagent halts, environment failures) in the
  progress notebook so reviewers can trace decisions.
- Leave the workspace in policy-compliant shape at hand-off: clean status or
  documented deltas, updated notebooks, and acknowledged manuals.
