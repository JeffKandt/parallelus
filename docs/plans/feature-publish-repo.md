# Branch Plan — feature/publish-repo

## Objectives
- Publish the local `agent-process-demo` repository to GitHub under `JeffKandt/parallelus`.
- Ensure guardrail documentation and session artefacts are captured for this publishing step.

## Checklist
- [x] Review `AGENTS.md` guardrails (logged in progress notebook).
- [x] Run `make bootstrap` to create feature branch scaffolding.
- [x] Start a session for 2025-10-12 work.
- [x] Configure the `origin` remote to point at `git@github.com:JeffKandt/parallelus.git`.
- [x] Push the initial `main` branch state to GitHub.
- [x] Record outcomes and next steps in progress notebook.
- [x] Allow audible alerts to fire even when stdout is not a TTY while keeping subagents quiet.
- [x] Document the updated audible alert behaviour for future contributors.
- [x] Reintroduce subagent Codex profile support and prompt configuration.
- [x] Update docs with tmux/profile guidance for human operators.

## Next Actions
- Confirm remote repository contents and branch protection needs.
- Plan follow-up work once additional requests arrive.
- Revisit whether `--dangerously-bypass-approvals-and-sandbox` should remain the default for subagent launches.
- Monitor tmux helper scripts for any remaining socket-awareness gaps as automation evolves.
- Document the review of `docs/agents/subagent-session-orchestration.md` before any subsequent subagent launches, per the latest CI audit follow-up.
- Confirm the revised tmux overlay layout with operators and document the outcome.
- Observe the new base worktree indicator in day-to-day use and record feedback.
- Capture and archive the complete main-agent console transcript for every session (not just CI audits). At each turn end, perform a retrospective review of the transcript to log execution anomalies, reasoning faults, prompt-context conflicts, specification drift, and any deviations, then record mitigations or guardrail updates.
- When relaunching the senior architect review, call out that only `docs/agents/subagent-session-orchestration.md` and the latest progress log entry changed after the prior approval so the reviewer can focus on that delta.
