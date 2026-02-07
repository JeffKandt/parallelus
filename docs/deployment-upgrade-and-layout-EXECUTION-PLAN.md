# Deployment, Upgrades, and Layout — Execution Plan

This document translates `docs/deployment-upgrade-and-layout-PLAN.md` into an
implementation sequence with concrete phase slices, validation gates, and rollback
checkpoints.

## Scope and Constraints

- Scope: implement the resolved layout reorg and pre-reorg upgrade path.
- Out of scope: changing merge governance semantics.
- Strategy: small, reversible phase slices; keep host repos operable throughout.
- Safety rule: dual-read compatibility before write-path cutovers.

## Execution Strategy

1. Land infrastructure that can detect/migrate safely.
2. Add compatibility layers (read old + new).
3. Move writers to new paths.
4. Migrate tracked artifacts.
5. Remove legacy references only after validation gates pass.

## Phase Slice Plan

### `PHASE-01` Sentinel + Namespace Detection Infrastructure

**Goals**
- Implement bundle sentinel schema, validation, and namespace decision logic.

**Primary changes**
- Add sentinel schema artifact:
  - `parallelus/schema/bundle-manifest.v1.json`
- Update deploy/upgrade logic:
  - `.agents/bin/deploy_agents_process.sh`
- Add/adjust tests around detection and override behavior:
  - `.agents/tests/` (new/updated targeted tests)

**Acceptance gate**
- Detection precedence works for:
  - managed `parallelus/`
  - managed `vendor/parallelus/`
  - no sentinel (legacy heuristic fallback)
  - malformed sentinel
- Overrides work and conflict (`FORCE_IN_PLACE` + `FORCE_VENDOR`) fails fast.

### `PHASE-02` Central Path Resolution + Session Dual-Read

**Goals**
- Centralize path resolution and enable `sessions/` migration with low risk.

**Primary changes**
- Add shared path-resolution helpers (shell + Python as needed) under:
  - `.agents/bin/` (or, if already moved in later slices, `parallelus/engine/bin/`)
- Update readers to dual-read old + new sessions paths:
  - `.agents/bin/agents-session-start`
  - `.agents/bin/agents-turn-end`
  - `.agents/bin/fold-progress`
  - `.agents/bin/collect_failures.py`
  - `.agents/bin/extract_codex_rollout.py`
  - `.agents/hooks/pre-commit`
  - `.agents/hooks/pre-merge-commit`

**Acceptance gate**
- New sessions write to `./.parallelus/sessions/`.
- Legacy `sessions/` remains readable.
- Marker/failure extraction/folding still works on existing branches.

### `PHASE-03` Docs Namespace Migration (Tracked Artifacts)

**Goals**
- Introduce target docs layout and migrate tracked artifacts safely.

**Primary changes**
- Create/normalize:
  - `docs/parallelus/`
  - `docs/branches/`
- Migrate references and tooling for:
  - `docs/plans/*`, `docs/progress/*` → `docs/branches/<slug>/{PLAN,PROGRESS}.md`
  - `docs/self-improvement/*` → `docs/parallelus/self-improvement/*`
  - `docs/reviews/*` → `docs/parallelus/reviews/*`
- Update affected scripts:
  - `.agents/bin/agents-ensure-feature`
  - `.agents/bin/agents-turn-end`
  - `.agents/bin/agents-merge`
  - `.agents/bin/fold-progress`
  - `.agents/bin/collect_failures.py`
  - `.agents/bin/subagent_manager.sh`

**Acceptance gate**
- Bootstrap, turn-end, fold-progress, merge prechecks pass with new docs layout.
- Canonical logs still fold correctly into `docs/PROGRESS.md`.

### `PHASE-04` Engine and Manuals Relocation

**Goals**
- Move process-owned tracked artifacts into replaceable bundle namespace.

**Primary changes**
- Move `.agents/**` → `parallelus/engine/**`.
- Move `docs/agents/**` → `parallelus/manuals/**`.
- Update all hardcoded references in:
  - `Makefile`
  - scripts under `.agents/bin/` / `parallelus/engine/bin/`
  - hooks
  - tests
  - docs

**Acceptance gate**
- No runtime/script references remain to `.agents/` or `docs/agents/` unless explicitly called out as temporary compatibility.
- All primary commands run via direct script entrypoints under
  `parallelus/engine/bin/` (Make targets may remain thin wrappers).

### `PHASE-05` Customization Contract Implementation

**Goals**
- Implement `docs/parallelus/custom/` discovery/execution contract.

**Primary changes**
- Add customization loader and hook executor.
- Support:
  - `docs/parallelus/custom/config.yaml`
  - `docs/parallelus/custom/hooks/*`
- Enforce timeouts, `on_error`, and safety constraints from the resolved plan.

**Acceptance gate**
- Hooks execute at documented lifecycle events.
- `pre_*` failure behavior blocks as configured; `post_*` failure behavior warns.
- Disabled/custom-missing modes are no-op and safe.

### `PHASE-06` Pre-Reorg Upgrade Command (Idempotent Migration)

**Goals**
- Implement first-class migration path for legacy host repos.

**Primary changes**
- Extend deploy/upgrade tooling to execute full algorithm:
  - detect + lock mode
  - install bundle
  - migrate tracked paths
  - migrate sessions
  - finalize + verify
- Add dry-run output and migration report.

**Acceptance gate**
- Migration works from:
  - legacy pre-reorg repo state
  - mixed/interrupted state
  - already-reorged state (idempotent no-op or safe update)
- Re-running migration does not duplicate/corrupt artifacts.

### `PHASE-07` Cleanup + Legacy Decommission

**Goals**
- Remove temporary compatibility paths after validation window.

**Primary changes**
- Remove legacy path fallbacks that are no longer needed.
- Delete/retire:
  - `docs/deployment-upgrade-and-layout-notes.md` (if no unique value remains)
- Finalize docs so only new layout is documented.

**Acceptance gate**
- Full `make ci` passes.
- Manual smoke of core workflow passes on clean clone/worktree.
- Pre-reorg upgrade simulation passes end-to-end.

## Validation Matrix

Each phase should run only the smallest useful checks plus one broader check:

- Targeted script tests for changed helpers in `.agents/tests/`.
- Path-specific smoke checks for:
  - bootstrap/session start
  - turn_end marker write
  - fold-progress apply/verify
  - merge precheck logic
- `make ci` at least at the end of `PHASE-03`, `PHASE-04`, and `PHASE-07`.

## Rollback and Recovery

- Every migration-capable command must support `--dry-run`.
- Migration steps are non-destructive by default; cleanup is separate.
- Emit machine-readable migration reports for troubleshooting.
- On failure, preserve original locations and print explicit next actions.

## Recommended Tracking

- Keep this execution plan as the implementation source.
- Track execution state in branch notebooks:
  - `docs/branches/feature-process-runtime-reorg/PLAN.md`
  - `docs/branches/feature-process-runtime-reorg/PROGRESS.md`
  - (legacy pre-migration paths may still appear in historical entries:
    `docs/plans/feature-process-runtime-reorg.md` and
    `docs/progress/feature-process-runtime-reorg.md`)
- Optional: mirror each phase slice as Beads items if you want queue visibility
  outside notebooks.

## Session Kickoff Prompt (Phase-Neutral)

Use this in a new session to execute the next phase without hardcoding a phase
number:

```text
Continue execution of the layout reorg on branch `feature/process-runtime-reorg`.

Treat `PHASE-01..PHASE-07` in `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`
as phase IDs (not GitHub pull requests). Work locally on this branch only; do
not merge to main.

First step: determine the next incomplete phase by reading:
- docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md
- active branch notebooks (path depends on migration phase):
  - pre-migration layout:
    - docs/plans/feature-process-runtime-reorg.md
    - docs/progress/feature-process-runtime-reorg.md
  - post-migration layout:
    - docs/branches/feature-process-runtime-reorg/PLAN.md
    - docs/branches/feature-process-runtime-reorg/PROGRESS.md

If both layouts exist, treat `docs/branches/...` as canonical and note any
legacy duplicates that need cleanup in the progress log.

Execution requirements:
1) Implement only the next incomplete phase scope and acceptance gate criteria.
2) Keep diff scoped; do not start later phases.
3) Run targeted validations for changed files/scripts; run broader checks when
   the phase gate requires.
4) Update:
   - the active branch notebooks for the current layout
     (`docs/plans|docs/progress` before migration, or
     `docs/branches/<slug>/{PLAN,PROGRESS}.md` after migration)
   with concrete evidence (commands run, outcomes, residual risks).
5) Commit phase work and push branch.

Review loop (required before declaring phase complete):
6) Launch Senior Architect review for the current phase scope on current HEAD.
   - Default review scope rule: Senior review defaults to full branch diff unless this prompt explicitly bounds scope to the current phase.
7) Reviewer must explicitly evaluate all phase exit gates:
   - gate satisfied? (yes/no)
   - evidence (file paths + command outputs)
   - remaining risks
8) If review is not approved, fix findings, commit, and re-run Senior Architect
   review.
9) Repeat until approved.

Handoff:
10) Provide a concise “phase complete” handoff with:
    - what changed
    - what validated
    - review artifact path
    - explicit statement whether the next phase is unblocked.
    - any difficulties experienced during execution which might warrant considering a change to the plan, process, or prompt used for future phases. Propose any such changes but do not implement them without user permission.
11) Stop after completing that one phase. Do not begin the following phase.
```
