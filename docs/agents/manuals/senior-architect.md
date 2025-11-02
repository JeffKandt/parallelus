# Senior Architect Review Manual

Senior architect reviews **must** be executed via the provided subagent launcher.
This ensures the canonical prompt, constraints, and audit logging run in an
isolated tmux pane.

## Launch Command

```bash
.agents/bin/subagent_manager.sh launch \
  --type throwaway \
  --slug senior-review \
  --role senior_architect
```

The helper lives under `.agents/bin/`; `make run_senior_review` is a convenient
wrapper if available. The subagent window will generate the markdown review and
save it to `docs/reviews/<branch>-<date>.md`.

## Operator Expectations

1. Stage and commit the work under review before launching the subagent.
2. Run the command above from the repo root (or add `.agents/bin` to your
   `PATH`); keep the tmux pane open until the agent says the
   review is complete.
3. Inspect the generated review, ensure findings are addressed, and commit it.
4. Do not hand-write review markdowns; merges will be blocked unless the review
   provenance indicates a subagent run.
5. After harvesting the review, close the senior-review pane (e.g. `tmux kill-pane`) so future launches start clean. Before launching a new run, confirm no previous pane remains; if `tmux list-panes` shows `*-senior-review` (or a slug-specific pane), close it or run `subagent_manager.sh cleanup --id <id>` first.
6. Remind the reviewer that their session is read-only apart from the review
   file—no plan/progress edits, `make bootstrap`, or other helpers that change
   the workspace are permitted during the review run.
7. Start monitoring with `make monitor_subagents ARGS="--id <id>"` (rather than
   calling `agents-monitor-loop.sh` directly); the make target keeps the loop
   running with the standard thresholds so you do not have to babysit it.
