# Parallelus Agent Process – Quickstart & Index

Use these targets for a consistent, portable workflow.

## Quickstart (30 seconds)

```
make read_bootstrap             # safe, read-only checks
make bootstrap slug=my-feature  # create feature/my-feature
make start_session              # scaffold session artifacts
```

## Process Targets

- `make turn_end m="summary"` – checkpoint docs and session meta
- `make archive b=feature/old` – remote-aware archival flow
- `make ci` – run lint + tests + agents smoke suite
- `make merge slug=<branch>` – run CI, enforce guardrails, and merge into the base branch

## Subagent Monitoring

Whenever you launch a subagent, start the monitor loop in a dedicated terminal pane:

```
make monitor_subagents
```

The helper runs `agents-monitor-loop.sh` with a 45 s poll interval, a 180 s log-heartbeat
threshold, and a 10 minute runtime limit. The loop exits automatically when no subagents
are still `running`, when a sandbox exceeds the heartbeat threshold, or when a sandbox
has been active for more than 10 minutes. Treat loop exit as a mandatory checkpoint:
investigate the identified subagent immediately, decide whether to let it continue,
request changes, or halt it, then restart the loop if work remains.

When a subagent hands work back, you—not the subagent—own the final quality bar. Run
the necessary checks, review the diff, and only merge into your feature branch when the
results meet your standards.

### Monitor Loop Exit Protocol

When `make monitor_subagents` exits:
- **Inspect immediately.** Tail the flagged subagent’s log (`tail -n 50 <log_path>`) and review its plan/progress notebooks to confirm whether it is still active or truly stalled/complete. ANSI escape sequences from editors can make a stale log look “busy”; rely on timestamps, not just visual churn.
- **Act before restarting.** Provide the next instructions (resume, request changes, or halt) *before* relaunching the monitor loop. Never leave the loop idle under the assumption the subagent is still working.
- **Ensure panes are cleared.** If you halt a subagent via `subagent_manager cleanup --force`, immediately close any tmux panes/windows it created (e.g., `tmux kill-pane -t <pane_id>`) and verify no Codex processes from that sandbox remain before launching another run.
- **Record the decision.** Note the intervention in your progress notebook so reviewers understand why the loop paused and what follow-up occurred.

IMPORTANT: At the start of every session, read this AGENTS.md file **and every linked reference** (`docs/agents/core.md`, `docs/agents/git-workflow.md`, `docs/agents/runtime-matrix.md`, `docs/agents/integrations/*`, `docs/agents/adapters/*`, `docs/agents/project/*`). Treat the combined guidance as authoritative; do not modify code, docs, or plans until you have reviewed and understood all linked material. The guardrails and processes described there are mandatory and must be followed throughout the session.

**Primary agent accountability.** The assistant is responsible for executing commands, enforcing guardrails, and keeping the workspace in policy-compliant shape. Users communicate intent in natural language; the assistant translates that intent into concrete commands, performs the required cleanup (e.g., clearing tmux panes after `subagent_manager cleanup --force`), and reports the outcomes. Never assume the user will run shell commands manually.

Before running any other command, execute `make read_bootstrap` to establish the current branch, repo mode, and session phase, then report those findings (including any orphaned notebooks) to the maintainer. Immediately afterwards, open the active branch plan and progress notebooks (`docs/plans/<branch>.md`, `docs/progress/<branch>.md`) so your status report reflects the latest objectives, TODOs, and open questions. Check `sessions/` for a same-day entry; if none exists, run `SESSION_PROMPT="..." make start_session` before moving past Recon & Planning.

## Adapters & Integrations

- Python adapter → `docs/agents/adapters/python.md`
- Node adapter stub → `docs/agents/adapters/node.md`
- Codex CLI/Cloud integration → `docs/agents/integrations/codex.md`

## Reference

- Phases & guardrails → `docs/agents/core.md`
- Git workflow → `docs/agents/git-workflow.md`
- Runtime support matrix → `docs/agents/runtime-matrix.md`
- Project-specific context → `docs/agents/project/`
- Worktree verification checklist → `docs/agents/subagent-session-orchestration.md#c-verification--merge`

Need the legacy instructions? See repository history prior to commit
`docs: capture agents reorg decisions`.
