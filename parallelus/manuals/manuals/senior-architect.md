# Senior Architect Review Manual

Senior architect reviews **must** be executed via the provided subagent launcher.
This ensures the canonical prompt, constraints, and audit logging run in an
isolated tmux pane.

## Launch Command

```bash
PATH="$PWD/.venv/bin:$PATH" make senior_review_preflight
```

`make senior_review_preflight` runs the serialized preflight pipeline
(`retro-marker` -> `collect_failures` -> local commit-aware auditor ->
`verify-retrospective`) and then launches the senior-review subagent. For
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
4. The launcher now registers the review file as a deliverable and the monitor
   exits once it detects the pending harvest; as soon as the loop stands down,
   run `parallelus/engine/bin/subagent_manager.sh harvest --id <id>` followed by `cleanup`
   so the pane never lingers between runs.
5. Never parallelize `retro-marker` and `collect_failures`; timestamp races
   produce stale retrospective artifacts. Use `make senior_review_preflight` to
   keep ordering deterministic.
6. Senior-review launch now enforces retrospective freshness: the current marker
   `head` must match branch `HEAD`, and the marker-matched audit report must
   reference the same branch/timestamp. If this fails, refresh marker + auditor
   artifacts for the current commit before relaunching.
7. Do not hand-write review markdowns; merges will be blocked unless the review
   provenance indicates a subagent run.
8. The helper refuses to send new instructions to a stale review sandbox once
   the feature branch `HEAD` moves; launch a fresh subagent for each follow-up
   commit instead of reusing the previous pane.
9. Remind the reviewer that their session is read-only apart from the review
   file—no plan/progress edits, `make bootstrap`, or other helpers that change
   the workspace are permitted during the review run.
10. Start monitoring with `make monitor_subagents ARGS="--id <id>"` (rather than
   calling `agents-monitor-loop.sh` directly); the make target keeps the loop
   running with the standard thresholds so you do not have to babysit it.
11. If the progress log still contains placeholder text ("pending update", TODOs,
   etc.), halt the review and ask the main agent to update the summary before
   proceeding.
12. If `review-preflight` reports `awaiting_manual_launch`, run the generated
   sandbox launcher (`<sandbox>/.parallelus_run_subagent.sh`) and then continue
   with monitor/harvest/cleanup as normal. Treat this as an expected fallback,
   not an automatic failure.
