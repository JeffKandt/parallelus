# Project Plan

## Completed Work
- Synchronous retrospective workflow enforced (marker validation, auditor prompt).
- Senior architect review guardrails updated (config defaults, review commit checks).
- Deployment safety and CI flow hardened (hook backups, Python-only adapter).
- Parallelus-specific documentation realigned (README philosophy, project domain/structure notes, continuous-improvement playbook, tmux setup manual).
- Overlay deployment workflow refined (preserve project docs, optional backup suppression, shared senior review template).

## Next Focus Areas
- Continue refining auditor heuristic coverage (e.g., additional log analysis).
- Socialise the updated folding workflow and communication philosophy with maintainers; gather feedback for the next iteration.
- Pilot the Recon queue split (next-feature vs backlog) on upcoming branches and capture friction points for tooling tweaks.
- Harden subagent launch permissions by codifying allowed write paths (e.g., add review-specific `allowed_writes` entries and automated verification).
- Confirm published repository metadata (branch protections, README prerequisites) once main is updated.
- Monitor tmux helper behaviour in day-to-day use (socket awareness, status indicators) and capture operator feedback.
- Ensure transcript capture and retrospective reviews happen at every turn end; evaluate automation for log summarisation.
- Revisit whether default subagent launches should keep `--dangerously-bypass-approvals-and-sandbox` or adopt a safer profile.
- Document subagent-session guardrails before each launch, including the updated `make monitor_subagents` requirement.
- Finish CI auditor follow-ups (restore markers/notebooks on feature branches and validate audits run from the correct branch).
- Extend the orchestration manual for multi-subagent coordination, consolidated deliverable retrieval, and human supervision expectations.
- Reinforce that senior architect reviews must be captured after the final commit (or regenerated) to avoid stale hash loops during merge.
- Define pruning/archival guidance for long-lived artefacts like `docs/progress/*.md` and `docs/agents/subagent-registry.json`.
- Prototype a subagent completion sentinel so the monitor loop no longer relies solely on log heartbeats.
- Remove the unused `docs/logs` deliverable from senior-review templates and scripts.
- Clean up duplicate `local` declarations in `.agents/bin/launch_subagent.sh:create_runner`.
- Update `docs/agents/templates/senior_architect_scope.md` to reference `origin/feature/publish-repo`.
- Rationalise backlog management across `docs/PLAN.md`, branch checklists, and Next Actions so TODOs appear in a single canonical location.
- Automate senior-review log harvest so sandbox cleanup records transcripts before panes close (preventing evidence loss).
- Pilot the context capsule workflow (design/templates/helpers) introduced on codex/investigate-context-cloning-for-subagents and evaluate integration points with existing progress logging.
