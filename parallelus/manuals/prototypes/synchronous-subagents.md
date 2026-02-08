# Synchronous Subagent Prototype

## Overview
The maintainer requested a synchronous launch mode where a subagent works inside the
primary tmux session while the main agent waits and supervises. This prototype describes
the desired behaviour, safety constraints, and process updates needed to experiment with
that flow without abandoning existing guardrails.

## Goals & Non-Goals
- **Goals**
  - Enable a "pairing" experience where the main agent can watch the subagent’s pane,
    answer questions quickly, and resume immediately after hand-off.
  - Preserve all process guardrails (bootstrap, notebooks, session logs, monitor loop)
    even when both agents share a tmux workspace.
  - Document tooling changes required so synchronous launches feel first-class rather
    than an ad-hoc tmux split.
- **Non-Goals**
  - Replace the existing asynchronous launch flow or skip the monitor loop.
  - Allow simultaneous edits on the same branch by main and subagent—control must remain
    with one agent at a time.
  - Introduce automatic merging; verification still happens after the subagent exits.

## Target Workflow

### Launch Preconditions
1. Main agent is on a clean feature branch with plan/progress notebooks up to date.
2. Scope file exists (or latest plan entry) describing the synchronous assignment.
3. Main agent starts a fresh session (`make start_session`) and records intent before
   launching the subagent.
4. Main agent runs `make monitor_subagents` in a dedicated pane even though the run is
   synchronous; the loop still provides heartbeat enforcement.
5. `subagent_manager` is invoked with a synchronous flag (described below) that splits
   the current tmux window, launches Codex in the new pane, and blocks until the subagent
   exits or signals completion.

### Execution Flow
1. Subagent follows the scope: reads AGENTS.md, bootstraps the feature branch (worktree or
   throwaway as dictated), seeds notebooks, and confirms the monitor loop is running.
2. Main agent remains in the original pane, ready to provide clarifications through tmux
   messages or shared notes, but avoids editing files to prevent conflicts.
3. All shell command output stays visible in the subagent pane; optional tee to
   `.parallelus/sessions/<ID>/console.log` continues capturing logs.
4. If the monitor loop flags a heartbeat lapse, the main agent pauses the subagent,
   investigates immediately, and documents the intervention in the plan/progress docs.

### Handoff & Completion
1. Subagent finishes checklist tasks, updates plan/progress notebooks, and declares
   readiness in the scope/progress entry.
2. Subagent exits the Codex session; the synchronous launcher detects the pane closing,
   collapses the tmux split (optional helper), and returns control to the main agent.
3. Main agent stops the monitor loop, reviews notebooks and diffs, runs validations, and
   records the verification outcome before deciding on follow-up actions.

## Requirements & Constraints
- tmux integration must be deterministic: identify the main pane, carve out a right-hand
  column for the subagent, and tag the pane title with the registry ID so the monitor loop
  output matches the visible pane.
- Launcher should block the calling shell until subagent completion to encode the
  synchronous expectation; backgrounding defeats the prototype’s intent.
- Logs/registry entries must reflect synchronous mode so later auditors know why the main
  agent was idle.
- Audible alert guardrail still applies: both agents fire alerts when pausing or handing
  off control even though they share a tmux session.
- Only one agent edits tracked files at a time; the main agent treats the branch as
  read-only until the subagent finishes.
- If the synchronous run exceeds the 10 minute monitor limit, the main agent must
  intervene—either extend via documented override or split work into smaller scopes.

## Tooling Gaps
- `subagent_manager launch` needs a `--mode sync` (or `--synchronous`) option that:
  - Uses the existing tmux launcher but records pane/window IDs, blocks until the pane
    exits, and tears down the split afterwards.
  - Emits a clear status line (`[sync-blocked] waiting for subagent <id>`) so the main
    agent knows the command is intentionally idle.
- Provide a synchronous prompt template (e.g. `parallelus/manuals/templates/subagent_scope_sync.md`)
  emphasising that the main agent is waiting, clarifying communication channels, and
  reiterating monitor loop expectations.
- Add registry metadata for synchronous sessions (`"mode": "sync"`) so `status` can
  highlight them and remind the maintainer to resume once the pane closes.
- Monitor loop helper may need to suppress duplicate heartbeat warnings when the main
  agent is actively supervising (e.g., extend tolerance or allow manual acknowledgments).
- Document a tmux restoration helper (`subagent_manager sync --collapse <id>`) to close
  stale panes if Codex crashes.

## Guardrails & Monitoring
- Main agent launches `make monitor_subagents` before the synchronous run and restarts it
  immediately after any intervention; loop exit remains a mandatory checkpoint.
- Scope must state that the subagent cannot close until the checklist is complete and
  `git status` is clean.
- Subagent keeps the progress notebook detailed because the main agent will rely on it
  during synchronous verification instead of requesting a separate status update.
- Both agents log any direct communication (e.g., clarifications sent through tmux
  messages) in the progress notebook to preserve traceability.
- If a synchronous session stalls, the main agent halts it via
  `subagent_manager cleanup --force`, documents the reason, and closes residual panes
  before relaunching—same as asynchronous flows.

## Risks & Mitigations
- **Resource contention:** Two agents might contend for the same files. Mitigate by
  freezing main agent edits and documenting that synchronous mode is single-editor.
- **Monitor loop fatigue:** Watching the pane may tempt maintainers to ignore monitor loop
  alerts. Mitigate by keeping the loop in a separate pane and treating exits as formal
  checkpoints.
- **Long-running sessions:** Synchronous runs inherently block the main agent; scopes must
  stay tightly focused (research, triage, short documentation). Longer tasks should remain
  asynchronous.
- **Pane drift or orphaned tmux panes:** If Codex dies unexpectedly, the synchronous
  launcher should re-focus the main pane and prompt for manual cleanup to avoid lingering
  panes that confuse later sessions.
- **Audible alert overlap:** Two agents firing alerts in the same terminal can be noisy;
  agree on a convention (e.g., subagent only fires "ready" alerts, main agent uses "wait")
  and document it in the scope.

## Open Questions
- Should the monitor loop heartbeat thresholds differ in synchronous mode (e.g., longer
  grace window while the main agent actively supervises)?
- How should synchronous scope handoffs be recorded in the registry—do we need explicit
  timestamps for "main agent resumed"?
- Do we want a `subagent_manager resume --id <id>` command that re-opens a pane if the
  main agent needs to follow up immediately after review?
- What is the preferred communication channel for quick clarifications (tmux popup,
  shared notes document, branch progress log)?
- Should synchronous mode automatically stage or commit results, or does the maintainer
  prefer manual commits after review?

## Recommended Next Steps
1. Prototype `subagent_manager launch --mode sync` with tmux pane blocking and teardown,
   plus registry metadata updates.
2. Add a synchronous scope template and update `parallelus/manuals/subagent-session-orchestration.md`
   with usage guidance, including audible alert conventions.
3. Extend the monitor loop helper to recognise synchronous sessions and allow manual
  acknowledgments or adjusted heartbeat timers when requested.
4. Run an end-to-end dry run (main + subagent) to validate pane management, registry
   entries, and documentation flow; incorporate findings into branch plan and progress
   notebooks.
