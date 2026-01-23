# Branch Plan — feature/subagent-exec-monitoring

## Objectives
- improve exec-mode subagent pane visibility (more informative progress than `[exec] item.completed`)
- ensure subagent cleanup reliably closes leftover tmux panes

## Checklist
- [ ] update exec stream filter summaries (command + exit + output hint)
- [ ] add cleanup fallback to kill panes by title when registry handle is missing
- [ ] update notebooks and validate changes

## Next Actions
- implement exec visibility + cleanup fixes
