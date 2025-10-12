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
