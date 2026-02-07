# Process Smoke Test Scope

## Context
- Disposable sandbox seeded with the Parallelus process docs.
- Goal: run the full smoke checklist autonomously.

## Objectives
- [ ] Confirm repository state with `make read_bootstrap`.
- [ ] Create the feature branch via `make bootstrap slug=process-smoke` ➜ checkpoint
- [ ] Start a session using prompt "Process smoke test scenario" ➜ checkpoint
- [ ] Add "Smoke test updated at <date>" under the README Quick Start heading ➜ checkpoint
- [ ] Update the branch plan/progress notebooks to reflect the README change.
- [ ] Append a progress log entry summarising the work so far ➜ checkpoint
- [ ] Run `make ci` and resolve issues ➜ checkpoint
- [ ] Merge using `make merge slug=process-smoke` and ensure notebooks are removed.
- [ ] Confirm `git status` is clean with no feature notebooks remaining.

## Acceptance Criteria
- README, plan, progress, and CI updates committed.
- `make ci` passes after any required formatting fixes.
- Branch merged back to main via the helper; sandbox left clean.

## Notes
- Work autonomously—no manual "proceed" prompts should be needed.
- Leave a detailed summary in `docs/branches/feature-process-smoke/PROGRESS.md` before exiting.
