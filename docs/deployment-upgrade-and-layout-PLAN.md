# Deployment, Upgrades, and Layout — Plan

This document defines the **target layout** and **migration plan** for
segregating Parallelus process/runtime artifacts from project documentation.

It is intentionally written as a “set-in-stone” plan. The companion document
`docs/deployment-upgrade-and-layout-notes.md` remains the working draft/history
until this plan is complete and executed.

## Terminology (Source Repo vs Bundle vs Host Repo)

Parallelus-related discussions in this repository can get “meta” because this
repo is both:
(1) a *host repo* where Parallelus is executed day-to-day, and
(2) the *source repo* where Parallelus itself is developed.

This plan uses the following terms to keep those roles distinct:

- **Parallelus source repo**: this repository (`/Users/jeff/Code/parallelus`).
  It contains the upstream process bundle *and* project-owned artifacts produced
  by running Parallelus while developing Parallelus.
- **Parallelus bundle** (or **bundle**): the tracked, replaceable folder
  `parallelus/…` which is intended to be copied into other repositories during
  deployment/upgrade.
- **Host repo** (or **target project**): any repository into which the bundle is
  deployed (including the source repo when used as its own host).
- **Instance artifacts**: tracked artifacts produced by running Parallelus in a
  specific host repo (reviews, self-improvement reports, curated run archives).
  These are *project-owned* and must survive bundle upgrades.
- **Runtime artifacts**: machine-local/high-churn outputs (logs, sandboxes,
  worktrees). These are process-owned and gitignored.

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
5. Keep high-churn / machine-local runtime artifacts in `./.parallelus/`
   (gitignored).
6. Reduce PR noise and collisions when deploying Parallelus into host repos.

## Non-Goals

- Changing merge governance semantics (audits, senior review, etc.) as part of
  the reorg. The goal is *relocation and clarity*, not policy redesign.
- Mandating optional integrations (e.g., Beads) as a dependency for using
  Parallelus.

## Target Layout (Decided)

### `docs/` (project-owned; Parallelus expects specific files)

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
  engine/
    README.md
    bin/
      ...
    hooks/
      ...
    make/
      ...
    prompts/
      ...
    tests/
      ...
    tmux/
      ...
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
- `parallelus/engine/` replaces today’s top-level `.agents/` directory.
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

## Background: Name / Namespace Collision Notes (Parallelus)

This plan assumes `parallelus/` is a reasonable, low-collision tracked namespace
to introduce into host repos. Quick checks indicate “parallelus” is uncommon in
software contexts:

- General web results skew toward dictionary/Latin usage (“parallel”) and
  scientific species names (e.g. `Pseudochorthippus parallelus`).
- GitHub repository-name search returns a small number of results for
  `parallelus` (e.g., `gh search repos parallelus` returned 16 results at the
  time this plan was updated, including this repo).
- GitHub code search cannot reliably answer “top-level directory named X across
  GitHub”; we approximated it by searching for `parallelus/` in file paths,
  then filtering for paths that *start with* `parallelus/`. That yielded zero
  results in the first 200 matches, which suggests there is no strong existing
  convention, but it is **not** a comprehensive dataset.

This is “good enough” to proceed with `parallelus/` as the default, but the plan
retains an open question about using a more vendor-like namespace
(e.g. `vendor/parallelus/`) for extremely collision-sensitive repos.

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
- `docs/agents/scopes/*` → `parallelus/scopes/*` (see “Scopes” in Open Questions)

### Engine (`.agents/`) relocation

- `.agents/**` → `parallelus/engine/**`

Follow-up (implementation-time): update any hard-coded `.agents/...` path usage
to reference `parallelus/engine/...`, including:
- Makefile include(s)
- hook install paths
- any docs that reference `.agents/`

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

## Implementation Work Items (Resulting Tasks)

These are not “open questions”; they are expected work implied by the decided
layout.

- **Path refactors:** update all references to `.agents/…` → `parallelus/engine/…`
  and `docs/agents/…` → `parallelus/manuals/…` once the moves happen.
- **Entry points:** define and document stable script entrypoints under
  `parallelus/engine/bin/…` that do not depend on Make.
- **Make adapter (if kept):** implement `parallelus/engine/make/parallelus.mk`
  with namespaced targets to avoid collisions in host repos.
- **Session/runtime outputs:** ensure new guardrail run captures and extracted
  artifacts default to `./.parallelus/guardrails/runs/…` (or to active session
  artifacts when session logging is enabled).
- **Promotion workflow:** define how/when runtime artifacts become tracked
  `docs/parallelus/…` archives (manual promotion step, or an explicit helper).
- **Branch notebooks:** implement the new directory layout
  `docs/branches/<slug>/{PLAN,PROGRESS}.md` and update any tooling/hook messages
  that assumes `docs/plans/*.md` and `docs/progress/*.md`.
- **Folding tooling:** update fold tooling to fold from
  `docs/branches/<slug>/PROGRESS.md` into `docs/PROGRESS.md`.
- **Self-improvement evidence:** update any scripts that read/write markers and
  reports so they target `docs/parallelus/self-improvement/…` (tracked) vs
  `./.parallelus/…` (runtime), per the decided split.
- **Customizations:** design a stable lookup mechanism for project-owned
  customizations under `docs/parallelus/custom/…` (Open Question 9).
- **Deploy/upgrade tooling:** update deployment helpers to treat `parallelus/…`
  as the replaceable bundle and `docs/parallelus/…` as preserved state.
- **Validation checklist:** add a “clean-room” validation procedure (fresh clone
  or clean worktree) that verifies bootstrap, CI, subagents, folding, and merge
  gates against the new layout.

## Implementation Sequence (High Level)

1. Land this plan + open questions resolved.
2. Add `parallelus/` tracked structure and update docs references.
3. Add `docs/parallelus/` tracked structure for instance artifacts and update
   merge gates/scripts to write evidence there.
4. Migrate `.agents/**` into `parallelus/engine/**` and update scripts/docs
   accordingly (no compatibility shims planned).
5. Migrate `docs/agents/*` into `parallelus/manuals/**` and update scripts/docs
   accordingly.
6. Migrate `docs/reviews/*` and `docs/self-improvement/*` into
   `docs/parallelus/…` and update scripts/hooks accordingly.
7. Migrate branch notebooks to `docs/branches/<slug>/…` and update fold tooling.
8. Establish guardrail run output as runtime (`./.parallelus/guardrails/runs/`)
   and archive any legacy tracked runs.
9. Validate: fresh bootstrap + CI + merge workflow + subagent workflow.
10. Delete `docs/deployment-upgrade-and-layout-notes.md` after confirming it no
   longer contains unique value.

## Open Questions

This section intentionally mixes **true decisions** (naming/placement choices)
with **design questions** that affect how we deploy into host repos. Each item
includes pros/cons and a recommendation so we can converge quickly.

### 1) Bundle namespace: `parallelus/` vs `vendor/parallelus/`

Pros (`parallelus/`):
- Short, readable, memorable.
- Matches the “replaceable bundle” mental model.

Cons (`parallelus/`):
- Potential (but likely low) collision with a host repo’s existing top-level
  folder naming conventions.

Pros (`vendor/parallelus/`):
- Clear “third-party bundle” signal.
- Reduces perceived ownership ambiguity in host repos.

Cons (`vendor/parallelus/`):
- More nesting; more path churn in scripts/docs.
- Some repos already reserve `vendor/` for language deps (Go/PHP).

Recommendation:
- Default to `parallelus/` in this plan.
- If a host repo already has a conflicting `parallelus/`, prefer
  `vendor/parallelus/` as an escape hatch (deployment-time choice).

### 2) Manuals namespace: `parallelus/manuals/` vs `parallelus/docs/`

Pros (`manuals/`):
- Clarifies intent: these are process manuals, not project docs.
- Keeps host repo `docs/` clean.

Cons (`manuals/`):
- Slightly unusual; some teams expect everything “doc-like” under `docs/`.

Pros (`docs/` under `parallelus/`):
- Familiar; fewer naming surprises.

Cons (`docs/` under `parallelus/`):
- Confusing alongside the host repo’s `docs/`.

Recommendation:
- Keep `parallelus/manuals/` as the bundle home for process documentation.

### 3) Engine namespace: `parallelus/engine/` vs `parallelus/tooling/`

Pros (`engine/`):
- Conveys “core system that runs the process”.
- Leaves room for `parallelus/integrations/` or `parallelus/adapters/` later.

Cons (`engine/`):
- A bit metaphorical; some contributors may interpret “engine” as runtime-only.

Pros (`tooling/`):
- More literal: scripts, hooks, helpers.

Cons (`tooling/`):
- Can be misread as “optional utilities” rather than required core.

Recommendation:
- Use `parallelus/engine/` (as already reflected in this plan).

### 4) Scopes: keep tracked (`parallelus/scopes/`) or make runtime-generated?

Reminder: **Scopes** are reusable, versioned context stubs used to scope
subagents/reviews/audits (e.g., “review these directories with these
constraints”). They act as “prompt fragments” / “work order templates”.

Pros (tracked scopes):
- Reviewable, consistent, and can evolve with the process bundle.
- Reusable across host repos (a key “bundle” advantage).

Cons (tracked scopes):
- Adds another “content” surface area in the bundle to maintain.
- Host repos may want custom scopes that should not be overwritten on upgrade.

Pros (runtime-generated scopes):
- Can be generated from live repo state (e.g., changed files).
- Reduces tracked content surface area.

Cons (runtime-generated scopes):
- Less reviewable/auditable; drift risk.
- Harder to share “canonical” scopes across hosts.

Recommendation:
- Keep **core** scopes tracked as part of the replaceable bundle:
  `parallelus/scopes/`.
- Add a project-owned override location for custom scopes:
  `docs/parallelus/scopes/` (load-order: project scopes first, then bundle).
- If we later add generated scopes, generate them into
  `./.parallelus/scopes/` (runtime-only).

### 5) `sessions/` placement: keep root `sessions/` or move into `./.parallelus/`?

Pros (keep root `sessions/`):
- Minimal churn: existing tooling already expects it.
- Visible and easy to inspect during debugging.
- Avoids conflating “session logs” with other `.parallelus` runtime artifacts
  until we’re sure the new layout is stable.

Cons (keep root `sessions/`):
- Less consistent: `.parallelus/` is otherwise the runtime namespace.
- Leaves a generic folder name in the repo root (even if gitignored).

Pros (move under `./.parallelus/sessions/`):
- Consistent: *all* runtime artifacts live under one namespace.
- Better “process-owned” encapsulation.

Cons (move under `./.parallelus/sessions/`):
- Requires careful updates to logging helpers and any consumer scripts.
- Risk of breaking session capture expectations during the reorg.

Recommendation:
- Keep root `sessions/` for this reorg (explicitly out-of-scope to move).
- Revisit after the rest of the reorg lands and we can do a focused migration.

### 6) Branch slug → directory naming (Decided)

Decision:
- `docs/branches/<slug>/…` uses the **full branch name** with `/` replaced by
  `-`.
- Examples:
  - git branch `feature/foo` → `docs/branches/feature-foo/PLAN.md`
  - git branch `feature/foo-bar` → `docs/branches/feature-foo-bar/PROGRESS.md`

Pros:
- 1:1 mapping with `git branch --show-current`; easy to find.
- Avoids collisions between branches that only differ by prefix.

Cons:
- Slightly longer path names.

Recommendation:
- Keep as decided above.

### 7) Folding + archiving branch notebooks (policy + mechanics)

Pros (always fold branch progress into `docs/PROGRESS.md`):
- A single high-signal canonical log.
- Branch notebooks can stay focused on WIP.

Cons:
- Folding can be opinionated (ordering, dedupe, “what counts”).

Pros (archive branch notebooks as an audit trail):
- Keeps provenance for review/audit context.

Cons:
- Can accumulate noise if not curated.

Recommendation:
- Keep `docs/PROGRESS.md` as the canonical folded log.
- Add an explicit “archive” workflow:
  - `docs/parallelus/branches-archive/<slug>/…` for closed branches, or
  - keep notebooks in-place and mark them closed with a final marker.
  (Decision pending; implement after we pick one.)

### 8) Bundle entrypoints vs host integration (Makefile vs direct scripts)

Question:
- In host repos, should Parallelus functionality be consumed primarily via
  `make …` targets, or by calling scripts directly?

Pros (Makefile-based entrypoints):
- Friendly “task discovery” via `make help`.
- Supports dependency ordering and standard target naming (`ci`, `bootstrap`).
- Keeps commands short and consistent across hosts.

Cons (Makefile-based entrypoints):
- Host repos may already have a Makefile with conflicting target names.
- Requires contributors to use/understand Make, which some teams avoid.

Pros (direct script entrypoints):
- Easier to integrate into repos that already have their own build system.
- Scripts can be invoked from any task runner (just, npm, bazel, CI).

Cons (direct script entrypoints):
- Harder to keep a stable UX without a “command surface” contract.
- Harder to provide a single discoverable task index.

Recommendation:
- Keep Makefile entrypoints for the **source repo** (developer ergonomics).
- For host repos, make **direct script entrypoints** the “lowest common
  denominator” contract (e.g. `parallelus/engine/bin/…`), and treat Makefile
  integration as an optional adapter (namespaced include like
  `parallelus/engine/make/parallelus.mk` rather than requiring target repos to
  merge Makefiles).

### 9) Project-owned customizations currently under `.agents/custom/`

Problem:
- `.agents/custom/README.md` describes host-project customizations, but
  `.agents/**` is moving into the **replaceable** `parallelus/engine/**`.

Pros (keep customizations inside the bundle):
- Simple to locate.

Cons:
- Bundle upgrades would overwrite host-specific customizations.

Recommendation:
- Move “customizations” to a project-owned namespace:
  - `docs/parallelus/custom/…` (tracked, preserved), and
  - define a stable lookup path for the engine to source/execute optional
    custom hooks from there.
  (Implementation detail to be designed; decision needed before moves.)

### 10) Root-level integration surface (AGENTS/Makefile/.gitignore)

Problem:
- The bundle is intended to be replaceable (`parallelus/…`), but some important
  integration points are (today) root-level: `AGENTS.md`, `PROJECT_AGENTS.md`,
  `Makefile`, `.gitignore`, and potentially CI configs.

Pros (keep root-level integration files as “deployed shims”):
- Clear for contributors: guardrails + entrypoints are at repo root.
- Matches current Parallelus expectations (and human habits).

Cons:
- Harder to upgrade cleanly if the host repo already has its own Makefile or
  root conventions.
- Increases the “blast radius” of deployment beyond a single replaceable folder.

Pros (move more entrypoints under the bundle and minimize root shims):
- Lower collision risk in host repos.
- Keeps the “replaceable bundle” promise stronger.

Cons:
- Requires training contributors to look under `parallelus/…` for core tasks.
- Some tools/people expect `AGENTS.md` at repo root.

Recommendation:
- Treat **root-level** `AGENTS.md` / `PROJECT_AGENTS.md` as non-negotiable
  guardrail surfaces for now.
- Reduce root-level collision risk by keeping Makefile integration optional and
  namespaced (see Open Question 8).
