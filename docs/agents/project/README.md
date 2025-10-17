# Customising Parallelus for a Host Project

When installing Parallelus inside another repository:

1. Copy the `.agents/` directory and `docs/agents/` manuals.
2. Immediately replace this `project/` folder with notes that describe the host product's domain, structure, and continuous-improvement norms.
3. Preserve the core guardrails; if you need project-specific behaviour, add sidecar scripts/manuals under `.agents/custom/` or `docs/agents/manuals/` rather than editing Parallelus core files.
4. Document any overrides (e.g., allowed write paths, adapter tweaks) so future updates from Parallelus can be merged cleanly while keeping your custom behaviour intact.

In the Parallelus repository itself, these files describe how we build and evolve the process toolkit. Downstream teams should treat them as placeholders and substitute their own guidance. 