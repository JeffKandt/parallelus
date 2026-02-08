# Senior Architect Review Scope — feature/branch-audit-report

## Context
- **Branch:** feature/branch-audit-report
- **Commit under review:** $(git rev-parse HEAD)
- **Remote check:** Confirm HEAD is pushed to origin/feature/branch-audit-report before launching the review.
- **Focus:** Branch audit reporting improvements, fold-progress guardrail enforcement, subagent launcher cleanup, and updated operator documentation.

## Preconditions
- Working tree is clean and matches the pushed commit.
- `make ci` has passed on this commit.
- Plan and progress notebooks have been folded into canonical docs; only committed files listed below differ from `main`.

## Objectives
- [ ] Review `parallelus/engine/bin/report_branches.py` filtering logic (no-merged detection, archive/base branch exclusions, conditional tips) and ensure output formatting is stable.
- [ ] Inspect `parallelus/engine/bin/fold-progress` guardrail changes enforcing turn-end markers prior to folding, including environment override handling and error messaging.
- [ ] Confirm `parallelus/engine/bin/launch_subagent.sh` cleanup removed duplicate `local` declarations without altering environment export behaviour.
- [ ] Validate documentation updates in `AGENTS.md`, `docs/PLAN.md`, and `parallelus/manuals/git-workflow.md` accurately reflect the new folding requirement.
- [ ] Verify `docs/PROGRESS.md` captures the folded entries for the branch and that no branch notebooks remain.

## Key Artifacts
- `parallelus/engine/bin/report_branches.py`
- `parallelus/engine/bin/fold-progress`
- `parallelus/engine/bin/launch_subagent.sh`
- `AGENTS.md`
- `docs/PLAN.md`
- `docs/PROGRESS.md`
- `parallelus/manuals/git-workflow.md`

## Deliverable
- Create `docs/parallelus/reviews/feature-branch-audit-report-2025-11-03.md` containing:
  - `Reviewed-Branch: feature/branch-audit-report`
  - `Reviewed-Commit: $(git rev-parse HEAD)`
  - Decision, severity-labelled findings, and recommended follow-ups.

_Operate read-only apart from the review deliverable above._
