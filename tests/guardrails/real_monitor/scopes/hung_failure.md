# Scenario: hung-failure

This sandbox emulates a task that stalls indefinitely. Before running it,
complete the usual bootstrap tasks:

- Run `make read_bootstrap`.
- Review `AGENTS.md` and `parallelus/engine/custom/README.md` (plus any manuals they
  explicitly reference for this scope).
- Run `make bootstrap slug=real-hung-failure` so plan/progress notebooks exist.
- Record guardrail acknowledgements and objectives in
  `docs/plans/feature-real-hung-failure.md` and
  `docs/progress/feature-real-hung-failure.md`.

1. Run:
   ```bash
   bash tests/guardrails/real_monitor/scripts/hung_failure.sh
   ```
2. The script logs a blocking message and then sleeps until cancelled. Wait for the main agent’s instructions—respond to nudges if prompted, otherwise remain idle and keep the session open.
