# Senior Architect Review – feature/sa-review-subagent-guardrail

Reviewed-Branch: feature/sa-review-subagent-guardrail
Reviewed-Commit: de7688d9403b7a78d76e311a53e9b72ae552e863
Reviewed-On: 2025-11-03
Decision: changes-required
Reviewer: senior-review-yI4ZT4

## Summary
- Auto-exit coverage was broadened for both deliverable-ready runs and persistently stale monitors, but the implementation still trips the original guardrails and the new smoke expectations.

## Findings
- Severity: Blocker | Area: Monitor Loop | Summary: Deliverable-ready auto exit now returns success, so the monitor no longer fails closed when a review deliverable is ready.  
  - Evidence: `pytest .agents/tests/monitor_loop.py::test_auto_exit_on_deliverable_ready` fails because the script exits `0` after emitting `[monitor] Deliverables ready ...`, whereas the updated smoke test (and our gating policy) require a non-zero exit to keep the pipeline stalled until the review is harvested (`.agents/bin/agents-monitor-loop.sh:707-714`).  
  - Recommendation: Treat the deliverable auto-exit as an alerting condition—propagate `OVERALL_ALERT=1` (or otherwise force a non-zero exit) so the monitor preserves back-pressure when work remains.
- Severity: Blocker | Area: Monitor Loop | Summary: Consecutive-stale auto-exit never fires; the loop still bails on the first heartbeat violation instead of waiting for the configured number of stale polls.  
  - Evidence: `pytest .agents/tests/monitor_loop.py::test_auto_exit_after_consecutive_stale_polls` and `::test_auto_exit_accepts_leading_zero_value` both fail because the script emits `requires manual attention (reason: log)` after the first poll and never prints the `[monitor] Auto-exit triggered ...` banner. The guard short-circuits inside `investigate_alerts(...)` before the stale counters can trigger (`.agents/bin/agents-monitor-loop.sh:642-735`).  
  - Recommendation: Defer the fatal log alert until after the stale counter has met `MONITOR_AUTO_EXIT_STALE_POLLS`, or otherwise prioritize the new auto-exit path so those tests (and real monitors) see the intended release message.

## Tests & Evidence Reviewed
- `pytest .agents/tests/monitor_loop.py::test_auto_exit_on_deliverable_ready`
- `pytest .agents/tests/monitor_loop.py::test_auto_exit_after_consecutive_stale_polls`
- `pytest .agents/tests/monitor_loop.py::test_auto_exit_accepts_leading_zero_value`
- `git show de7688d9403b7a78d76e311a53e9b72ae552e863`

## Follow-Ups / Tickets
- [ ] Restore the monitor smoke suite to green by aligning the auto-exit implementation with the new gating expectations (deliverable-ready path and consecutive stale polls).

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
