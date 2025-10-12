# Branch Plan — feature/process-review-gate

## Objectives
- Enforce senior architect review workflow including synchronous subagent usage and configurable prompt metadata.
- Improve merge guardrails: surface non-blocking review findings pre-merge and document override behavior.
- Harden deployment to preserve existing instructions and warn when overwriting files.

## Checklist
- [x] Update senior architect role prompt with configuration header (model, sandbox, approval) and note synchronous subagent execution.
- [x] Extend merge helper to require acknowledgement of lower-severity findings prior to merge.
- [x] Enhance docs/reviews guidance to support unique filenames (branch + date) and address branch slug reuse.
- [x] Modify agent deployment script to warn about overwrites, create .bak backups, and insert merge instructions into AGENTS.md upon overlay.
- [x] Document new processes in AGENTS.md, git workflow manual, and relevant manuals.
- [ ] Validate updated hooks and deployment flow (lint/tests as needed).

## Next Actions
- Draft changes to senior architect prompt and update documentation about synchronous review expectations.
- Amend merge helper/hook logic to capture review findings acknowledgement.
- Prototype overlay warning/AGENTS.md banner in deploy script, then refresh docs.

- [ ] Prevention (Self-Improvement): Add an environment validation step that checks for ruff before invoking lint
