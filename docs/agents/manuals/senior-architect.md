# Senior Architect Review Manual

Senior architect reviews **must** be executed via the provided subagent launcher.
This ensures the canonical prompt, constraints, and audit logging run in an
isolated tmux pane.

> Baseline: the last formally approved subagent review on `main` is commit
> `c2eab8b0c9d86b01a14b4c0e7073cddffb010e70` (feature/process-review-gate,
> 2025-10-12). Use that commit when you need to diff against the most recent
> subagent-reviewed state.

## Launch Command

```bash
subagent_manager.sh launch \
  --type throwaway \
  --slug senior-review \
  --role senior_architect
```

`make run_senior_review` (if available) wraps this command.

## Operator Expectations

1. Stage and commit the work under review before launching the subagent.
2. Run the launcher above; keep the tmux pane open until the agent reports
   completion.
3. Inspect the generated `docs/reviews/<branch>-<date>.md`, ensure findings are
   addressed, and commit it alongside any doc housekeeping.
4. Do not hand-write review markdowns. Merges are blocked unless the review
   shows `Session Mode: synchronous subagent` in its provenance.
