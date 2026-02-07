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
- [x] harden subagent review/auditor orchestration after `PHASE-02` review-loop incidents (harvest baseline rewrites, cleanup guard, context pinning)

## Next Actions
- execute `PHASE-03` from `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md` only (docs namespace migration + tracked artifact relocation for notebooks/reviews/self-improvement paths)
- capture `PHASE-03` gate evidence in branch progress (bootstrap/turn_end/fold-progress/merge precheck compatibility under the migrated docs layout)
- add retrospective preflight guardrail to block review progression when `marker.head != HEAD` or marker-matched report is missing (auditor follow-up)
- tighten marker generation/session discipline so marker metadata always includes `session_id` and `session_console` (auditor follow-up)
- decide whether to mirror phase slices as Beads items for queue visibility
- keep implementation strictly phased (do not start `PHASE-04+` until `PHASE-03` is approved)
