# Subagent Session Orchestration

**Read this manual in full before launching or monitoring subagents.** Per the
core guardrails in `AGENTS.md`, you must acknowledge in the branch progress log
that you reviewed this document prior to running `make monitor_subagents`,
`subagent_manager`, or any related helper.

This manual describes how a primary Codex CLI session can delegate work to an
interactive "subagent" while maintaining traceability. Use this flow when
non-interactive execution is unavailable or when you want a human-supervised
agent to take ownership of a scoped task.

> **Senior architect reviews:** Launch them as **synchronous subagents** so the
> primary agent stays focused on review findings. Populate the configuration
> header in `.agents/prompts/agent_roles/senior_architect.md` (defaults in
> `.agents/config/senior_architect.yaml`) before launch. The subagent operates
> read-only and may write only `docs/reviews/feature-<slug>-<date>.md`.

> **Retrospective audits:** After each `make turn_end`, launch the Retrospective
> Coach prompt (`.agents/prompts/agent_roles/agent_coach.md`) to coordinate the
> synchronous auditor. The auditor works read-only, analyses evidence starting
> from the marker recorded in `docs/self-improvement/markers/<branch>.json`, and
> returns a JSON report to be saved under
> `docs/self-improvement/reports/<branch>--<marker-timestamp>.json`.

## 1. Overview

The main agent prepares a target repository (either a throwaway sandbox or a git
worktree), launches a secondary Codex session in a new terminal, and continues
its own tasks while the subagent works. Later it verifies the results and
resumes its workflow. A launcher parameter selects the target type.

Roles:

- **Main agent:** prepares the target repo, records scope/plan updates, launches
  the subagent session, and validates results. Subagents are always created from
  a feature branch—never directly on `main`—so supporting docs and registry
  entries can be committed safely.
- **Subagent session:** follows the published guardrails inside the sandbox,
  executes the scoped work, and leaves detailed progress updates for review.
- **User (optional):** monitors progress, relays "done" or follow-up instructions
  if the main agent requests confirmation.

Target modes:

- **Throwaway sandbox:** used for transient validation; deleted after
  verification.
- **Worktree sandbox:** a git worktree for real development. The main agent
  decides when the branch is merged back into the primary repo.

## 2. Prerequisites

- The main session must be on a clean feature branch (not `main`).
- The environment permits launching additional terminals (iTerm2, Terminal.app,
  tmux, VS Code, etc.); provide fallbacks for headless hosts.
- Optional helpers (`.agents/bin/process_self_test.sh`,
  `scripts/run_with_watchdog.py`) are available if needed for logging/monitoring.

## 3. Command Interface

All orchestration commands are exposed through `.agents/bin/subagent_manager.sh`
(to be implemented). Interface summary:

- `launch --type {throwaway|worktree} --slug <branch-slug> --scope <scope-file>
  [--launcher auto|iterm-window|iterm-tab|terminal-window|terminal-tab|tmux|code]`
  - Validates the current branch (must not be `main`).
  - Creates the target repo (temp directory or git worktree).
  - Drops the scope file, registers the subagent in
    `docs/agents/subagent-registry.json`, and launches Codex via the selected
    terminal integration.
  - Prints sandbox/log paths so the main agent can tail progress.
  - Registry entries now include `window_title`, `launcher_kind`, and a
    structured `launcher_handle` (session/pane identifiers) so the main
    agent can locate or automate the launched terminal session later.
  - GUI launchers emit ANSI title sequences so iTerm2/Terminal chrome reflects
    the registry ID immediately after the window spawns.
  - When the main agent is already running inside tmux, subagent panes now
    appear alongside it in the current window: the first launch carves out a
    right-hand column at roughly half the window width, and subsequent launches
    stack additional panes vertically in that column so each subagent stays visible.
  - tmux panes automatically display the registry ID in the pane border, and
    `subagent_manager.sh status` reports the matching pane/window handle so you
    can jump straight to the right pane when the monitor loop flags an agent.
  - Launches now check whether a tmux session is available; if none is found,
    the helper prints the current Codex session ID and points to
    `.agents/bin/resume_in_tmux.sh` so you can resume the session inside the
    shared tmux workspace before retrying. Sanitised environments (e.g. ones
    launched with `env -i` that clear `TMUX`) are handled automatically. The
    resume helper drops a prompt on reconnect asking whether the user wants the
    pending subagent relaunched.
- `status`
  - Reads the registry and reports the state of each subagent (running, awaiting
    verification, completed, abandoned). It runs `make read_bootstrap`, inspects
    plan/progress notebooks, and may report log heartbeat or active Codex
    processes where permitted.
- `verify --id <registry-id>`
  - Executes the appropriate verification checklist (throwaway vs worktree) and
    records the outcome.
- `cleanup --id <registry-id>`
  - Removes the target repo/worktree and finalises the registry entry. The helper
    refuses to clean a sandbox whose status is still `running`; pass `--force`
    only when you are certain the session has exited.

Launcher precedence is configurable via `config/subagent_launcher.toml`; users
may override the default (iTerm2 window → Terminal window → tmux → VS Code →
manual instructions) and choose "window" or "tab" variants where applicable.

## 4. Main Agent Workflow

### 4.1 Prepare Target Repository

1. **Create sandbox**
   - *Throwaway:* clone/export the repo into a temp directory.
   - *Worktree:* `git worktree add ../worktrees/<slug> <feature-branch>`.
2. Drop an untracked scope file (e.g. `SUBAGENT_SCOPE.md`) describing tasks,
   acceptance criteria, and constraints. Use
   `docs/agents/templates/subagent_scope_template.md` as a starting point.
3. Record an entry in `docs/agents/subagent-registry.json` capturing sandbox path,
   scope file, branch slug, launch time, and current status.

### 4.2 Launch Subagent

Use `subagent_manager.sh launch ...`. The helper prints the sandbox path, log
path (tee’d output), and any monitoring commands before returning control to the
main agent.

### 4.3 Monitor Progress

Run `subagent_manager.sh status` whenever you need a snapshot. The command polls
`make read_bootstrap` in each sandbox, examines plan/progress notebooks, and
checks log heartbeat. Status output drives decisions on whether to let a
subagent continue, assign more work, or proceed to verification.

Start the looping monitor immediately after launching a subagent:

```
make monitor_subagents
```

The helper runs `agents-monitor-loop.sh` with a 45 s poll interval, a 180 s log-heartbeat
threshold, and a 600 s runtime threshold.

- `--interval` controls how often the registry is polled (seconds).
- `--threshold` is the maximum age (seconds) of the subagent’s most recent log update
  before the loop surfaces a warning.
- `--runtime-threshold` is the maximum accumulated runtime for a subagent before the
  loop forces a review (defaults to 10 minutes). Use `make monitor_subagents ARGS="--runtime-threshold 900"`
  to customise.
- `--iterations N` stops the loop after N polls (useful for short smoke checks).
- The loop exits automatically when no subagents remain in the `running` state, when at
  least one running subagent exceeds the heartbeat threshold, or when a running subagent
  crosses the runtime threshold. Treat loop exit as a mandatory hand-off: inspect the
  flagged sandbox right away, respond, document the intervention (plan/progress + progress log),
  and restart the loop only after next steps are clear.

When the loop exits:
1. Run `./.agents/bin/subagent_manager.sh status --id <registry-id>` to confirm which
   subagent triggered the exit and capture its latest log age.
2. Review the subagent’s plan/progress notebooks and console log; if the work is unfinished,
   message the subagent with next steps and rerun the monitor loop. Verify timestamps—ANSI redraws can
   make stale logs look active. For runtime threshold exits, watch the live log to ensure forward progress
   resumes. If the sandbox is stuck (e.g., looping, burning tokens without completing tasks), halt the
   session (`Esc` in Codex CLI or killing the pane), capture notes about the failure, and **leave the sandbox
   intact** for human forensics.
3. If the subagent appears complete, follow the verification checklist below, run any required CI/lint,
   and then decide whether to request revisions, let the subagent continue, or proceed toward merge/cleanup.
4. After issuing follow-up instructions (or after verification/cleanup), restart the monitor loop so
   remaining subagents stay covered.

### 4.4 Completion & Verification

When `status` marks a subagent ready (or the user reports "done"), verify and
record the outcome.

- **Throwaway verification**
  1. `make read_bootstrap`
  2. Confirm plan/progress notebooks indicate completion.
  3. Inspect `sessions/<id>/summary.md` & `meta.json`.
  4. Ensure `git status` is clean; no notebooks remain.
  5. Log results in the main branch progress doc.

- **Worktree verification**
  1. `make read_bootstrap`
  2. Confirm plan/progress notebooks are complete and the subagent left a
     detailed summary for review.
  3. Run lint/tests as required.
  4. Decide whether to request further work or move toward merge.
  5. If approved, merge via the standard helper, then fold notebooks back into
     the canonical docs.
  6. Remember that the main agent owns the final quality bar—only merge once the changes
     satisfy your standards and you are confident the feature branch remains healthy.

Follow this worktree verification checklist before accepting or merging subagent output:

- [ ] Run `make read_bootstrap` inside the worktree to confirm branch context, notebooks, and orphaned artifacts.
- [ ] Re-read the scope (if still present) and compare it against `docs/plans/<branch>.md` plus `docs/progress/<branch>.md`; flag outstanding tasks or questions.
- [ ] Inspect the diff with `git status --short --branch` and `git diff`; ensure only expected files changed and review each hunk for correctness.
- [ ] Execute the documented lint/tests (`make ci`, `make lint`, `make test`, or commands called out in the progress log) and capture the results in your notes.
- [ ] Review subagent logs (`subagent.log`, session summaries, console transcripts) for warnings, skipped steps, or TODOs that require follow-up.
- [ ] Restart or resume any monitoring loops paused for the subagent (e.g. `.agents/bin/agents-monitor-loop.sh --id <registry-id>` or your local equivalent) so the main session regains coverage.
- [ ] Record the decision in the branch progress notebook using `docs/agents/templates/subagent_acceptance_snippet.md`, capturing follow-ups or rework requests.
- [ ] Decide on the outcome: request additional changes, merge via `make merge slug=<slug>`, archive, or leave the worktree in place for further review.
- [ ] If merging, fold notebooks into canonical docs before running `git worktree remove` and deleting the feature branch.

**Acceptance rubric:** The main agent owns final quality. Only accept work that satisfies the scope, passes required checks, and produces diffs you fully understand. Capture any remaining risks or TODOs in the progress notebook before merging; if confidence is missing, request revisions instead of approving.

### 4.5 Cleanup

- *Throwaway:* delete/archive the sandbox directory and update the registry.
- *Worktree:* after merge or abandonment, remove the worktree (`git worktree
  remove ...`), delete the remote branch if needed, and update the registry.
- After cleanup (or after giving the subagent more instructions), restart the
  monitoring loop so remaining subagents continue to receive heartbeat coverage.
- If a sandbox was halted for investigation (runtime threshold exit with no forward progress),
  leave it in place until a maintainer reviews the artifacts; document the failure in the main
  branch progress log and only clean up once the follow-up analysis is complete.

If the subagent exits prematurely, follow Section 6 to resume work with a
replacement.

## 5. Subagent Responsibilities

- Run the standard continuity checks (`make read_bootstrap`, scope review)
  before editing.
- Read the untracked scope file, create the feature branch via `make bootstrap`
  with the assigned slug, and convert the scope into official plan/progress
  notebooks before making changes.
- Follow all guardrails: update plan/progress notebooks, record checkpoints,
  commit as required, and leave the sandbox clean.
- Throwaway sandboxes may use a temporary feature branch solely for notebooks
  and remove it later. Worktree subagents remain on the long-lived branch.
- For long-lived worktrees the subagent **does not** merge back to main; it
  leaves a comprehensive progress summary (what changed, tests run, outstanding
  items) so the main agent can review and decide on next steps. Throwaway smoke
  sandboxes may explicitly instruct the subagent to run the merge helper as
  part of validation—keep that directive isolated to harness scopes.
- Prompts should remind subagents to keep working without manual nudges, call
  out the merge/cleanup expectations from the scope, and not exit until the
  checklist is complete with a clean `git status`.
- A helper script (`.agents/bin/subagent_alive.sh`) is available for Codex sessions:
  run `/shell .agents/bin/subagent_alive.sh` to confirm whether the sandbox
  directory still exists before deciding to keep the tab open or close it.

## 6. Resuming After Premature Exit

If a subagent session closes early:

1. Inspect the sandbox/worktree (plan/progress, commits, git status).
2. Update the scope or plan with remaining tasks.
3. Launch a replacement pointing at the same target. The new session runs
   continuity checks and resumes the updated checklist from the current phase.
4. Repeat until the scope is complete.

## 7. Communication & Monitoring

- The main agent can add tasks by editing the branch plan; subagents are told to
  “check the plan for next steps.”
- Status monitoring relies on the registry, optional helper scripts, and the
  tee’d log heartbeat. `ps` can detect active Codex processes where system
  permissions allow.
- Sessions are expected to remain open until finished, but replacements can be
  launched at any time.

## 8. Failure Handling

- If a subagent crashes or cannot be launched, capture logs/plan state and note
  the blocked condition in the registry. Decide whether to retry or troubleshoot
  manually.
- For persistent environment issues, fall back to manual instructions.

## Known Issues & Follow-Ups

- `make start_session` can pause with `.agents/bin/agents-session-start: line 43: <suffix>: unbound variable` when existing session directories include timestamp suffixes (e.g. `041-20251004155824-a73977`). Strip the suffix before performing `10#$dir` arithmetic in the helper so smoke prompts and harness sessions launch without manual `SESSION_ID` overrides.

## Worktree-Specific Notes

### A. Creation Recap

1. `git worktree add ../worktrees/<slug> <feature-branch>`
2. Add untracked scope file
3. Registry entry
4. Launch subagent

### B. Subagent Work Instructions

- Read scope → `make bootstrap slug=<slug>` → seed plan/progress → delete or
  archive scope file once notebooks exist.
- Leave clean working tree, plan/progress updates, commits, and a detailed
  summary for review.

### C. Verification & Merge

1. `make read_bootstrap`
2. Review notebooks and progress summary
3. Run tests/lint
4. Decide: request changes, merge, or abandon
5. If merging, fold notebooks into canonical docs
6. `git worktree remove` and delete feature branch when done

### D. Multiple Worktrees & Status

- Track all worktrees in the registry; use `subagent_manager.sh status` to
  review them asynchronously.
- Coordinate merges sequentially to avoid conflicts.

### E. Failure Handling

- Leave the worktree intact for inspection if a session fails.
- Document the failure in the main branch progress log before removing or
  recycling the worktree.

### F. Future Enhancements

- Allow publishing a subagent branch/worktree to `origin` so a Codex Cloud
  instance can take over. A human would still launch the cloud session and
  submit PRs, but this enables remote execution.

## Appendix: Prompt Templates

### Throwaway Sandbox Prompt

```
You are operating inside disposable sandbox {PATH}. Follow AGENTS.md and
SUBAGENT_SCOPE.md. Create a temporary feature branch, execute the smoke
checklist, update plan/progress notebooks, and leave `main` clean before
exiting. Record all checkpoints and keep the session open until every task is
complete.
```

### Worktree Development Prompt

```
Work inside worktree {PATH} on branch {FEATURE_BRANCH}. Read the assignment in
SUBAGENT_SCOPE.md, bootstrap the session (`make bootstrap slug=...`, `make
start_session`), and complete the tasks. Update plan/progress notebooks, run
required tests, and leave a detailed summary for review. Do not merge—stop once
`git status` is clean and all work is documented.
```

These templates are starting points; expand them with task-specific details as
needed.

## Appendix: Scope Template

The default scope template lives at `docs/agents/templates/subagent_scope_template.md`. Copy or customise it when preparing instructions for a subagent. Ensure the final plan/progress notebooks mirror the tasks defined in the scope.
