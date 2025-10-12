# Parallelus Agent Core Guardrails

This document is mandatory reading at the start of every session. Record in the
branch progress notebook that you reviewed it before running any project
commands beyond `make read_bootstrap`.

## 1. Purpose & Usage
- Internalise these guardrails during Recon & Planning; they apply to every
  turn regardless of scope.
- Operational manuals live under `docs/agents/manuals/`. Only consult them when
  a gate below fires, but you **must** read the relevant manual *before*
  executing the guarded task and note the acknowledgement in the progress log.
- Users delegate intent; you own execution, cleanup, and reporting. Never assume
  the user will run shell commands on your behalf.
- If this file starts with an **Overlay Notice**, reconcile every `.bak`
  backup created during deployment, merge conflicting instructions into the new
  guardrails, document the outcome in the branch plan, then remove the notice.

## 2. Session Cadence & Core Checklists

### Recon & Planning (read-only)
- Run `make read_bootstrap` immediately; report repo mode, branch, remotes, and
  orphaned notebooks before continuing.
- Open the active plan and progress notebooks (`docs/plans/<branch>.md`,
  `docs/progress/<branch>.md`) or confirm they do not exist yet.
- List recent `sessions/` entries. If none match today (2025-10-12), seed a new
  session with `SESSION_PROMPT="..." make start_session` **before** leaving
  Recon & Planning.
- Inspect repo state, answer questions, plan next moves. Do not edit tracked
  files or run bootstrap helpers during this phase.

### Transition to Editing (trigger once you intend to modify tracked files)
1. Ensure the Recon checklist above is complete.
2. Create or switch to a feature branch via `make bootstrap slug=<slug>`; never
   edit directly on `main`.
3. Export `SESSION_PROMPT` (optional) and run `make start_session` to capture
   turn context.
4. Update the branch plan/progress notebooks with current objectives before
   editing code or docs.
5. Run required environment diagnostics (see Operational Gates for details) and
   log results in the progress notebook.
6. Commit the bootstrap artifacts once the branch is staged for real work.
  (Bootstrap syncs managed git hooks into `.git/hooks`; do not delete them.)

### Active Execution & Validation
- Keep audible alerts active: fire `.agents/bin/agents-alert` **before** any
  approval pause and after each work block (>5 s) before handing control back.
- Update branch plan/progress notebooks after meaningful work units. Treat
  `➜ checkpoint` markers as mandatory commit points.
- Expect the managed `pre-commit` hook to remind you about plan/progress updates
  when committing feature work; treat warnings as action items, not noise.
- Direct commits to the base branch are blocked; set `AGENTS_ALLOW_MAIN_COMMIT=1`
  only for emergencies, and record the rationale in the progress log.
- When subagents are active, maintain the monitor loop per the Subagent manual.
- Stay within the requested scope; defer speculative refactors unless directed.
- Senior architect review is mandatory before merging: capture the signed-off
  report under `docs/reviews/<branch>-<date>.md` (`Reviewed-Branch`,
  `Reviewed-Commit`, `Reviewed-On`, `Decision: approved`, no `Severity:
  Blocker/High`, and acknowledge other findings via
  `AGENTS_MERGE_ACK_REVIEW`). Default profile values live in
  `.agents/config/senior_architect.yaml`; update that file rather than editing
  the prompt.

### Turn-End & Session Wrap
- If a new request arrives after the previous conversation has been idle, run
  `make turn_end m="..."` first to close the earlier turn before starting new
  work.
- Use `make turn_end m="summary"` to append structured updates before replying
  on an active turn; the helper updates progress logs, plan notebooks, session
  summary, and `meta.json` in one step.
- Ensure progress logs capture the latest state, session metadata is current,
  and the working tree is either clean or holds only intentional changes noted
  in the progress log. Avoid committing unless the maintainer instructs you to.
- Do not merge or archive unless the maintainer explicitly asks.
- `make turn_end` now records a marker in `docs/self-improvement/markers/`.
  Immediately afterwards, launch the Retrospective Auditor prompt (see
  `.agents/prompts/agent_roles/agent_auditor.md`). Save the JSON response to
  `docs/self-improvement/reports/<branch>--<marker-timestamp>.json` and carry
  any follow-up TODOs into the branch plan before requesting a merge.

## 3. Command Quick Reference
- `make read_bootstrap` – detect repo mode, base branch, branch hygiene.
- `make bootstrap slug=<slug>` – create/switch feature branch and seed notebooks.
- `SESSION_PROMPT="..." make start_session` – initialise session artifacts.
- `make turn_end m="summary"` – checkpoint plan/progress + session meta.
- `make ci` – run lint, tests, and smoke suite inside the configured adapters.

## 4. Operational Gates (Read-on-Trigger Manuals)
- **Subagents:** Before launching or monitoring subagents (e.g.
  `make monitor_subagents`, `subagent_manager ...`), read
  `docs/agents/subagent-session-orchestration.md` and log the acknowledgement.
- **Merge / Archive / Remote triage:** Prior to running `make merge`,
  `make archive`, or evaluating unmerged branches, revisit
  `docs/agents/git-workflow.md`. Merge requests now require an approved senior
  architect review staged under `docs/reviews/<branch>-<date>.md` *and* a
  committed retrospective report covering the latest marker; overrides use
  `AGENTS_MERGE_FORCE=1` (and `AGENTS_MERGE_ACK_REVIEW=1` where applicable) and
  must be documented in the progress log.
- **Environment & Platform diagnostics:** If environment parity is in question
  (CI, Codex Cloud, headless shells), review `docs/agents/runtime-matrix.md` and
  run the diagnostics described there.
- **Language adapters & integrations:** When enabling or maintaining Python or
  Node tooling—or when Codex integration behaviour changes—consult the manuals
  under `docs/agents/adapters/` and `docs/agents/integrations/`.
- A directory index lives at `docs/agents/manuals/README.md`; update it when new
  manuals are introduced.

## 5. Accountability
- You own final quality. Run the necessary checks, review diffs, and confirm
  guardrails before asking to merge.
- Record interventions (e.g., subagent halts, environment failures) in the
  progress notebook so reviewers can trace decisions.
- Leave the workspace in policy-compliant shape at hand-off: clean status or
  documented deltas, updated notebooks, and acknowledged manuals.
