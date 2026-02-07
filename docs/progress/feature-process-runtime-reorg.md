# Branch Progress — feature/process-runtime-reorg

## 2026-02-04 20:05:30 UTC
**Objectives**
- implement process-vs-runtime reorg items from `docs/deployment-upgrade-and-layout-notes.md`
- update Beads integration docs based on current design discussion

**Work Performed**
- reviewed `AGENTS.md` guardrails and ran `make read_bootstrap`
- bootstrapped branch `feature/process-runtime-reorg` and started session `20251049-20260204200536-b8e8c8`
- captured initial objectives/checklist updates in the branch plan notebook

**Artifacts**
- `docs/plans/feature-process-runtime-reorg.md`
- `docs/progress/feature-process-runtime-reorg.md`

**Next Actions**
- review `docs/deployment-upgrade-and-layout-notes.md` and enumerate concrete reorg changes to implement
- update `docs/agents/integrations/beads.md` to reflect the branch/worktree semantics and “optional Beads” adoption strategy

## 2026-02-04 20:12:10 UTC
**Objectives**
- implement initial “process vs runtime” adjustments (reduce PR noise from runtime artifacts)
- update Beads docs based on current discussion (sync branch semantics; optional adoption)

**Work Performed**
- updated failures collection to scan runtime guardrail-run paths under `.parallelus/guardrails/runs/` (while retaining legacy `docs/guardrails/runs/` scanning)
- updated the rollout-extraction tool default output to `.parallelus/guardrails/runs/extracted` when no active session artifacts directory is available
- updated `docs/deployment-upgrade-and-layout-notes.md` and `docs/agents/project/structure.md` to clarify runtime-vs-tracked placement expectations
- updated `docs/agents/integrations/beads.md` to cover branches/worktrees vs “done” semantics, and to clarify the “optional Beads” pilot flow

**Artifacts**
- `.agents/bin/collect_failures.py`
- `.agents/bin/extract_codex_rollout.py`
- `docs/deployment-upgrade-and-layout-notes.md`
- `docs/agents/project/structure.md`
- `docs/agents/integrations/beads.md`

**Next Actions**
- run `make ci` and record results
- continue implementing any remaining reorg items from `docs/deployment-upgrade-and-layout-notes.md` that we agree are in-scope for this branch

## 2026-02-04 20:12:55 UTC
**Objectives**
- validate the branch via `make ci`

**Work Performed**
- ran `make ci` and confirmed the full suite passed

**Next Actions**
- decide whether any additional “process vs runtime” layout moves are needed beyond the current “write new run artifacts to `.parallelus/`” convention

## 2026-02-04 20:18:10 UTC
**Objectives**
- draft a concrete plan for the process/runtime reorg and future migrations without moving files yet

**Work Performed**
- added `docs/deployment-upgrade-and-layout-PLAN.md` describing the target layout:
  - `docs/` reserved for project docs except `docs/PLAN.md`, `docs/PROGRESS.md`, and `docs/branches/<slug>/…`
  - all other Parallelus-owned tracked artifacts move under `parallelus/…`
  - runtime/high-churn artifacts live under `./.parallelus/…` (gitignored)
- captured an initial mapping of existing paths to their intended destinations and recorded open questions for review

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

**Next Actions**
- review and refine the `parallelus/` and `./.parallelus/` subfolder structure until the plan is final
- confirm the migration mapping (what moves, what remains as explicit `docs/` exceptions)

## 2026-02-04 20:24:40 UTC
**Objectives**
- update the layout plan so `parallelus/` is replaceable on upgrade and project-specific evidence lives under `docs/parallelus/`

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` to split:
  - `parallelus/…` as an upstream-owned, replaceable bundle (manuals/templates/etc.)
  - `docs/parallelus/…` as project-owned instance artifacts (reviews, retrospectives, curated run archives)
- updated the migration mapping accordingly (reviews + self-improvement move under `docs/parallelus/…`)

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

**Next Actions**
- review and iterate on the `docs/parallelus/` subfolder structure and any additional `docs/` exceptions we want to allow

## 2026-02-04 20:31:20 UTC
**Objectives**
- update the plan to relocate the `.agents/` engine under `parallelus/engine/` to avoid collisions in consuming projects

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` to introduce `parallelus/engine/` as the future home for the current `.agents/` tree
- added a migration mapping section for `.agents/**` → `parallelus/engine/**` plus new open questions about naming and bundle placement

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

## 2026-02-05 16:59:21 UTC
**Objectives**
- enable Codex SQLite state-db capture and document access patterns

**Work Performed**
- reviewed `AGENTS.md` and `PROJECT_AGENTS.md` guardrails
- started session `20251050-20260205165903-b2ab22` via `make start_session`

## 2026-02-06 15:31:10 UTC
**Objectives**
- update Codex SQLite state DB doc with TUI log capture + notify hook notes

**Work Performed**
- reviewed `AGENTS.md`, `PROJECT_AGENTS.md`, and `.agents/custom/README.md` guardrails
- started session `20251051-20260206153110-8584b3` via `make start_session`

**Work Performed**
- updated `docs/codex-sqlite-state-db.md` with the sqlite unstable-feature warning text and the notify hook payload shape/example

**Artifacts**
- `docs/codex-sqlite-state-db.md`

## 2026-02-06 15:34:12 UTC
**Objectives**
- document Codex SQLite state DB behavior and how it relates to session metadata/log capture

**Work Performed**
- created `docs/codex-sqlite-state-db.md` describing the local Codex sqlite state DB, log-capture expectations, and the end-of-turn `notify` hook payload shape
- captured the branch marker file `docs/self-improvement/markers/feature-process-runtime-reorg.json` (new)

**Artifacts**
- `docs/codex-sqlite-state-db.md` (new; currently unstaged)
- `docs/self-improvement/markers/feature-process-runtime-reorg.json` (new; currently unstaged)

**Next Actions**
- decide whether `docs/codex-sqlite-state-db.md` should be tracked as a project doc (recommended) or relocated under a Parallelus-owned namespace during the reorg
- stage or discard the new marker file intentionally (avoid leaving it accidentally untracked)

## 2026-02-06 17:50:36 UTC
**Objectives**
- expand the layout reorg plan with concrete open questions + implementation work items
- research whether `parallelus/` is likely to collide in host repos (naming/namespace)

**Work Performed**
- reviewed `AGENTS.md`, `PROJECT_AGENTS.md`, and `.agents/custom/README.md` guardrails
- started session `20251053-20260206175036-e4e384` via `make start_session`
- updated `docs/deployment-upgrade-and-layout-PLAN.md`:
  - added a terminology section to distinguish source repo vs bundle vs host repo vs instance artifacts
  - converted the “Open Questions” list into structured items with pros/cons/recommendations
  - added an “Implementation Work Items” section to capture resulting tasks implied by the decided layout
  - removed “tmux optional” language (tmux is not a reorg decision)
  - added naming-collision notes for the `parallelus/` folder (web + GitHub sampling)
- updated branch plan notebook to remove placeholder “summary” checklist items and align next steps

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`
- `docs/plans/feature-process-runtime-reorg.md`

## 2026-02-06 18:07:30 UTC
**Objectives**
- incorporate maintainer decisions on namespace collisions, sessions placement, folding policy, and entrypoint strategy

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` per maintainer decisions:
  - added `./.parallelus/sessions/` as the new sessions home and documented migration mitigations (dual-read/single-write, config, migration helper)
  - clarified that branch notebook folding/cleanup follows the current documented process (this reorg is path-only, not a policy change)
  - switched the plan’s entrypoint stance to “direct script entrypoints first” (Makefile, if kept, becomes a compatibility shim)
  - pruned the “Open Questions” section down to only remaining decisions (bundle ownership detection sentinel + customization lookup contract)
- updated the branch plan notebook next actions to match the remaining open items

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`
- `docs/plans/feature-process-runtime-reorg.md`

## 2026-02-07 00:12:00 UTC
**Objectives**
- add explicit pre-reorg host repo upgrade coverage to the layout plan

**Work Performed**
- added a dedicated pre-reorg host upgrade path to the plan, including:
  - host-state classification (legacy/reorg/conflict/mixed)
  - ordered idempotent migration algorithm
  - compatibility + rollback policy
  - acceptance criteria for successful host upgrades
- added one new open question to resolve deterministic first-upgrade detection
  for legacy repos that have no sentinel yet

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

## 2026-02-07 13:32:34 UTC
**Objectives**
- convert the accepted legacy-detection recommendation into concrete plan policy

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` to resolve the
  first-upgrade/no-sentinel detection question with explicit:
  - strong fingerprints + context markers
  - threshold-based classification rules
  - forced-mode override env vars and conflict behavior
  - audit-output requirements for upgrade runs
- removed that item from “Open Questions” and recorded it under resolved
  decisions

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`

## 2026-02-07 13:36:37 UTC
**Objectives**
- resolve the final two open questions and mark the layout plan as design-complete

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-PLAN.md` to resolve:
  - bundle ownership detection (`parallelus/` vs `vendor/parallelus/`) with
    sentinel schema, precedence, and conflict handling
  - project customization interface under `docs/parallelus/custom/` with
    concrete layout, config schema, hook execution contract, and safety rules
- removed the remaining open-question entries and marked the plan as having no
  unresolved design questions
- updated branch plan next actions to focus on implementation sequencing rather
  than outstanding design decisions

**Artifacts**
- `docs/deployment-upgrade-and-layout-PLAN.md`
- `docs/plans/feature-process-runtime-reorg.md`

## 2026-02-07 13:43:29 UTC
**Objectives**
- produce a detailed execution plan now that design questions are resolved

**Work Performed**
- created `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md` with:
  - phased PR slices (`PR-01` through `PR-07`)
  - per-slice goals, primary file areas, and acceptance gates
  - validation matrix and rollback/recovery policy
- added a cross-reference from `docs/deployment-upgrade-and-layout-PLAN.md` to
  the new execution plan
- updated branch plan checklist/next actions to start with `PR-01` execution

**Artifacts**
- `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`
- `docs/deployment-upgrade-and-layout-PLAN.md`
- `docs/plans/feature-process-runtime-reorg.md`

## 2026-02-07 14:05:35 UTC
**Objectives**
- align execution-plan terminology with local branch workflow and provide
  reusable phase-neutral kickoff prompt text

**Work Performed**
- updated `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`:
  - renamed `PR-01..PR-07` to `PHASE-01..PHASE-07`
  - updated validation/references to phase terminology
  - added a phase-neutral “Session Kickoff Prompt” template that instructs each
    new session to detect and execute the next incomplete phase
- updated branch plan next actions to reference `PHASE-01/PHASE-02` wording

**Artifacts**
- `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`
- `docs/plans/feature-process-runtime-reorg.md`

## 2026-02-07 14:09:36 UTC
**Objectives**
- make phase-neutral kickoff prompt robust to notebook path migration during execution

**Work Performed**
- updated the kickoff prompt in
  `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md` to:
  - detect active branch notebook paths across both layouts
  - prefer `docs/branches/<slug>/...` when both old and new paths exist
  - require updates to whichever notebook layout is active for the phase

**Artifacts**
- `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`

## 2026-02-07 14:23:20 UTC
**Objectives**
- continue layout reorg execution by implementing only `PHASE-01`
- determine the next incomplete phase from the execution plan + active notebooks
- acknowledge required startup guardrails before code edits

**Work Performed**
- reviewed `AGENTS.md`, `PROJECT_AGENTS.md`, and `.agents/custom/README.md`
- ran `eval "$(make start_session)"` and captured session `20251054-20260207142153-5d4004`
- read:
  - `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`
  - `docs/plans/feature-process-runtime-reorg.md`
  - `docs/progress/feature-process-runtime-reorg.md`
- confirmed only pre-migration notebook layout exists (`docs/plans|docs/progress`); no `docs/branches/...` canonical files yet
- determined next incomplete phase is `PHASE-01` (sentinel + namespace detection infrastructure)

**Next Actions**
- implement `PHASE-01` scope only:
  - add sentinel schema artifact
  - add namespace detection/override conflict handling in deploy tooling
  - add targeted tests for precedence + fallback paths
- run targeted validations and capture concrete gate evidence
- commit + push, then run Senior Architect review for this phase and iterate until approved

## 2026-02-07 14:27:41 UTC
**Objectives**
- complete `PHASE-01` implementation and gather acceptance-gate evidence

**Work Performed**
- added sentinel schema artifact at:
  - `parallelus/schema/bundle-manifest.v1.json`
- implemented namespace detection infrastructure in:
  - `.agents/bin/deploy_agents_process.sh`
  - new `--detect-namespace` mode for auditable decision output
  - sentinel validation for `parallelus/.parallelus-bundle.json` and `vendor/parallelus/.parallelus-bundle.json`
  - fallback legacy heuristic (`strong_count` + `context_count`)
  - explicit overrides:
    - `PARALLELUS_UPGRADE_FORCE_IN_PLACE=1`
    - `PARALLELUS_UPGRADE_FORCE_VENDOR=1`
    - conflict fail-fast when both are set
- added targeted tests:
  - `.agents/tests/test_bundle_namespace_detection.py`
  - covers: managed `parallelus`, managed `vendor/parallelus`, no-sentinel fallback, malformed sentinel handling, override behavior, conflict error path

**Validation Evidence**
- `bash -n .agents/bin/deploy_agents_process.sh`
  - outcome: pass (no syntax errors)
- `.agents/adapters/python/env.sh >/dev/null && ./.venv/bin/pytest -q .agents/tests/test_bundle_namespace_detection.py`
  - outcome: pass (`7 passed in 0.48s`)
- `.agents/bin/deploy_agents_process.sh --detect-namespace .`
  - outcome: `NAMESPACE_DECISION=parallelus`, `NAMESPACE_REASON=legacy_parallelus`, `LEGACY_STRONG_COUNT=4`, `LEGACY_CONTEXT_COUNT=2`
- `PARALLELUS_UPGRADE_FORCE_IN_PLACE=1 PARALLELUS_UPGRADE_FORCE_VENDOR=1 .agents/bin/deploy_agents_process.sh --detect-namespace .`
  - outcome: exit `1` with `Error: PARALLELUS_UPGRADE_FORCE_IN_PLACE and PARALLELUS_UPGRADE_FORCE_VENDOR cannot both be set`
- `python3 - <<'PY' ... json.loads('parallelus/schema/bundle-manifest.v1.json') ... PY`
  - outcome: `schema-json-ok`

**Phase Gate Check (`PHASE-01`)**
- managed `parallelus/` sentinel detection precedence: satisfied (`test_detection_prefers_parallelus_when_both_manifests_are_valid`)
- managed `vendor/parallelus/` sentinel detection: satisfied (`test_detection_uses_vendor_manifest_when_parallelus_manifest_missing`)
- no-sentinel legacy heuristic fallback: satisfied (`test_detection_legacy_fallback_without_manifests`)
- malformed sentinel handling: satisfied (`test_detection_skips_malformed_parallelus_manifest`)
- overrides + conflict fail-fast: satisfied (`test_detection_override_force_in_place`, `test_detection_override_force_vendor`, `test_detection_conflicting_overrides_fail_fast`)

**Residual Risks**
- detection is wired for audit/reporting and overlay invocation, but phase-1 does not yet migrate copy/write paths to namespace-specific bundle roots (planned for later phases)
- sentinel validation currently checks required fields/types but does not enforce URI/date-time semantics beyond non-empty strings in deploy script runtime checks

**Next Actions**
- commit and push `PHASE-01` changes
- launch Senior Architect review for current `HEAD` and confirm explicit gate evaluation in the review artifact

## 2026-02-07 14:29:48 UTC
**Objectives**
- prepare required audit/review workflow after pushing `PHASE-01`

**Work Performed**
- pushed commit `4883f21` to `origin/feature/process-runtime-reorg`
- reviewed required subagent manuals prior to launching review/auditor subagents:
  - `docs/agents/subagent-session-orchestration.md`
  - `docs/agents/manuals/senior-architect.md`
- ran prerequisite failure collection:
  - `make collect_failures`
  - outcome: wrote `docs/self-improvement/failures/feature-process-runtime-reorg--2026-02-06T15:38:52.371063+00:00.json`

**Next Actions**
- run the Continuous Improvement Auditor prompt for the latest marker and persist the JSON report to:
  - `docs/self-improvement/reports/feature-process-runtime-reorg--2026-02-06T15:38:52.371063+00:00.json`
- commit/push audit artifacts so the senior-review launcher precheck passes
- launch Senior Architect review subagent for current `HEAD`

## 2026-02-07 14:34:36 UTC
**Objectives**
- satisfy mandatory retrospective-audit prerequisites before Senior Architect review launch

**Work Performed**
- committed audit prerequisites in `6a34fdc`:
  - `docs/progress/feature-process-runtime-reorg.md`
  - `docs/self-improvement/failures/feature-process-runtime-reorg--2026-02-06T15:38:52.371063+00:00.json`
- launched Continuous Improvement Auditor via subagent manager:
  - initial auto-launch blocked (no tmux session)
  - relaunched with manual launcher using repo venv on `PATH`:
    - `PATH=\"$PWD/.venv/bin:$PATH\" .agents/bin/subagent_manager.sh launch --type throwaway --slug ci-audit --role continuous_improvement_auditor --launcher manual`
  - launch id: `20260207-143050-ci-audit`
- executed the generated sandbox runner manually to complete the auditor prompt:
  - `/Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/ci-audit-UVqGyL/.parallelus_run_subagent.sh`
- captured auditor JSON output and saved report:
  - `docs/self-improvement/reports/feature-process-runtime-reorg--2026-02-06T15:38:52.371063+00:00.json`
- cleaned stale subagent registry entry after completion:
  - `.agents/bin/subagent_manager.sh cleanup --id 20260207-143050-ci-audit --force`
- validated audit linkage:
  - `.agents/bin/verify-retrospective`
  - outcome: found matching report for latest marker

**Residual Risks**
- manual-launch fallback was required due missing tmux session in this environment; audit still executed and report was persisted, but monitor-loop automation was not available for this run

**Next Actions**
- commit/push the retrospective report artifact
- launch Senior Architect review subagent on current `HEAD`

## 2026-02-07 14:35:24 UTC
**Objectives**
- launch Senior Architect review loop for `PHASE-01` scope on current `HEAD`

**Work Performed**
- re-reviewed required subagent/review manuals immediately before launch:
  - `docs/agents/subagent-session-orchestration.md`
  - `docs/agents/manuals/senior-architect.md`
- confirmed clean worktree and pushed head:
  - `git status --short --branch` → clean on `feature/process-runtime-reorg`
  - pushed `c8b184c` to `origin/feature/process-runtime-reorg`

**Next Actions**
- launch Senior Architect subagent review for current `HEAD`
- harvest review artifact, address findings if any, and rerun until approved
