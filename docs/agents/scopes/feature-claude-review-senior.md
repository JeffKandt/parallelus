# Senior Architect Review Scope — feature/claude-review

## Context
- **Branch:** feature/claude-review
- **Commit under review:** $(git rev-parse HEAD)
- **Remote check:** Confirm HEAD is pushed to origin/feature/claude-review before proceeding.
- **Focus:** Guardrail monitor fixes, harness archiving workflow, documentation updates, and new automated tests introduced on 2025-10-27.

## Preconditions
- Working tree is clean and matches the pushed commit.
- `make ci` has passed (see latest run in docs/progress).
- No additional changes will be added while the review is in progress.

## Objectives
- [ ] Audit `.agents/bin/agents-monitor-loop.sh` runtime/heartbeat handling, tmux nudge integration, and exit semantics to confirm manual-attention paths are safe and observable.
- [ ] Review `.agents/bin/agents-monitor-real.sh` archive workflow (ENTRY_SUMMARIES, `archive_entry`) to ensure transcripts and deliverables are persisted before cleanup and that failure modes are logged.
- [ ] Verify `.agents/tests/monitor_loop.py` expectations align with the new behaviour (non-zero exit on alerts) and cover representative scenarios.
- [ ] Check documentation updates (`AGENTS.md` operational gate, `docs/PROGRESS.md` entries) for clarity and completeness.
- [ ] Inspect the new run artefacts under `docs/guardrails/runs/20251027-194902-real-interactive-success/` for consistency (session log, transcript, summary, deliverables).

## Key Artifacts
- `.agents/bin/agents-monitor-loop.sh`
- `.agents/bin/agents-monitor-real.sh`
- `.agents/tests/monitor_loop.py`
- `AGENTS.md`
- `docs/guardrails/runs/20251027-194902-real-interactive-success/`
- `docs/PLAN.md`, `docs/PROGRESS.md` (post-folding state)
- Prior review baseline: `docs/reviews/feature-claude-review-2025-10-20.md` (if present) or latest approved commit on this branch.

## Deliverable
- New review report at `docs/reviews/feature-claude-review-2025-10-27.md` capturing:
  - `Reviewed-Branch: feature/claude-review`
  - `Reviewed-Commit: $(git rev-parse HEAD)`
  - Decision and severity-labelled findings (if any)
  - Recommendations / follow-up actions

_Operate read-only apart from the review report above._
