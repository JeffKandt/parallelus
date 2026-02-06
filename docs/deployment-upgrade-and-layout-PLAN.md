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
      ... (optional compatibility shim; primary interface is `engine/bin/*`)
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
  sessions/
    <id>/
      console.log
      summary.md
      meta.json
      artifacts/
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
- This plan moves repo-level `sessions/` into `./.parallelus/sessions/` to avoid
  root-level name conflicts in host repos.
- Tools that currently emit to `docs/guardrails/runs/` should be updated to emit
  to `./.parallelus/guardrails/runs/` (or to the active
  `./.parallelus/sessions/<id>/artifacts/`
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
  - emit to `./.parallelus/guardrails/runs/**` (or `./.parallelus/sessions/<id>/artifacts/`)

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
- **Make adapter (optional):** if we keep a Makefile surface for convenience,
  implement it as a thin shim that delegates to `parallelus/engine/bin/…` rather
  than being the primary contract.
- **Session/runtime outputs:** ensure new guardrail run captures and extracted
  artifacts default to `./.parallelus/guardrails/runs/…` (or to active session
  artifacts when session logging is enabled).
- **Session directory migration:** relocate `sessions/` → `./.parallelus/sessions/`
  and update all helpers/docs accordingly, with a compatibility plan (see below).
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

### Session migration mitigations (`sessions/` → `./.parallelus/sessions/`)

This migration touches core workflow helpers (`make start_session`, `make turn_end`,
folding checks, failure collection) and is therefore a higher-risk part of the
reorg. Mitigations to reduce breakage:

1. **Dual-read, single-write (transition window):**
   - Writers create new sessions under `./.parallelus/sessions/<id>/…`.
   - Readers (folding, failure collection, tooling) search both:
     `./.parallelus/sessions/…` then legacy `sessions/…`.
2. **Explicit config + auto-detection:**
   - Introduce a single “sessions root” setting (env var or config file) that
     defaults to `./.parallelus/sessions/` when present, else falls back to
     `sessions/`.
3. **One-time migration helper:**
   - Provide a script that moves existing `sessions/<id>/…` directories into
     `./.parallelus/sessions/<id>/…` and validates that log references remain
     resolvable.
4. **No symlinks required (but allowed as an emergency shim):**
   - Avoid relying on `sessions -> .parallelus/sessions` symlinks because some
     environments dislike symlinks and they still occupy a root-level name.
   - If a host repo needs short-term compatibility, a symlink can be created,
     but it should not be the steady-state requirement.

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

## Decisions (Resolved)

The recommendations below are accepted (as of this plan revision), and are no
longer treated as open questions:

- Bundle namespace default: `parallelus/` (escape hatch: `vendor/parallelus/`).
- Manuals namespace: `parallelus/manuals/`.
- Engine namespace: `parallelus/engine/`.
- Scopes: keep core scopes tracked under `parallelus/scopes/`, allow project
  overrides under `docs/parallelus/scopes/`, and treat generated scopes as
  runtime-only if introduced later.
- Branch slug → directory mapping: full branch name with `/` replaced by `-`.
- Branch notebook policy: follow the current process (fold into canonical docs
  before merge; remove branch notebooks after folding) — this reorg is only
  changing paths, not governance.
- Entrypoints: switch to **direct script entrypoints** as the primary interface
  (including in this repo), and treat Makefile integration as an optional shim
  rather than the core contract.

## Open Questions (Remaining)

Only the items below still require a decision.

### 1) Detecting “our” `parallelus/` vs a host repo’s unrelated `parallelus/`

Requirement:
- If `parallelus/` already exists in a host repo, deployment/upgrade must decide
  whether it is an existing Parallelus bundle that should be upgraded *in place*
  or an unrelated folder that should be left untouched (triggering
  `vendor/parallelus/` deployment instead).

Recommendation:
- Make the bundle self-identifying via a **sentinel manifest** that is extremely
  unlikely to exist accidentally:
  - `parallelus/.parallelus-bundle.json` (or `.toml`) containing:
    - `bundle_id` (fixed string, e.g. `"parallelus.bundle.v1"`)
    - `layout_version` (monotonic int)
    - `upstream_repo` (URL)
    - `bundle_version` (git sha or semver)
    - `installed_on` (timestamp, optional)
- Deployment logic:
  - If `parallelus/` exists **and** sentinel manifest is present + valid:
    upgrade in place.
  - If `parallelus/` exists **without** a valid sentinel: do not touch it;
    deploy to `vendor/parallelus/`.
  - Provide an explicit override flag for rare edge cases.

### 2) Customizations lookup contract (project-owned hooks/config)

We are moving `.agents/**` into the replaceable bundle (`parallelus/engine/**`),
so project-specific customizations cannot live under the bundle long-term.

Open design question:
- What is the minimal, stable “customization interface” the engine should
  support (config file path, hook scripts, optional manuals), and how should it
  be discovered?

Current recommendation (accepted direction, but contract details TBD):
- Keep project-owned customizations under `docs/parallelus/custom/…` and define a
  stable lookup mechanism for the engine to load them when present.
