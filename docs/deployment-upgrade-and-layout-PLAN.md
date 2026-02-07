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

This is “good enough” to proceed with `parallelus/` as the default, with a
resolved escape hatch to `vendor/parallelus/` for collision-sensitive repos.

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
- `docs/agents/scopes/*` → `parallelus/scopes/*` (see resolved scopes decision)

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
- **Customizations:** implement the resolved customization contract under
  `docs/parallelus/custom/…` (config + hooks).
- **Deploy/upgrade tooling:** update deployment helpers to treat `parallelus/…`
  as the replaceable bundle and `docs/parallelus/…` as preserved state.
- **Validation checklist:** add a “clean-room” validation procedure (fresh clone
  or clean worktree) that verifies bootstrap, CI, subagents, folding, and merge
  gates against the new layout.

## Pre-Reorg Host Repo Upgrade Path

This section defines how to upgrade host repos that were deployed before the
reorg (legacy `.agents/`, `docs/agents/`, `docs/plans|progress`, root
`sessions/`, and no bundle sentinel).

### Host state detection

Before making changes, classify the host repo:

1. **Legacy deployment (pre-reorg):**
   - `.agents/` exists, `parallelus/.parallelus-bundle.*` missing.
2. **Reorg deployment (current):**
   - `parallelus/` exists with valid sentinel manifest.
3. **Conflict namespace:**
   - `parallelus/` exists without valid sentinel (assume unrelated).
4. **Mixed / interrupted migration:**
   - partial move detected (for example both `.agents/` and `parallelus/engine/`).

### Bundle ownership detection policy (resolved)

Use a sentinel manifest to determine whether a namespace is Parallelus-managed.

**Sentinel path:**
- `<bundle-root>/.parallelus-bundle.json` where `<bundle-root>` is either
  `parallelus/` or `vendor/parallelus/`.

**Required sentinel fields:**
- `bundle_id` (must equal `parallelus.bundle.v1`)
- `layout_version` (integer)
- `upstream_repo` (string URL)
- `bundle_version` (git sha or semver string)
- `installed_on` (timestamp string)
- `managed_paths` (array; must include at least `engine` and `manuals`)

**Detection precedence:**
1. If `parallelus/.parallelus-bundle.json` is valid, treat `parallelus/` as
   managed and upgrade in place.
2. Else if `vendor/parallelus/.parallelus-bundle.json` is valid, treat
   `vendor/parallelus/` as managed and upgrade in place there.
3. Else fall back to the resolved legacy heuristic below.
4. If legacy heuristic is ambiguous, deploy into `vendor/parallelus/` and do
   not mutate existing `parallelus/`.

**Conflict handling:**
- If both `parallelus/` and `vendor/parallelus/` have valid sentinels, prefer
  `parallelus/` and warn that dual-managed namespaces were found.
- If sentinel exists but is malformed/invalid, treat that namespace as
  unmanaged and continue detection; do not overwrite it without explicit force.

### Legacy detection heuristic (resolved; first upgrade without sentinel)

When no valid bundle sentinel exists yet, use this deterministic rule set to
decide whether `.agents/` is a legacy Parallelus install.

**Strong fingerprints (file must exist):**
- `.agents/bin/agents-session-start`
- `.agents/bin/agents-ensure-feature`
- `.agents/hooks/pre-commit`
- `.agents/prompts/agent_roles/senior_architect.md`

**Context markers (content match):**
- `AGENTS.md` contains `Parallelus Agent Core Guardrails`
- `Makefile` references `make start_session` and/or `.agents/bin/`

**Classification rule:**
- If `strong_count >= 2` and `context_count >= 1`: classify as
  `legacy_parallelus` and migrate in place.
- Otherwise: classify as `ambiguous_or_unrelated`; do not mutate existing
  `parallelus/`, deploy to `vendor/parallelus/`, and emit a warning.

**Explicit overrides (for operators):**
- `PARALLELUS_UPGRADE_FORCE_IN_PLACE=1`: force in-place migration.
- `PARALLELUS_UPGRADE_FORCE_VENDOR=1`: force `vendor/parallelus/`.
- If both are set: fail fast with an error.

**Auditability requirement:**
- Upgrade output must print detection inputs (`strong_count`, `context_count`,
  matched paths/markers), selected mode, and whether an override was used.

### Upgrade algorithm (idempotent)

The deploy/upgrade helper should execute these steps in order, and be safe to
re-run if interrupted:

1. **Detect + lock mode:**
   - Decide target namespace (`parallelus/` or `vendor/parallelus/`) from state
     detection rules.
   - Emit a migration summary in dry-run mode before mutating files.
2. **Install bundle payload:**
   - Copy/update bundle files into target namespace.
   - Write/update sentinel manifest with `bundle_id`, `layout_version`,
     `upstream_repo`, and `bundle_version`.
3. **Migrate tracked docs paths (if present):**
   - `docs/agents/**` → `parallelus/manuals/**`
   - `docs/plans/*.md` + `docs/progress/*.md` →
     `docs/branches/<slug>/{PLAN,PROGRESS}.md`
   - `docs/reviews/**` + `docs/self-improvement/**` →
     `docs/parallelus/**`
4. **Migrate runtime/session paths:**
   - root `sessions/` → `./.parallelus/sessions/` using the migration helper.
   - Switch writers to `./.parallelus/sessions/` and keep dual-read during
     transition.
5. **Migrate engine paths:**
   - `.agents/**` → `<bundle-root>/engine/**` (where `<bundle-root>` is either
     `parallelus` or `vendor/parallelus`).
   - Update internal references/entrypoints to direct script paths.
6. **Finalize + verify:**
   - Run structural validation checks for expected new paths and required files.
   - Report legacy leftovers that were intentionally kept or need manual review.

### Compatibility and rollback policy

- **Dual-read window:** for one layout-version window, readers accept both legacy
  and new locations for sessions and select process artifacts.
- **Single-write rule:** once upgraded, writers only emit to new locations.
- **No destructive deletes in upgrade step:** legacy paths are archived or left
  in place until validation passes; cleanup happens in an explicit follow-up
  step.
- **Safe retry:** interrupted upgrades can be re-run without duplicating files or
  corrupting state.

### Acceptance criteria for pre-reorg upgrades

An upgraded host repo is considered successful when all are true:

1. Bundle sentinel exists and validates in the active bundle namespace.
2. Process entrypoints resolve to direct scripts under
   `<bundle-root>/engine/bin/…`.
3. New sessions are written under `./.parallelus/sessions/`.
4. Plan/progress/reviews/self-improvement artifacts resolve to the new tracked
   locations.
5. `make deploy` and core workflow checks pass after migration.

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

Detailed executable slicing, gates, and rollback criteria are tracked in:
`docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`.

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
- Legacy-first-upgrade detection (no sentinel): use the fingerprint heuristic in
  “Pre-Reorg Host Repo Upgrade Path” with conservative fallback to
  `vendor/parallelus/` when ambiguous.
- Bundle ownership detection for `parallelus/` vs `vendor/parallelus/`: use the
  sentinel policy and precedence rules in “Pre-Reorg Host Repo Upgrade Path”.
- Project customizations contract: use `docs/parallelus/custom/` with the
  configuration and hook interface defined below.

## Customization Contract (Resolved)

Project-owned customizations are loaded from `docs/parallelus/custom/` so they
survive replacement of the bundle in `parallelus/` or `vendor/parallelus/`.

### Layout

```
docs/parallelus/custom/
  config.yaml
  hooks/
    pre_bootstrap.sh
    post_bootstrap.sh
    pre_start_session.sh
    post_start_session.sh
    pre_turn_end.sh
    post_turn_end.sh
```

Files are optional. Missing files mean “no customization” for that hook/event.

### `config.yaml` schema

- `version`: required integer (`1` for initial contract).
- `enabled`: optional boolean (default `true`).
- `hooks`: optional object keyed by hook name with values:
  - `enabled`: optional boolean (default `true`)
  - `timeout_seconds`: optional integer (default `30`)
  - `on_error`: `fail` or `warn` (default: `fail` for `pre_*`, `warn` for `post_*`)

### Discovery and execution rules

1. Engine checks `docs/parallelus/custom/config.yaml`.
2. If config missing, execute hooks by file presence with defaults.
3. If config exists and `enabled=false`, skip all custom hooks.
4. Hooks execute with:
   - CWD = repo root
   - executable = `/bin/sh`
   - env vars:
     - `PARALLELUS_REPO_ROOT`
     - `PARALLELUS_BUNDLE_ROOT`
     - `PARALLELUS_EVENT` (hook/event name)
5. Timeouts and error handling follow `config.yaml` policy.
6. Hook output is streamed and tagged with `[custom-hook:<name>]`.

### Safety rules

- Hooks must live under `docs/parallelus/custom/hooks/`; no external paths.
- Non-executable hook files are ignored with a warning.
- Failed `pre_*` hooks with `on_error=fail` abort the parent command.
- `post_*` hook failures never abort already-completed primary work.

## Open Questions (Remaining)

No open design questions remain in this plan revision.
