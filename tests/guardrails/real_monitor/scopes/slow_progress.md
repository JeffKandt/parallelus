# Scenario: slow-progress

This sandbox simulates long-running work without interactive prompts.
Before launching the workload, complete the standard bootstrap flow:

- Run `make read_bootstrap`.
- Review `AGENTS.md` and `.agents/custom/README.md` (plus any manuals they
  explicitly call out for this scope).
- Run `make bootstrap slug=real-slow-progress` so plan/progress notebooks
  exist in the sandbox.
- Capture guardrail acknowledgements and initial objectives in
  `docs/plans/feature-real-slow-progress.md` and
  `docs/progress/feature-real-slow-progress.md`.

1. Run:
   ```bash
   bash tests/guardrails/real_monitor/scripts/slow_progress.sh
   ```
2. The script logs progress approximately every 8 seconds and finishes after processing ten items. No deliverables are produced.
3. Leave the shell open in case the main agent requests additional work.
