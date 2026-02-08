# Senior Architect Review – feature/sa-review-subagent-guardrail

Reviewed-Branch: feature/sa-review-subagent-guardrail
Reviewed-Commit: 2264ab84af461d0edf109c5b1bf889c7669f455a
Reviewed-On: 2025-11-03
Decision: changes-required
Reviewer: senior-review-IcFRSH

## Summary
- Deliverable-driven auto-exit now fires as soon as a subagent with declared deliverables enters the loop, so the monitor quits before providing any heartbeat or alert coverage.

## Findings
- Severity: High | Area: Monitoring | Summary: The new deliverables shortcut treats any non-empty `deliverables_status` (including the default `pending`) as “ready,” so a run launched with `--deliverable src[:dest]` exits the monitor on the very first poll even though nothing has been produced yet. This regresses the safety net for every deliverable-based launch.  
  - Evidence: `.agents/bin/agents-monitor-loop.sh:618-669`, `.agents/bin/subagent_manager.sh:903-1016`  
  - Recommendation: Distinguish “deliverable declared” from “deliverable produced” (e.g. require an explicit `ready` state or verify new files via glob/baseline) before setting `deliverable_complete`, so monitors only exit once artifacts actually exist.

## Tests & Evidence Reviewed
- `git show 2264ab84af461d0edf109c5b1bf889c7669f455a`
- Manual inspection of `.agents/bin/agents-monitor-loop.sh` and `.agents/bin/subagent_manager.sh`

## Follow-Ups / Tickets
- [ ] Rework deliverable auto-exit detection so pending specs do not terminate monitoring before artifacts appear.

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
