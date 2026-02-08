# Scenario: interactive-success

You are operating inside a throwaway sandbox. Before posting the readiness
message, complete the standard bootstrap sequence:

- Run `make read_bootstrap`.
- Review `AGENTS.md` and `parallelus/engine/custom/README.md` (plus any manuals they
  explicitly reference for this scope).
- Run `make bootstrap slug=real-interactive-success` so plan/progress notebooks
  exist in the sandbox.
- Record the guardrail acknowledgements and initial objectives in
  `docs/plans/feature-real-interactive-success.md` and
  `docs/progress/feature-real-interactive-success.md`.

Once those steps are finished, follow this interactive flow:

1. Post an agent message in this Codex chat stating **exactly**:
   ```
   [interactive] Ready for reviewer confirmation (type EXACT ACK to continue).
   ```
   Do not run any shell commands that simulate user input.
2. Remain idle until you see a standalone message `ACK` from the main agent. Do **not** type it yourself or automate the reply through a script.
3. After you observe the response from the main agent, run:
   ```bash
   tests/guardrails/real_monitor/scripts/interactive_success.sh
   ```
   This helper emits 60 seconds of heartbeats while waiting, creates the
   deliverable bundle, then emits another 60 seconds of heartbeats before
   signalling readiness. It writes the files to `deliverables/` on your behalf.
4. Leave the shell open so the main agent can harvest/cleanup.

Do not modify other files. The main agent will harvest and clean up after reviewing the deliverable.
