# Branch Plan — feature/process-review-gate

## Objectives
- Enforce senior architect review workflow including synchronous subagent usage and configurable prompt metadata.
- Improve merge guardrails: surface non-blocking review findings pre-merge and document override behavior.
- Harden deployment to preserve existing instructions and warn when overwriting files.

## Checklist
- [x] Persist senior architect defaults in repo config and reference them from the prompt header.
- [x] Replace automated self-retrospective with synchronous marker/auditor workflow.
- [x] Create a read-only agent_auditor prompt to collect and analyse turn evidence.
- [x] Gate merge on retrospective reports corresponding to the latest marker.
- [x] Strengthen deploy safety for hooks and identical overlays.
- [ ] Validate updated hooks and deployment flow (lint/tests as needed).

## Next Actions
- Run `make ci` after reformatting any files flagged by black.
- Capture a sample retrospective report using the new workflow to demonstrate end-to-end usage.
