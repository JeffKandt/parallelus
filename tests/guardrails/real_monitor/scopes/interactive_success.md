# Scenario: interactive-success

You are operating inside a throwaway sandbox. Follow these steps:

1. Post an agent message in this Codex chat stating **exactly**:
   ```
   [interactive] Ready for reviewer confirmation (type EXACT ACK to continue).
   ```
   Do not run any shell commands that simulate user input.
2. Remain idle until you see a standalone message `ACK` from the main agent. Do **not** type it yourself or automate the reply through a script.
3. Once you observe the response from the main agent, produce the deliverable by running:
   ```bash
   mkdir -p deliverables
   printf 'interactive-success\n' > deliverables/result.txt
   printf '{"files":["deliverables/result.txt"]}\n' > deliverables/.manifest
   touch deliverables/.complete
   printf '[interactive] deliverable recorded at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
   ```
4. Leave the shell open so the main agent can harvest/cleanup.

Do not modify other files. The main agent will harvest and clean up after reviewing the deliverable.
