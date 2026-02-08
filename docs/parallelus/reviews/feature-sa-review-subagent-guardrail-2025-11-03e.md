# Senior Architect Review – feature/sa-review-subagent-guardrail

Reviewed-Branch: feature/sa-review-subagent-guardrail
Reviewed-Commit: 77dd7b175b528b50dac1a4d44071d1b92d85fd4e
Reviewed-On: 2025-10-12
Decision: approved
Reviewer: senior-review-KR19QX

## Summary
- Deliverable auto-exit now forces a non-zero monitor exit and surfaces the guardrail banner so harvest back-pressure is preserved (`.agents/bin/agents-monitor-loop.sh:682`, `.agents/bin/agents-monitor-loop.sh:730`).
- Consecutive-stale auto-exit tracks per-ID heartbeat counts and defers manual-attention alerts until the threshold is met, letting the loop exit with the intended auto-exit message (`.agents/bin/agents-monitor-loop.sh:701`, `.agents/bin/agents-monitor-loop.sh:739`).
- Smoke tests capture both regressions, and the targeted pytest checks pass in this sandbox (`.agents/tests/monitor_loop.py:293`, `.agents/tests/monitor_loop.py:345`).

## Findings
- None.

## Tests & Evidence Reviewed
- `pytest .agents/tests/monitor_loop.py::test_auto_exit_after_consecutive_stale_polls`
- `pytest .agents/tests/monitor_loop.py::test_auto_exit_on_deliverable_ready`
- Manual inspection of `.agents/bin/agents-monitor-loop.sh` and `.agents/tests/monitor_loop.py`

## Residual Risks
- Monitor auto-exit on consecutive stale polls still depends on setting `MONITOR_AUTO_EXIT_STALE_POLLS`; ensure ops keep that override in scope when they expect self-unwinding behaviour.

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
