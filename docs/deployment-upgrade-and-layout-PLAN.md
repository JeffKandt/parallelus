# Deployment, Upgrades, and Layout — Plan

This document defines the **target layout** and **migration plan** for
segregating Parallelus process/runtime artifacts from project documentation.

It is intentionally written as a “set-in-stone” plan. The companion document
`docs/deployment-upgrade-and-layout-notes.md` remains the working draft/history
until this plan is complete and executed.

## Goals

1. Keep `docs/` primarily for **project documentation**.
2. Preserve high-visibility global artifacts in `docs/`:
   - `docs/PLAN.md`
   - `docs/PROGRESS.md`
   - per-branch notebooks (new location: `docs/branches/<slug>/…`)
3. Move all other Parallelus-owned tracked process artifacts into a dedicated
   tracked namespace: `parallelus/`.
4. Keep high-churn / machine-local runtime artifacts in `./.parallelus/`
   (gitignored).
5. Reduce PR noise and collisions when deploying Parallelus into host repos.

## Non-Goals

- Changing merge governance semantics (audits, senior review, etc.) as part of
  the reorg. The goal is *relocation and clarity*, not policy redesign.
- Mandating optional integrations (e.g., Beads) as a dependency for using
  Parallelus.

## Target Layout (Decided)

### `docs/` (project-owned, with explicit exceptions)

Keep only:
- `docs/PLAN.md` — global backlog and priorities.
- `docs/PROGRESS.md` — consolidated work log (folded from branch notebooks).
- `docs/branches/<slug>/PLAN.md` — branch plan notebook.
- `docs/branches/<slug>/PROGRESS.md` — branch progress notebook.

Everything else that is Parallelus-owned moves out of `docs/` and into
`parallelus/` (tracked) or `./.parallelus/` (runtime).

### `parallelus/` (tracked, process-owned)

This folder is versioned and PR-reviewed. It contains the process manuals,
templates, evidence, and other artifacts the workflow owns.

Proposed structure:

```
parallelus/
  README.md
  manuals/
    core.md
    git-workflow.md
    deployment.md
    runtime-matrix.md
    subagent-session-orchestration.md
    integrations/
      codex.md
      beads.md
    adapters/
      python.md
    project/
      structure.md
      continuous_improvement.md
  templates/
    ci_audit_scope.md
    subagent_scope_template.md
  scopes/
    ... (any reusable scope stubs)
  reviews/
    ... (senior architect review artifacts)
  self-improvement/
    README.md
    markers/
      *.json
    reports/
      *.json
    failures/
      *.json
  guardrails/
    runs-archive/
      ... (legacy tracked run captures that were previously committed)
```

Notes:
- `parallelus/manuals/` consolidates what is currently under `docs/agents/…`.
- `parallelus/reviews/` replaces `docs/reviews/…` for review artifacts.
- `parallelus/self-improvement/` replaces `docs/self-improvement/…` for markers,
  reports, and failures summaries.
- `parallelus/guardrails/runs-archive/` is a *tracked* home for any historically
  committed run captures that we keep for provenance, while new run captures are
  treated as runtime under `./.parallelus/…`.

### `./.parallelus/` (runtime, process-owned)

This folder is machine-local (gitignored). It contains subagent sandboxes,
worktrees, transient logs, and any other high-churn outputs.

Proposed structure:

```
.parallelus/
  README.md (optional; explains runtime-only intent)
  subagents/
    sandboxes/
      <slug>-<random>/
    worktrees/
      <slug>/
  guardrails/
    runs/
      <run-id>/
        session.jsonl
        subagent.exec_events.jsonl
      extracted/
        codex-rollout-*.{jsonl,md}
  cache/
    ... (optional future use; e.g., compiled indexes)
  tmp/
    ... (optional future use; scratch space for helpers)
```

Notes:
- Keep `sessions/` separate (it is already gitignored) and do not relocate it as
  part of this plan unless required later.
- Tools that currently emit to `docs/guardrails/runs/` should be updated to emit
  to `./.parallelus/guardrails/runs/` (or to the active `sessions/<id>/artifacts/`
  when session logging is enabled).

## Migration Mapping (No Moves Yet)

This section records the *intended* move targets so implementation work can be
planned and reviewed. It does not imply the files have already moved.

### Manuals, integrations, and templates

- `docs/agents/core.md` → `parallelus/manuals/core.md`
- `docs/agents/git-workflow.md` → `parallelus/manuals/git-workflow.md`
- `docs/agents/deployment.md` → `parallelus/manuals/deployment.md`
- `docs/agents/runtime-matrix.md` → `parallelus/manuals/runtime-matrix.md`
- `docs/agents/subagent-session-orchestration.md` → `parallelus/manuals/subagent-session-orchestration.md`
- `docs/agents/integrations/*.md` → `parallelus/manuals/integrations/*.md`
- `docs/agents/adapters/*.md` → `parallelus/manuals/adapters/*.md`
- `docs/agents/project/*.md` → `parallelus/manuals/project/*.md`
- `docs/agents/templates/*.md` → `parallelus/templates/*.md`
- `docs/agents/scopes/*` → `parallelus/scopes/*` (if we still want tracked scopes)

### Reviews and retrospective artifacts

- `docs/reviews/*` → `parallelus/reviews/*`
- `docs/self-improvement/*` → `parallelus/self-improvement/*`

### Branch notebooks and folding

- `docs/plans/feature-<slug>.md` → `docs/branches/<slug>/PLAN.md`
- `docs/progress/feature-<slug>.md` → `docs/branches/<slug>/PROGRESS.md`
- Update fold tooling to fold from `docs/branches/<slug>/PROGRESS.md` into
  `docs/PROGRESS.md`.

### Guardrail run captures

- Existing tracked run captures:
  - `docs/guardrails/runs/**` → `parallelus/guardrails/runs-archive/**`
- New run captures (runtime-only):
  - emit to `./.parallelus/guardrails/runs/**` (or `sessions/<id>/artifacts/`)

### Deployment upgrade note

- Keep `docs/deployment-upgrade-and-layout-notes.md` until this plan is fully
  implemented and validated, then delete it.

## Implementation Sequence (High Level)

1. Land this plan + open questions resolved.
2. Add `parallelus/` tracked structure and update docs references.
3. Migrate `docs/agents/*`, `docs/reviews/*`, `docs/self-improvement/*` into
   `parallelus/…` and update scripts/hooks accordingly.
4. Migrate branch notebooks to `docs/branches/<slug>/…` and update fold tooling.
5. Establish guardrail run output as runtime (`./.parallelus/guardrails/runs/`)
   and archive any legacy tracked runs.
6. Validate: fresh bootstrap + CI + merge workflow + subagent workflow.
7. Delete `docs/deployment-upgrade-and-layout-notes.md` after confirming it no
   longer contains unique value.

## Open Questions

1. Should the tracked namespace be `parallelus/` or `parallelus/process/`?
2. Do we want `parallelus/manuals/` vs `parallelus/docs/` naming?
3. Should `parallelus/scopes/` remain tracked, or should scopes be generated
   dynamically and treated as runtime?
4. Should any subset of review artifacts remain in `docs/` for discoverability,
   or is `parallelus/reviews/` sufficient?
5. Do we want to keep `sessions/` as-is (gitignored) or move session artifacts
   under `./.parallelus/sessions/` for tighter process ownership?
6. How should branch slugs map when the git branch is `feature/foo-bar`:
   - directory `docs/branches/foo-bar/…` (drop prefix), or
   - directory `docs/branches/feature-foo-bar/…` (keep full slugged branch name)?

