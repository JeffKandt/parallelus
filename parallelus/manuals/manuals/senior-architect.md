# Senior Architect Review Manual

Senior architect reviews **must** be executed via the provided subagent launcher.
This ensures the canonical prompt, constraints, and audit logging run in an
isolated tmux pane.

## Launch Command

```bash
PATH="$PWD/.venv/bin:$PATH" make senior_review_preflight_run ARGS="--auto-clean-stale"
```

For non-tmux/headless runs, `make senior_review_preflight_run` is the default:
it runs preflight, auto-cleans stale `awaiting_manual_launch` review entries
when no sandbox process appears active (`--auto-clean-stale`), executes the
generated sandbox launcher when status is `awaiting_manual_launch`, then
harvests and cleans up automatically.

If you want launch-only behavior (without wrapper harvest/cleanup), use:

```bash
PATH="$PWD/.venv/bin:$PATH" make senior_review_preflight ARGS="--auto-clean-stale"
```

For
manual launch-only fallback, use:

```bash
PATH="$PWD/.venv/bin:$PATH" parallelus/engine/bin/subagent_manager.sh launch --type throwaway --slug senior-review --role senior_architect
```

The subagent window will generate the markdown review and save it to
`docs/parallelus/reviews/<branch>-<date>.md`.

## Operator Expectations

1. Stage and commit the work under review before launching the subagent.
2. Run the command above from the repo root (or add `parallelus/engine/bin` to your
   `PATH`); keep the tmux pane open until the agent says the
   review is complete.
3. Inspect the generated review, ensure findings are addressed, and commit it.
4. After the final code commit under review (and before any extra notebook-only
   checkpoint commit), refresh retrospective artifacts in strict order on that
   same `HEAD`: `retro-marker` -> `collect_failures.py` -> `retro_audit_local.py`.
   Do not parallelize these commands.
5. The launcher now registers the review file as a deliverable and the monitor
   exits once it detects the pending harvest; as soon as the loop stands down,
   run `parallelus/engine/bin/subagent_manager.sh harvest --id <id>` followed by `cleanup`
   so the pane never lingers between runs.
6. Never parallelize `retro-marker` and `collect_failures`; timestamp races
   produce stale retrospective artifacts. Use `make senior_review_preflight` to
   keep ordering deterministic.
7. Senior-review launch now enforces retrospective freshness: the current marker
   `head` must match branch `HEAD`, and the marker-matched audit report must
   reference the same branch/timestamp. If this fails, refresh marker + auditor
   artifacts for the current commit before relaunching.
8. Do not hand-write review markdowns; merges will be blocked unless the review
   provenance indicates a subagent run.
9. The helper refuses to send new instructions to a stale review sandbox once
   the feature branch `HEAD` moves; launch a fresh subagent for each follow-up
   commit instead of reusing the previous pane.
10. Remind the reviewer that their session is read-only apart from the review
   file—no plan/progress edits, `make bootstrap`, or other helpers that change
   the workspace are permitted during the review run.
11. Start monitoring with `make monitor_subagents ARGS="--id <id>"` (rather than
   calling `agents-monitor-loop.sh` directly); the make target keeps the loop
   running with the standard thresholds so you do not have to babysit it.
12. If the progress log still contains placeholder text ("pending update", TODOs,
   etc.), halt the review and ask the main agent to update the summary before
   proceeding.
13. If `review-preflight` reports `awaiting_manual_launch`, run the generated
   sandbox launcher (`<sandbox>/.parallelus_run_subagent.sh`) and then continue
   with monitor/harvest/cleanup as normal. Treat this as an expected fallback,
   not an automatic failure.
