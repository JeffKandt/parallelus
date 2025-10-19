# Branch Progress — feature-fix-it-forever-guardrail

## 2025-10-19 18:40:00 UTC
**Objectives**
- Enforce fix-it-forever and subagent guardrails.

**Work Performed**
- Hardened `.agents/bin/agents-turn-end` and `.agents/bin/agents-merge`; updated AGENTS.md with manual references.
- Moved the continuous-improvement playbook into `docs/agents/manuals/` and refreshed the manuals index.
- Documented senior-review baseline separately, archived manual reviews, and removed the temporary baseline callout.
- Updated `docs/agents/project/domain.md` to highlight the playbook for downstream repos.
- Added guidance in the continuous-improvement manual to upstream generalisable fixes after capturing them downstream.
- Authored `docs/agents/manuals/git-workflow.md` to document both direct merge and PR-based integration paths, and pointed AGENTS.md at the manual.
- Added scope-validation guards in `subagent_manager.sh` (placeholders must be replaced, branch must match, objectives filled), and updated the senior architect manual to call out placeholder replacement plus `make monitor_subagents`.

**Artifacts**
- .agents/bin/subagent_manager.sh
- .agents/bin/agents-turn-end
- .agents/bin/agents-merge
- AGENTS.md
- docs/agents/manuals/continuous-improvement.md
- docs/agents/manuals/senior-architect.md
- docs/agents/manuals/git-workflow.md
- docs/agents/manuals/README.md
- docs/agents/project/domain.md
- archive/manual-reviews/

**Next Actions**
- Run subagent senior review when ready to merge into `main`.
