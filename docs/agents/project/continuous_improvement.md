# Continuous Improvement Playbook

Continuous improvement is the heartbeat of Parallelus. When the agent falls short, pause immediately, capture what happened, and drive a fix that ensures the issue never recurs.

## Investigation Discipline
- **Stop the line.** When behaviour diverges from expectations (missed guardrail, incorrect output, user confusion), halt new work and investigate.
- **Document evidence.** Save logs, notebook entries, and transcripts in the branch progress file so the context is preserved.
- **Capture failures.** Before merging, run `make collect_failures` so failed tool calls are summarized and can be audited for mitigation guidance.
- **Root cause over symptoms.** Ask "why" repeatedly until you understand the systemic gap (missing check, unclear instruction, tool limitation, human-agent misunderstanding).

## Durable Mitigations
- Add or update automated guardrails (scripts, hooks, prompts) rather than relying on memory or progress-log notes.
- If the fix is specific to a downstream project, capture it in that project's sidecar config (e.g., `.agents/custom/`, project-specific manuals) so Parallelus updates can be applied without merge conflicts.
- When introducing configuration knobs or optional behaviour, keep defaults aligned with Parallelus best practices and document how operators can opt in/out safely.

## Feedback Loop
1. Log the incident in the progress notebook with a `➜ checkpoint` marker.
2. Implement the mitigation (code, doc, test) on the feature branch.
3. Update this playbook if the incident reveals a new class of risk or mitigation pattern.
4. Surface learnings in `docs/PLAN.md` so future work prioritises system-level resilience.

## Metrics to Watch
- Frequency and severity of retrospective findings that repeat past issues.
- Time from issue detection to permanent mitigation.
- Adoption rate of new guardrails across downstream projects.

Treat every unexpected behaviour as an opportunity to harden the system. The bar is "fix it once, fix it forever."
