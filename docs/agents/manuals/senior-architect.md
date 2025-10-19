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
.agents/bin/subagent_manager.sh launch \
  --type throwaway \
  --slug senior-review \
  --role senior_architect
```

The helper lives under `.agents/bin/`; `make run_senior_review` is a convenient
wrapper (when available). The subagent window will generate the markdown review
and save it to `docs/reviews/<branch>-<date>.md`.

## Operator Expectations

1. Stage and commit the work under review before launching the subagent.
2. Run the launcher above from the repo root (or add `.agents/bin` to your
   `PATH`); keep the tmux pane open until the agent reports completion.
3. Inspect the generated review, ensure findings are addressed, and commit it.
4. The launcher registers the review file as a deliverable; once the monitor
   exits, run `.agents/bin/subagent_manager.sh harvest --id <id>` followed by
   `cleanup` so panes do not linger.
5. Do not hand-write review markdowns; merges are blocked unless the review
   provenance shows `Session Mode: synchronous subagent`.
6. The launcher refuses to send new instructions to a stale sandbox after
   `HEAD` moves; launch a fresh subagent for each follow-up commit.
7. Remind the reviewer that their session is read-only apart from the review
   file—no plan/progress edits, `make bootstrap`, or other helpers that change
   the workspace are permitted during the review run.
8. Start monitoring with `make monitor_subagents ARGS="--id <id>"` (rather than
   calling `agents-monitor-loop.sh` directly); the make target keeps standard
   thresholds so you do not have to babysit it.
9. If the progress log still contains placeholder text (“pending update”,
   TODOs, etc.), halt the review and ask the main agent to update the summary
   before proceeding.
