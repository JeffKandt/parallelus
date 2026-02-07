# Parallelus Repository Structure

## Core Directories
- `parallelus/engine/bin/` -- Guardrail-enforcing helpers (branch management, retrospectives, subagent launch, monitoring).
- `parallelus/engine/hooks/` -- Managed Git hooks installed during bootstrap/merge.
- `parallelus/engine/prompts/` -- Role prompts with YAML front matter for subagents.
- `parallelus/engine/custom/` -- Optional host-project extensions; keep Parallelus core files pristine and stage overrides here.
- `parallelus/manuals/` -- Manuals read when gates trigger (git workflow, subagents, adapters, integrations).
- `docs/branches/<slug>/{PLAN,PROGRESS}.md` -- Branch notebooks generated during bootstrap.
- `docs/PLAN.md` & `docs/PROGRESS.md` -- Canonical backlog and cross-branch progress log.
- `docs/parallelus/self-improvement/` -- Retrospective markers, failures summaries, and audit reports.
- `docs/parallelus/custom/` -- Project-owned hook configuration (`config.yaml`) and lifecycle hook scripts.
- `.parallelus/` -- Runtime-only artifacts (subagent sandboxes/worktrees, transient logs); gitignored by default.
- `.parallelus/sessions/` -- Session logs (`console.log`, `summary.md`, `meta.json`) captured per turn.
- `parallelus/manuals/project/` -- These maintainer-focused notes (domain, structure, continuous improvement).

## Development Flow
1. Work from feature branches only; bootstrap ensures notebooks/hooks sync.
2. Keep notebooks aligned with the work—every code change should reflect in plan/progress entries.
3. Use the guardrail manuals (`parallelus/manuals/*.md`) when performing merges, archive operations, diagnostics, or subagent orchestration.
4. After significant enhancements, update this directory with the rationale and any migration notes so downstream adopters understand what changed.

## Release & Sync Guidance
- Tag the main branch (`template-vX.Y`) whenever Parallelus ships a stable update that downstream projects should consume.
- Provide migration notes under `parallelus/manuals/project/` describing new guardrails, breaking changes, or required manual actions.
- Downstream repositories should copy `parallelus/engine/` and `parallelus/manuals/` verbatim, then replace `parallelus/manuals/project/` with their product-specific notes (see `README.md` for instructions).
