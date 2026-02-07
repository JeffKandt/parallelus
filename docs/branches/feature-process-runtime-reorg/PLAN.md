# Branch Plan — feature/process-runtime-reorg

## Objectives
- implement the process-vs-runtime documentation and layout reorgs described in `docs/deployment-upgrade-and-layout-notes.md`
- update Beads integration guidance to reflect the “sync branch + optional usage” stance and how it interacts with Parallelus merge governance
- keep the repo merge workflow intact (CI, audits, senior review) with minimal disruption

## Checklist
- [x] read `docs/deployment-upgrade-and-layout-notes.md` and enumerate concrete changes to land
- [x] implement the agreed “process vs runtime” reorg (docs + scripts) and keep compatibility where possible
- [x] update Beads docs (`docs/agents/integrations/beads.md`) based on current discussion (branch/worktree semantics, optional usage strategy, pilot flow)
- [x] run `make ci` and record results in the progress log
- [x] draft and iterate on `docs/deployment-upgrade-and-layout-PLAN.md` until the layout plan is final (no file moves yet)
- [x] create detailed implementation slicing in `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`
- [x] expand open questions in the layout plan (pros/cons/recommendations; terminology; naming collision notes)
- [x] update branch plan/progress notebooks with outcomes + follow-ups
- [x] execute `PHASE-01` (sentinel schema + namespace detection + acceptance gate + approved senior review)
- [x] execute `PHASE-02` (session path resolver + dual-read compatibility + acceptance gate validations)
- [x] execute `PHASE-03` (docs namespace migration + tracked artifact relocation + acceptance gate + approved senior review)
- [ ] execute `PHASE-04` (engine/manual relocation + hardcoded path rewrite + acceptance gate + approved senior review)
- [x] harden subagent review/auditor orchestration after `PHASE-02` review-loop incidents (harvest baseline rewrites, cleanup guard, context pinning)
- [x] enforce retrospective/head freshness and CI-auditor timeout abort handling as default guardrails (not prompt-specific reminders)
- [x] harden session handling for stateless-shell environments (runtime session pointers + turn_end fallback + marker session metadata recovery)
- [x] harden `make read_bootstrap` logging gate for stateless-shell environments (session context helper + pointer fallback)
- [x] implement post-phase retrospective/senior-review remediations (serialized preflight command, no-parallel policy docs, local commit-aware auditor mode)

## Next Actions
- close the `PHASE-04` review loop by landing launch-state remediations from the latest senior review and rerunning review on updated `HEAD`
- keep validation scoped to the changed review/preflight scripts plus required `PHASE-04` broader gate (`make ci`)
- capture refreshed gate evidence in canonical branch notebooks and mark `PHASE-04` complete only after explicit approved review artifact
