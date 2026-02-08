# Senior Architect Review – feature/sa-review-subagent-guardrail

Reviewed-Branch: feature/sa-review-subagent-guardrail
Reviewed-Commit: 364622c2bbad106c230e93308c15bbf76c296a7b
Reviewed-On: 2025-11-03
Decision: changes-required
Reviewer: senior-review-Q4L7MG

## Summary
- Deliverable auto-exit still trips immediately for newly launched runs, so the monitor stops before providing heartbeat or alert coverage.

## Findings
- Severity: Blocker | Area: Monitoring | Summary: `agents-monitor-loop` still treats any `deliverables_status` other than `""`, `-`, `waiting`, or `harvested` as "ready"; fresh runs start in `pending`, so the new commit triggers `auto_exit_candidate` on the first poll and the monitor exits without observing anything.  
  - Evidence: `.agents/bin/agents-monitor-loop.sh:620-676`  
  - Recommendation: Only enqueue IDs when the status is explicitly `ready` (or another new state that signifies confirmed artifacts), or re-initialize deliverables to `waiting` until `print_status` verifies new files exist.
- Severity: High | Area: Deliverables registry | Summary: `print_status` flips the registry-level `deliverables_status` to `ready` as soon as any single deliverable produces files, even if other declared deliverables remain `pending`, so the monitor will still exit early.  
  - Evidence: `.agents/bin/subagent_manager.sh:240-275`  
  - Recommendation: Aggregate across the full deliverables set—only promote the row to `ready` once every deliverable reports `ready`, otherwise leave the registry entry in `pending` (or introduce a `partial` intermediate state).

## Tests & Evidence Reviewed
- `git show 364622c2bbad106c230e93308c15bbf76c296a7b`
- Manual inspection of `.agents/bin/agents-monitor-loop.sh` and `.agents/bin/subagent_manager.sh`

## Follow-Ups / Tickets
- [ ] Rework deliverable readiness detection so monitors stay active until all declared artifacts exist.

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
