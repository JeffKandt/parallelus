# Scenario: interactive-success

You are operating inside a throwaway sandbox. Follow these steps:

1. Run the job:
   ```bash
   bash tests/guardrails/real_monitor/scripts/interactive_success.sh
   ```
2. Watch the output. After several heartbeat lines, the script will print:
   `Ready for reviewer confirmation (type EXACT ACK to continue)`
3. Reply with `ACK` (uppercase) and press Enter when the main agent instructs you to proceed.
4. Once the script acknowledges the response and reports that the deliverable was recorded, leave the shell open for further instructions.

Do not modify other files. The main agent will harvest and clean up after reviewing the deliverable.
