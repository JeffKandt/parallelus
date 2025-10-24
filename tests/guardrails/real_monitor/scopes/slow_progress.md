# Scenario: slow-progress

This sandbox simulates long-running work without interactive prompts.

1. Run:
   ```bash
   bash tests/guardrails/real_monitor/scripts/slow_progress.sh
   ```
2. The script logs progress approximately every 8 seconds and finishes after processing ten items. No deliverables are produced.
3. Leave the shell open in case the main agent requests additional work.
