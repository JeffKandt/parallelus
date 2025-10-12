# Subagent Scope

## Context
- Brief description of the parent feature/goal
- Links to relevant specs or tickets

## Objectives
- [ ] Item 1
- [ ] Item 2

## Acceptance Criteria
- Detail the conditions that must be met before the main agent considers the work complete.

## Branch & Environment
- Suggested branch slug: `feature/example`
- Special environment setup (if any):

## Notes
- Additional guidance, edge cases, or references for the subagent.
- Spell out whether the subagent should merge via `make merge slug=…` or leave
  that step for the main agent. The throwaway smoke harness is the only flow
  that typically merges inside the sandbox.
- Mention explicitly that the subagent should keep working without waiting for
  additional approval once the checklist is defined. If it feels blocked,
  assume the answer is “Continue.” Skip standalone status updates after
  bootstrap/read_bootstrap—go straight to the next checklist item.
