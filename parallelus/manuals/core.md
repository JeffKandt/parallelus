# Core Agent Process (Manual)

Read this manual when you need deeper context or examples for the core
guardrails defined in `AGENTS.md`. The summary in `AGENTS.md` remains the
authoritative checklist at session start; acknowledge this manual in your
progress log when you consult it for open questions or training.

## 1. Phases & Mandatory Checks

### Recon & Planning (read-only)
- Start every session with `eval "$(make start_session)"`, which enables logging and runs `make read_bootstrap`. Relay the branch/phase status to the maintainer before proceeding.
- Immediately open the active branch plan and progress notebooks (`docs/branches/<slug>/PLAN.md`, `docs/branches/<slug>/PROGRESS.md`) so next steps and status updates reflect the latest objectives, TODOs, and follow-ups.
- List recent session directories (`ls -1 sessions/ | tail -5`). If the newest entry predates the current turn, run `SESSION_PROMPT="..." eval "$(make start_session)"` before leaving Recon & Planning.
- Inspect repo state, answer questions, plan next moves.
- Do **not** modify code, docs, or plans, and skip bootstrap helpers.

### Transition Checklist (from recon to editing)
Trigger as soon as you intend to change any tracked file.
1. Run repository detection via `eval "$(make start_session)"`. Direct `make read_bootstrap` now requires active session logging.
2. Create/switch to a feature branch via `make bootstrap slug=<slug>`.
3. Export `SESSION_PROMPT` (optional) and run `eval "$(make start_session)"` to capture the turn context.
4. Update branch plan/progress notebooks with objectives before editing files.
5. Run environment diagnostics (see §3) and confirm readiness.
6. Commit the initialized plan/progress notebooks (and session metadata) so future contributors inherit scope, diagnostics, and starting context.

### Active Execution (editing & validation)
- Follow checkpoint cadence (plan, progress log, commits) after every meaningful unit of work.
- Keep audible-alert guardrail active (see below).

Skipping these steps causes inconsistent state, missing logs, and fragile merge workflows.


### Recon & Planning (read-only)

## Recon & Planning (read-only)
- Run `make read_bootstrap` immediately to detect repo mode, current branch, and outstanding notebooks; relay the branch/phase status to the maintainer before proceeding.
- Immediately open the active branch plan and progress notebooks (`docs/branches/<slug>/PLAN.md`, `docs/branches/<slug>/PROGRESS.md`) so next steps and status updates reflect the latest objectives, TODOs, and follow-ups.
- List recent session directories (`ls -1 sessions/ | tail -5`). If the newest entry predates the current turn, run `SESSION_PROMPT="..." make start_session` before leaving Recon & Planning.
- Inspect repo state, answer questions, plan next moves.
- Do **not** modify code, docs, or plans, and skip bootstrap helpers.

### Transition Checklist (from recon to editing)
Trigger as soon as you intend to change any tracked file.
1. Run repository detection: `eval "$(parallelus/engine/bin/agents-detect)"` or the
   equivalent `make read_bootstrap` target.
2. Create/switch to a feature branch via `make bootstrap slug=<slug>`. **If `make bootstrap` (or any bootstrap step) exits non-zero, stop immediately, describe the failure, and wait for the user to resolve it. Do not create or switch branches manually until the command succeeds with a clean tree.**
3. Export `SESSION_PROMPT` (optional) and run `make start_session` to capture the
   turn context.
4. Update branch plan/progress notebooks with objectives before editing files.
5. Run environment diagnostics (see §3) and confirm readiness.

## Active Execution (editing & validation)
- Follow checkpoint cadence (plan, progress log, commits) after every meaningful
  unit of work.
- Keep audible-alert guardrail active (see below).
- When subagents are running, keep the monitor loop active via
  `make monitor_subagents` (45 s poll interval, 180 s heartbeat threshold,
  600 s runtime threshold). The loop exits when no subagents remain, when a sandbox
  stops logging inside the heartbeat window, or when a sandbox has been active for
  ten minutes. Treat loop exit as a mandatory checkpoint: review the flagged sandbox,
  issue new instructions or halt it as needed, log the intervention, and only then restart the loop.

Skipping these steps causes inconsistent state, missing logs, and fragile merge
workflows.

### Session Continuity Check (always Step 1)
Run the quick audit before touching anything:
```bash
git status --short --branch
ls -1 sessions/ | tail -5
ls docs/branches/ | tail -5
```
Use the output to determine whether you are resuming an existing feature or
starting fresh (Recon & Planning), then open the branch plan/progress notebooks
you just listed to capture outstanding work before proposing next steps. If the
latest `sessions/` directory predates today, seed a fresh session immediately via
`SESSION_PROMPT="..." make start_session` before editing tracked files.

## 2. Audible Alert Rule
> `parallelus/engine/bin/agents-alert "Codex is waiting for your input"` **before** you
> pause for approval or user input. No exceptions.
>
> `AUDIBLE_ALERT_MESSAGE="Codex is ready for your input" parallelus/engine/bin/agents-alert`
> **after** each work block before handing control back (unless <5 seconds).

- macOS prefers `say` (voice `Reed` by default), falls back to `afplay`, then
  terminal BEL + log line.
- Headless/CI shells degrade to BEL/log-only behaviour.
- Fire an alert *before* running commands likely to gate on approval so the user
  hears the pause even if the command itself blocks.
- Track elapsed time between alerts; when unsure, default to firing the “ready”
  alert.

## 3. Environment Validation (Transition checklist step 5)
Run inside the project virtualenv:
```bash
python scripts/check_env.py --check-internet https://pypi.org \
  --ssh-host m4-mac-mini --check-command ffmpeg
ffmpeg -version
```
Ensure `.venv` exists, dependencies align, SSH heartbeat succeeds, and ffmpeg is
available. Log results in the branch progress notebook.

## 4. Session Bootstrap Checklist
1. `eval "$(make start_session)"`
2. `make bootstrap slug=<slug>` (refuses if worktree dirty)
3. `SESSION_PROMPT="..." eval "$(make start_session)"`
4. Update plan/progress docs with objectives and links to `sessions/<ID>/`
5. Record environment diagnostics (above)
6. Commit the plan/progress bootstrap to freeze the starting state

Only after completing all six items may you begin editing tracked files.

## 5. Turn-End & Session-End Flow

If a conversation goes idle and a new request arrives later—especially if it
changes focus—run `make turn_end m="..."` **before** starting the new work.
That closes the prior turn so artifacts stay sequenced.

### Turn-End Validation (run before replying to the user)
- Progress log reflects current state (append timestamped entry).
- Session summary (`sessions/<ID>/summary.md`) updated with turn notes.
- `meta.json` refreshed with latest timestamp.
- No auto-commits; user decides.
- Working tree either clean or containing only intentional changes noted in the
  progress log.
- Fire “ready” audible alert if work block >5s.
- Session console logging must be enabled (`sessions/<ID>/console.log` is non-empty).
- `make start_session` must have been run for the current branch (enforced by a session marker).

Run `make turn_end m="summary"` (wraps `parallelus/engine/bin/agents-turn-end`) to perform
these updates in one step. The helper appends to the branch progress log and
plan notebooks (when present), updates the session summary, touches `meta.json`,
and records the retro marker; supply a descriptive message so reviewers
understand the outcome.

### Merge-Time Retrospective Audit
- Do not run `retro-marker`, `collect_failures`, and the auditor in parallel.
- Preferred path: run `make senior_review_preflight` to execute the serialized
  retrospective pipeline and launch senior review.
- Manual fallback: run `retro-marker` -> `collect_failures` -> auditor in that
  exact order, then save the JSON report under
  `docs/parallelus/self-improvement/reports/<branch>--<marker>.json`.

### Session Wrap (feature complete)
- Add end timestamp & duration to `meta.json`.
- Link session summary from branch log.
- Final checkpoint commit: `docs: checkpoint – close session <ID>`.

## 6. Checkpointing Cadence
After each meaningful change (compiling edit, test run, doc migration):
1. Update branch plan checklist / next actions.
2. Append timestamped progress entry (with artifacts + follow-ups).
3. Commit docs alongside code.

Checklist markers (➜ checkpoint) are treated as mandatory commit points.

## 7. Planning & Progress Conventions
- `docs/PLAN.md` remains the canonical roadmap; refresh only after merges.
- Each feature branch owns `docs/branches/<slug>/PLAN.md` and
  `docs/branches/<slug>/PROGRESS.md` while active.
- Merge branch notebooks into canonical docs before deleting them.
- Inline answers (code comments, spec updates) are preferred over new ad-hoc docs
  unless a lasting reference is needed.

## 8. Autonomy Guardrails
- Avoid pausing for approval unless destructive operations, milestone
  boundaries, or clarification is required.
- Keep work close to the user’s request; defer speculative refactors.
- Treat audible alerts, session logging, and checkpointing as non-negotiable.

## 9. Process Enforcement & Violations
Violations lead to inconsistent state, lost progress, broken merge workflows, and
confusion. Avoid:
- Skipping session continuity checks.
- Editing without full bootstrap.
- Auto-committing at turn end.
- Starting new sessions while a feature branch remains active.
- Ignoring checkpoint validation reminders.

The process exists to prevent these failures—follow it consistently.
