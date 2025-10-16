# Continuous Improvement Audit Scope

## Context
- Parent branch: {{PARENT_BRANCH}}
- Latest marker: {{MARKER_PATH}}
- Goal: Produce a JSON retrospective report for the most recent turn before `make turn_end`.

## Objectives
- [ ] Analyse guardrail compliance, git status/diffs, and plan/progress updates since the marker timestamp.
- [ ] Document any issues with clear evidence, remediation, and prevention notes.
- [ ] Surface follow-up actions the main agent must carry into the branch plan.

## Acceptance Criteria
- JSON output matches the schema in `.agents/prompts/agent_roles/continuous_improvement_auditor.md`.
- Evidence references concrete commands, files, or timestamps.
- No repository state is modified.

## Notes
- Remain read-only: do not run `make bootstrap`, install dependencies, or edit files.
- Focus on the active branch `{{PARENT_BRANCH}}`; ignore unrelated historical entries.
