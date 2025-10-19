Reviewed-Branch: feature/fix-it-forever-guardrail
Reviewed-Commit: 7cd40ad4a1e944d7d4a245b8ae347bd383f2163d
Reviewed-On: 2025-10-19
Decision: approved
Reviewer: codex-agent

## Findings
- Severity: Info – Verified AGENTS.md and continuous improvement manual now explicitly require permanent fixes.
- Severity: Info – Confirmed `.agents/bin/agents-turn-end` enforces durable artifacts, with override only via `AGENTS_ALLOW_NOTE_ONLY`.
- Severity: Info – Checked `.agents/bin/agents-merge` diff to ensure doc-only post-review commits are accepted while code changes still require a fresh review.

## Tests & Evidence Reviewed
- Manual inspection of AGENTS.md, continuous_improvement.md, agents-turn-end, and agents-merge diffs.

## Follow-Ups / Tickets
- [ ] None.

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: enabled (danger-full-access)
- Approval Policy: never
- Session Mode: synchronous primary agent
