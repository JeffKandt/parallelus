# Parallelus Domain Notes

Parallelus exists to give human operators confidence that an AI agent can work inside their repositories without compromising quality, auditability, or pace. When we improve Parallelus itself, keep these pillars front of mind:

- **Guardrails before cleverness.** Every new capability must respect the core cadence (Recon, Planning, Execution, Wrap-up) and protect the invariants codified in `AGENTS.md`.
- **Automation plus narrative.** The system automates notebooks, retrospectives, and reviews so humans stay informed even if they never touch the shell.
- **Continuous improvement as a discipline.** Every failure mode becomes a root-cause investigation, with mitigations captured as durable artifacts (scripts, manuals, prompts). The goal is that each class of error is addressed once—permanently. See `parallelus/manuals/project/continuous_improvement.md` for the playbook and remember: fix it once, fix it forever.

### Current Focus Areas
- Expand adapter coverage beyond Python/Swift while keeping guardrail parity.
- Reduce friction in multi-subagent workflows (launch ergonomics, monitor feedback, deliverable harvesting).
- Improve retrospective insights (better heuristics, richer metrics, automation for carrying actions into the backlog).
- Simplify adoption in downstream projects by offering templated onboarding conversations and generated branch plans.

Document process experiments, lessons learned, and approved patterns here so future contributors understand the rationale behind each guardrail.
