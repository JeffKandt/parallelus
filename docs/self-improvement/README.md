# Self-Improvement Retrospectives

This directory stores two types of artifacts:

1. **Turn markers** (`markers/<branch>.json`) created automatically by
   `.agents/bin/retro-marker` when the main agent runs `make turn_end`.
   Markers record the timestamp, plan/progress snapshot, session console offset,
   and current commit so retrospective auditors know exactly where to resume
   analysis.
2. **Retrospective reports** (`reports/<branch>--<marker-timestamp>.json`)
   written by the Retrospective Auditor subagent. Each report must follow the
  schema described in `.agents/prompts/agent_roles/continuous_improvement_auditor.md` and is
   committed by the main agent after review.

Merge guardrails require that the latest marker for a branch has a corresponding
report committed before `make merge slug=<slug>` will succeed.
