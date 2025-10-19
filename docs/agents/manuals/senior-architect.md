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

The helper lives under `.agents/bin/`; `make run_senior_review` is a convenient
wrapper if available. The subagent window will generate the markdown review and
save it to `docs/reviews/<branch>-<date>.md`.

## Operator Expectations

1. Stage and commit the work under review before launching the subagent.
2. Run the command above; keep the tmux pane open until the agent says the
   review is complete.
3. Inspect the generated review, ensure findings are addressed, and commit it.
4. Do not hand-write review markdowns; merges will be blocked unless the review
   provenance indicates a subagent run.
