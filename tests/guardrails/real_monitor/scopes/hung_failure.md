# Scenario: hung-failure

This sandbox emulates a task that stalls indefinitely.

1. Run:
   ```bash
   bash tests/guardrails/real_monitor/scripts/hung_failure.sh
   ```
2. The script logs a blocking message and then sleeps until cancelled. Wait for the main agent’s instructions—respond to nudges if prompted, otherwise remain idle and keep the session open.
