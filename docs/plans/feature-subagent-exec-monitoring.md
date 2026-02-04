# Branch Plan — feature/subagent-exec-monitoring

## Objectives
- improve exec-mode subagent pane visibility (more informative progress than `[exec] item.completed`)
- ensure subagent cleanup reliably closes leftover tmux panes
- capture a concrete recommendation for Beads integration and how it interacts with Parallelus plan/progress notebooks
- close out this branch and merge it back to `main` once merge gates are satisfied

## Checklist
- [x] render exec events in a TUI-like, human readable format (no hidden reasoning text)
- [x] add cleanup fallback to kill panes by title when registry handle is missing
- [x] add mid-flight checkpoint log (`subagent.progress.md`) and prefer it in status/tailing
- [x] update notebooks and validate changes
- [x] write Beads integration recommendation under `docs/`
- [x] run merge gates (retrospective report, senior architect review)
- [ ] fold branch notebooks + merge to `main`

## Next Actions
- keep iterating on checkpoint UX (formatting + redaction) as needed
- validate merge-time audit workflow:
  - run `make turn_end`, `make collect_failures`, and a CI auditor subagent on a throwaway branch
  - confirm `make merge` blocks when failures summary or audit report is missing
- land this branch: fold notebooks + merge
