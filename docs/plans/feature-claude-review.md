# Branch Plan — feature/claude-review

## Objectives
- Capture existing CLAUDE documentation artifacts in `feature/claude-review`.
- Ensure guardrail compliance artifacts (plan/progress updates) accompany the commit.

## Checklist
- [x] Review CLAUDE-related files and confirm contents are ready to commit.
- [x] Update progress log with guardrail acknowledgements and context.
- [x] Commit CLAUDE artifacts with an informative message.

## Next Actions
- Schedule an ad-hoc real-mode validation (`HARNESS_MODE=real tests/guardrails/manual_monitor_real_scenario.sh`) and capture summaries/log tails in the branch progress log.
- Circulate the new guardrail design document for review and capture feedback.
- Monitor branch for additional CLAUDE documentation updates or review feedback.
- Coordinate with reviewers if further changes to CLAUDE artifacts are requested.
- Gather feedback on the hardened subagent monitor (false-positive handling, multi-subagent tracking) and tune thresholds as reliability data accumulates.
- Collect telemetry from tightened monitor thresholds (30/90/240s) and schedule follow-up adjustments if false positives remain low.
- Fold the manual monitor scenario (`tests/guardrails/manual_monitor_scenario.sh`) into the forthcoming automated suite once harness scaffolding is ready.
- Analyse the captured tmux snapshots to catalogue common prompts and drive smarter automated responses.
- Keep the manual monitor harness defaulting to `KEEP_SESSION=1` so tmux panes stay visible during local testing; gather operator feedback on usability.
- Verify the harness’ mirrored layout (left main pane, right stacked subagents) matches production expectations and refine as needed.
- Fix the synthetic monitor harness so the `await-prompt` scenario logs the nudge response, exits cleanly, and leaves no panes open.
- Implement a dual-mode harness switch (`HARNESS_MODE=synthetic|real`) and document when to run the real Codex workflow versus the lightweight regression mode once synthetic coverage is stable.
- Scope automated testing for guardrail tooling per improvement suggestion #1.
- Design shared path pattern configuration to unify documentation-only checks (suggestion #2).
- Draft remaining timeout/recovery enhancements (deliverable manifests, recovery adapter) per suggestion #3.

- [ ] summary
