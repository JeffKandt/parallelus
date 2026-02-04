# Branch Plan — feature/process-runtime-reorg

## Objectives
- implement the process-vs-runtime documentation and layout reorgs described in `docs/deployment-upgrade-and-layout-notes.md`
- update Beads integration guidance to reflect the “sync branch + optional usage” stance and how it interacts with Parallelus merge governance
- keep the repo merge workflow intact (CI, audits, senior review) with minimal disruption

## Checklist
- [x] read `docs/deployment-upgrade-and-layout-notes.md` and enumerate concrete changes to land
- [x] implement the agreed “process vs runtime” reorg (docs + scripts) and keep compatibility where possible
- [x] update Beads docs (`docs/agents/integrations/beads.md`) based on current discussion (branch/worktree semantics, optional usage strategy, pilot flow)
- [ ] update branch plan/progress notebooks with outcomes + follow-ups
- [ ] run `make ci` and record results in the progress log
- [ ] draft and iterate on `docs/deployment-upgrade-and-layout-PLAN.md` until the layout plan is final (no file moves yet)

## Next Actions
- review `docs/deployment-upgrade-and-layout-notes.md` and decide which reorg items are in-scope for this branch
- iterate on `docs/deployment-upgrade-and-layout-PLAN.md` (structure + mapping + open questions)
