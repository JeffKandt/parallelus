# Branch Plan — feature/sa-review-subagent-guardrail

## Objectives
- Land guardrail fixes (subagent provenance, monitoring defaults, retrospective ordering) and merge safely after approvals.
- Keep CI audit artifacts current through final merge.

## Checklist
- [x] Capture senior review approvals for guardrail updates.
- [x] Restore notebooks and rerun CI audit after adjustments.
- [ ] Complete merge to main once guardrails pass.

## Next Actions
- Run `make turn_end` after the final audit/report is saved so the marker head stays aligned.

- [ ] post-audit merge prep
