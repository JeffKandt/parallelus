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
- [ ] update branch plan/progress notebooks with outcomes + follow-ups

## Next Actions
- start `PR-01` from the execution plan (sentinel schema + namespace detection + tests)
- decide whether to mirror PR slices as Beads items for queue visibility
- keep implementation strictly phased (no broad file moves before PR-01/PR-02 gates pass)
