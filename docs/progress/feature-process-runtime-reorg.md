# Branch Progress — feature/process-runtime-reorg

## 2026-02-04 20:05:30 UTC
**Objectives**
- implement process-vs-runtime reorg items from `docs/deployment-upgrade-and-layout-notes.md`
- update Beads integration docs based on current design discussion

**Work Performed**
- reviewed `AGENTS.md` guardrails and ran `make read_bootstrap`
- bootstrapped branch `feature/process-runtime-reorg` and started session `20251049-20260204200536-b8e8c8`
- captured initial objectives/checklist updates in the branch plan notebook

**Artifacts**
- `docs/plans/feature-process-runtime-reorg.md`
- `docs/progress/feature-process-runtime-reorg.md`

**Next Actions**
- review `docs/deployment-upgrade-and-layout-notes.md` and enumerate concrete reorg changes to implement
- update `docs/agents/integrations/beads.md` to reflect the branch/worktree semantics and “optional Beads” adoption strategy

## 2026-02-04 20:12:10 UTC
**Objectives**
- implement initial “process vs runtime” adjustments (reduce PR noise from runtime artifacts)
- update Beads docs based on current discussion (sync branch semantics; optional adoption)

**Work Performed**
- updated failures collection to scan runtime guardrail-run paths under `.parallelus/guardrails/runs/` (while retaining legacy `docs/guardrails/runs/` scanning)
- updated the rollout-extraction tool default output to `.parallelus/guardrails/runs/extracted` when no active session artifacts directory is available
- updated `docs/deployment-upgrade-and-layout-notes.md` and `docs/agents/project/structure.md` to clarify runtime-vs-tracked placement expectations
- updated `docs/agents/integrations/beads.md` to cover branches/worktrees vs “done” semantics, and to clarify the “optional Beads” pilot flow

**Artifacts**
- `.agents/bin/collect_failures.py`
- `.agents/bin/extract_codex_rollout.py`
- `docs/deployment-upgrade-and-layout-notes.md`
- `docs/agents/project/structure.md`
- `docs/agents/integrations/beads.md`

**Next Actions**
- run `make ci` and record results
- continue implementing any remaining reorg items from `docs/deployment-upgrade-and-layout-notes.md` that we agree are in-scope for this branch

## 2026-02-04 20:12:55 UTC
**Objectives**
- validate the branch via `make ci`

**Work Performed**
- ran `make ci` and confirmed the full suite passed

**Next Actions**
- decide whether any additional “process vs runtime” layout moves are needed beyond the current “write new run artifacts to `.parallelus/`” convention

## 2026-02-04 20:18:10 UTC
**Objectives**
- draft a concrete plan for the process/runtime reorg and future migrations without moving files yet

**Work Performed**
- added `docs/deployment-upgrade-and-layout-PLAN.md` describing the target layout:
  - `docs/` reserved for project docs except `docs/PLAN.md`, `docs/PROGRESS.md`, and `docs/branches/<slug>/…`
  - all other Parallelus-owned tracked artifacts move under `parallelus/…`
  - runtime/high-churn artifacts live under `./.parallelus/…` (gitignored)
- captured an initial mapping of existing paths to their intended destinations and recorded open questions for review

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

**Next Actions**
- review and refine the `parallelus/` and `./.parallelus/` subfolder structure until the plan is final
- confirm the migration mapping (what moves, what remains as explicit `docs/` exceptions)

## 2026-02-04 20:24:40 UTC
**Objectives**
- update the layout plan so `parallelus/` is replaceable on upgrade and project-specific evidence lives under `docs/parallelus/`

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` to split:
  - `parallelus/…` as an upstream-owned, replaceable bundle (manuals/templates/etc.)
  - `docs/parallelus/…` as project-owned instance artifacts (reviews, retrospectives, curated run archives)
- updated the migration mapping accordingly (reviews + self-improvement move under `docs/parallelus/…`)

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

**Next Actions**
- review and iterate on the `docs/parallelus/` subfolder structure and any additional `docs/` exceptions we want to allow

## 2026-02-04 20:31:20 UTC
**Objectives**
- update the plan to relocate the `.agents/` engine under `parallelus/engine/` to avoid collisions in consuming projects

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` to introduce `parallelus/engine/` as the future home for the current `.agents/` tree
- added a migration mapping section for `.agents/**` → `parallelus/engine/**` plus new open questions about naming and bundle placement

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`
