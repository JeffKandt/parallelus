# Scenario: hung-failure

This sandbox emulates a task that stalls indefinitely.

1. Run:
   ```bash
   bash tests/guardrails/real_monitor/scripts/hung_failure.sh
   ```
2. The script logs a blocking message and then sleeps until cancelled. Wait for the main agent to decide whether to nudge, terminate, or retry; do not exit the shell on your own.
