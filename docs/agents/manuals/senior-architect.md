# Senior Architect Review Manual

Senior architect reviews **must** be executed via the provided subagent launcher.
This ensures the canonical prompt, constraints, and audit logging run in an
isolated tmux pane.

## Launch Command

```bash
subagent_manager.sh launch \
  --type throwaway \
  --slug senior-review \
  --role senior_architect
```

The helper lives under `.agents/bin/`; `make run_senior_review` (if available)
wraps this command. The subagent window will generate the markdown review and
save it to `docs/reviews/<branch>-<date>.md`.

## Operator Expectations

1. Stage and commit the work under review before launching the subagent.
2. Update `SUBAGENT_SCOPE.md` in the sandbox (or template copy) so the branch
   name, objectives, and artifacts match the feature you are reviewing.
3. Run the launcher above; keep the tmux pane open until the agent reports
   completion. To monitor progress, run `make monitor_subagents --id
   <subagent-id>`.
4. Inspect the generated `docs/reviews/<branch>-<date>.md`, ensure findings are
   addressed, and commit it alongside any doc housekeeping.
5. Do not hand-write review markdowns. Merges are blocked unless the review
   shows `Session Mode: synchronous subagent` in its provenance.
