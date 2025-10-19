# Operational Manuals Index

This directory collects task-specific manuals referenced from `AGENTS.md`.
Agents only read a manual when they reach the matching gate in the core
guardrails, then document that acknowledgement in the branch progress log.

- `continuous-improvement.md` – fix-it-forever playbook; revisit whenever you
  root-cause an incident.
- `subagent-session-orchestration.md` – required **before** launching or
  monitoring subagents. Covers scope prep, monitor loop usage, verification,
  and cleanup procedures.
- `git-workflow.md` – revisit when planning direct merges or PR-based merges.
  Covers `make merge`, GitHub PR flow, and follow-up steps.
- `runtime-matrix.md` – consult when troubleshooting environment differences or
  running in CI/headless shells.
- `tmux-setup.md` – reference when configuring operator machines or codex
  launchers; details the required tmux build, socket strategy, and clean shell
  expectations for Parallelus.
- `integrations/` – adapter and platform overlays (Codex, Python, Node). Read
  the relevant integration manual the first time you enable that tooling or
  whenever the environment changes.
- `../reviews/` – permanent store for senior architect reviews required before
  merging feature branches.
- `../self-improvement/` – turn markers (`markers/`) and stored retrospective
  reports (`reports/`) produced by the synchronous audit workflow.

Add new manuals here when specialised workflows emerge, and update `AGENTS.md`
with the gate condition that sends maintainers to the new document.
