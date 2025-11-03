# Branch Plan — feature/sa-review-subagent-guardrail

## Objectives
- Land guardrail fixes (subagent provenance, monitoring defaults, retrospective ordering) and merge safely after approvals.
- Keep CI audit artifacts current through final merge.

## Checklist
- [x] Capture senior review approvals for guardrail updates.
- [x] Restore notebooks and rerun CI audit after adjustments.
- [ ] Complete merge to main once guardrails pass.

## Next Actions
- [x] Implement monitor auto-exit behaviour (e.g. exit after consecutive stale-heartbeat polls) so the main agent regains control once senior-review logs go quiet.
- [x] Rework the `AGENTS_MERGE_SKIP_RETRO` flow to log justification after checkout without staging files on the feature branch, then rerun the senior architect review.
- [ ] Once guardrails and audit skip flow are approved, rerun required audits and complete the merge back to `main`.
- [ ] Relaunch the senior architect review on the updated commit after pushing the fixes and harvest the new approval.
