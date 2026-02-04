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
3. Add a project-owned home for Parallelus-related **instance artifacts**
   (reviews/audits/history) that must survive upgrades:
   - `docs/parallelus/…`
4. Move all other Parallelus-owned tracked process artifacts into a dedicated
   tracked namespace intended to be **replaceable on upgrade**:
   - `parallelus/…`
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
- `docs/parallelus/…` — project-owned Parallelus instance artifacts (see below).

Everything else that is Parallelus-owned moves out of `docs/` and into
`parallelus/` (tracked) or `./.parallelus/` (runtime).

### `parallelus/` (tracked, process-owned, **replaceable**)

This folder is versioned and PR-reviewed, but intended to be treated as an
upstream-owned bundle: a consuming project should be able to replace the entire
folder when upgrading Parallelus.

As a result, **do not** store project-specific, accumulating history here
(reviews, retrospective reports, markers, etc.). Those live under
`docs/parallelus/`.

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
  schema/
    ... (optional future use: machine-readable constraints / file manifests)
```

Notes:
- `parallelus/manuals/` consolidates what is currently under `docs/agents/…`.
- Any “instance history” artifacts belong under `docs/parallelus/…` so they
  survive bundle replacement.

### `docs/parallelus/` (tracked, project-owned **instance artifacts**)

This folder is tracked and PR-reviewed. It is project-owned (not replaceable)
and stores artifacts *produced by running Parallelus in this repository*.

Proposed structure:

```
docs/parallelus/
  README.md
  reviews/
    feature-<slug>-<date>.md
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
      <run-id>/
        session.jsonl
        subagent.exec_events.jsonl
```

Notes:
- This is where you put anything you *never* want to lose during an upgrade:
  senior review artifacts, retrospective evidence, and any curated run captures.
- New run captures remain runtime-only under `./.parallelus/…` unless explicitly
  promoted into `docs/parallelus/guardrails/runs-archive/` for provenance.

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

- `docs/reviews/*` → `docs/parallelus/reviews/*`
- `docs/self-improvement/*` → `docs/parallelus/self-improvement/*`

### Branch notebooks and folding

- `docs/plans/feature-<slug>.md` → `docs/branches/<slug>/PLAN.md`
- `docs/progress/feature-<slug>.md` → `docs/branches/<slug>/PROGRESS.md`
- Update fold tooling to fold from `docs/branches/<slug>/PROGRESS.md` into
  `docs/PROGRESS.md`.

### Guardrail run captures

- Existing tracked run captures:
  - `docs/guardrails/runs/**` → `docs/parallelus/guardrails/runs-archive/**`
- New run captures (runtime-only):
  - emit to `./.parallelus/guardrails/runs/**` (or `sessions/<id>/artifacts/`)

### Deployment upgrade note

- Keep `docs/deployment-upgrade-and-layout-notes.md` until this plan is fully
  implemented and validated, then delete it.

## Implementation Sequence (High Level)

1. Land this plan + open questions resolved.
2. Add `parallelus/` tracked structure and update docs references.
3. Add `docs/parallelus/` tracked structure for instance artifacts and update
   merge gates/scripts to write evidence there.
4. Migrate `docs/agents/*` into `parallelus/…` and update scripts/docs
   accordingly.
5. Migrate `docs/reviews/*` and `docs/self-improvement/*` into
   `docs/parallelus/…` and update scripts/hooks accordingly.
4. Migrate branch notebooks to `docs/branches/<slug>/…` and update fold tooling.
5. Establish guardrail run output as runtime (`./.parallelus/guardrails/runs/`)
   and archive any legacy tracked runs.
6. Validate: fresh bootstrap + CI + merge workflow + subagent workflow.
7. Delete `docs/deployment-upgrade-and-layout-notes.md` after confirming it no
   longer contains unique value.

## Open Questions

1. Should the tracked bundle namespace be `parallelus/` or `parallelus/process/`?
2. Do we want `parallelus/manuals/` vs `parallelus/docs/` naming?
3. Should `parallelus/scopes/` remain tracked, or should scopes be generated
   dynamically and treated as runtime?
4. Do we want to keep `sessions/` as-is (gitignored) or move session artifacts
   under `./.parallelus/sessions/` for tighter process ownership?
5. How should branch slugs map when the git branch is `feature/foo-bar`:
   - directory `docs/branches/foo-bar/…` (drop prefix), or
   - directory `docs/branches/feature-foo-bar/…` (keep full slugged branch name)?
