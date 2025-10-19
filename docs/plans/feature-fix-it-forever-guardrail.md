# Branch Plan — feature/fix-it-forever-guardrail

## Objectives
- Enforce fix-it-forever philosophy across docs and tooling.
- Require senior architect reviews to run via the subagent launcher.
- Consolidate review baseline guidance and archive manual reviews.
- Validate that no regressions slipped in (README, manuals, CI deps/tests).

## Checklist
- [x] Document objectives.
- [x] Update AGENTS.md with fix-it-forever reference to manuals.
- [x] Promote the continuous-improvement playbook into `docs/agents/manuals/`.
- [x] Tighten agents-turn-end to block note-only updates.
- [x] Enhance agents-merge for doc-only allowances and subagent provenance.
- [x] Archive manual senior reviews and document baseline tag.
- [x] Confirm README next-steps section still points operators correctly.
- [x] Verify shared manuals (continuous improvement, etc.) exist in new location and references resolve.
- [x] Reconfirm CI dependencies/tests (requirements.txt, tests/test_basic.py) intact so `make ci` passes.

## Next Actions
- Validate the updated manual links (README and notebooks) then rerun the senior architect review via the subagent launcher once cleared.
- Capture the approved review artifact and update notebooks/checklists to reflect the outcome.
- Package the branch for a pull request to `main` (push branch, draft PR summary, note guardrail compliance) instead of performing a local merge.
