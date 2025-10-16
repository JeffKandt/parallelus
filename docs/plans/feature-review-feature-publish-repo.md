# Branch Plan — feature/review-feature-publish-repo

## Objectives
- Audit the feature publish automation and supporting tooling for regressions before merge.
- Validate tmux overlay helpers and prompt handling to ensure they do not leak control sequences into shells.
- Capture review findings and required follow-up work in progress logs for maintainers.

## Checklist
- [x] Reproduce the tmux overlay prompt leak and capture the raw escape sequence source.
- [x] Trace the overlay helper scripts/config to the misconfigured prompt string.
- [x] Implement or document the fix needed to stop injecting terminal identification data.
- [x] Update plan/progress notebooks with findings and follow-up actions.
- [ ] Summarize review outcomes for senior architect hand-off.

## Next Actions
- Decide how to resolve the CI auditor follow-ups (restore feature/publish-repo marker + notebooks, ensure audits run from that branch) and record the plan.
- Re-run targeted validation (CI + `make monitor_subagents`) to demonstrate the heartbeat fix and capture evidence for senior architect sign-off.
- Refresh `docs/agents/project/` so it no longer references the Interruptus project; add any remaining TODOs to the docs worklist.
- Harden subagent launch permissions by codifying allowed write paths (e.g., review-specific `allowed_writes` entries and automated verification).
- Exercise and document the new deliverable harvest workflow (`subagent_manager.sh --deliverable` + `harvest`) during the next senior-review run.
- Clarify multi-subagent coordination in the orchestration manual (harvest + restart flow for staggered completions) and sync summary back to `docs/PLAN.md`.
- Review handling of ever-growing artifacts (`docs/progress/*.md`, `docs/agents/subagent-registry.json`) and design pruning/archival guidance.
- Rework `docs/agents/subagent-session-orchestration.md` to cover parallel coding subagents, consolidated deliverable retrieval, and clearer human-supervision expectations.
- Validate whether the main agent should continue supervising interactive subagents or pivot to a non-interactive launch path for reviews.
- Evaluate renaming the "scope file" concept to "assignment file" and update tooling/docs accordingly.
- Prototype a subagent completion signal (e.g., sentinel file or expected deliverable presence) so the monitor can detect finished runs without depending solely on log heartbeats.
- Remove the unnecessary `docs/logs` deliverable from senior-review launches and update tooling/docs to expect only `docs/reviews/` outputs.
