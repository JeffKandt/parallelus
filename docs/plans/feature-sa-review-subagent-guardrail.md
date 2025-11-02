# Branch Plan — feature/sa-review-subagent-guardrail

## Objectives
- Ship subagent guardrails (review provenance, monitoring defaults, tmux hygiene) and merge safely.
- Ensure retrospective/CI audit artifacts stay in sync before folding notebooks.

## Checklist
- [x] Restore plan/progress notebooks after merge-cleanup attempt.
- [ ] Re-run CI audit and capture report.
- [ ] Complete merge once guardrails pass.

## Next Actions
- Run make turn_end after CI audit to refresh the marker.
