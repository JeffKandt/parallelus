# Branch Plan — feature/subagent-exec-monitoring

## Objectives
- improve exec-mode subagent pane visibility (more informative progress than `[exec] item.completed`)
- ensure subagent cleanup reliably closes leftover tmux panes

## Checklist
- [x] render exec events in a TUI-like, human readable format (no hidden reasoning text)
- [x] add cleanup fallback to kill panes by title when registry handle is missing
- [ ] add mid-flight checkpoint log (`subagent.progress.md`) and prefer it in status/tailing
- [ ] update notebooks and validate changes

## Next Actions
- wire checkpoint log into prompts and monitoring, then validate on a real subagent run
