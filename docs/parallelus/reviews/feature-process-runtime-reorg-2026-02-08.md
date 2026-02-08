# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 142c97a9123c66f29599394f2c74f5c4e299d04c
Reviewed-On: 2026-02-08
Decision: approved
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...142c97a9123c66f29599394f2c74f5c4e299d04c`).
- Deep verification focus for this rerun: remediation commits since prior review point `429c6dcc7e4824671a79ec600d52c26479ab1628`.

## Gate Evaluation
- Gate: Scope + metadata aligned to requested branch/commit.
  - gate satisfied? yes
  - evidence:
    - `git rev-parse HEAD` -> `142c97a9123c66f29599394f2c74f5c4e299d04c`.
    - `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'` -> `feature/process-runtime-reorg 142c97a9123c66f29599394f2c74f5c4e299d04c`.
    - `git diff --stat origin/main..142c97a9123c66f29599394f2c74f5c4e299d04c | tail -1` -> `222 files changed, 9779 insertions(+), 1680 deletions(-)`.
    - `git diff --stat 429c6dcc7e4824671a79ec600d52c26479ab1628..142c97a9123c66f29599394f2c74f5c4e299d04c | tail -1` -> `18 files changed, 532 insertions(+), 19 deletions(-)`.
  - remaining risks: none.

- Gate: `Migration works from: legacy pre-reorg repo state`
  - gate satisfied? yes
  - evidence:
    - Legacy migration coverage exists at `parallelus/engine/tests/test_upgrade_migration.py:86` (`test_overlay_upgrade_migrates_legacy_layout_and_writes_report`).
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py parallelus/engine/tests/test_bundle_namespace_detection.py parallelus/engine/tests/test_session_paths.py` -> `21 passed in 8.93s`.
  - remaining risks: coverage is strongest for in-place namespace; vendor-specific lifecycle behavior is validated separately below.

- Gate: `Migration works from: mixed/interrupted state`
  - gate satisfied? yes
  - evidence:
    - Mixed/interrupted classification coverage exists at `parallelus/engine/tests/test_upgrade_migration.py:130` (`test_overlay_upgrade_classifies_mixed_interrupted_state`).
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py parallelus/engine/tests/test_bundle_namespace_detection.py parallelus/engine/tests/test_session_paths.py` -> `21 passed in 8.93s`.
  - remaining risks: mixed-state test validates classification + successful run, but not every downstream command path permutation.

- Gate: `Migration works from: already-reorged state (idempotent no-op or safe update)`
  - gate satisfied? yes
  - evidence:
    - Idempotent rerun coverage exists at `parallelus/engine/tests/test_upgrade_migration.py:169` (`test_overlay_upgrade_rerun_on_reorg_repo_is_safe`).
    - Vendor runtime viability regression coverage exists at `parallelus/engine/tests/test_upgrade_migration.py:147` (`test_vendor_namespace_upgrade_keeps_bootstrap_entrypoints_working`) and validates `make start_session` + `make bootstrap` after `vendor/parallelus` migration.
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py parallelus/engine/tests/test_bundle_namespace_detection.py parallelus/engine/tests/test_session_paths.py` -> `21 passed in 8.93s`.
  - remaining risks: no dedicated coverage yet for symlinked path alias behavior (see Low finding below).

- Gate: `Re-running migration does not duplicate/corrupt artifacts.`
  - gate satisfied? yes
  - evidence:
    - Rerun assertions are exercised in `parallelus/engine/tests/test_upgrade_migration.py:180` through `parallelus/engine/tests/test_upgrade_migration.py:189`.
    - Non-overwriting migration semantics are enforced by `rsync_copy ... --ignore-existing` at `parallelus/engine/bin/deploy_agents_process.sh:941`, `parallelus/engine/bin/deploy_agents_process.sh:961`, `parallelus/engine/bin/deploy_agents_process.sh:978`, `parallelus/engine/bin/deploy_agents_process.sh:999`, `parallelus/engine/bin/deploy_agents_process.sh:1009`, `parallelus/engine/bin/deploy_agents_process.sh:1033`, and `parallelus/engine/bin/deploy_agents_process.sh:1051`.
  - remaining risks: non-destructive semantics intentionally leave legacy trees in place until `PHASE-07` cleanup/decommission.

## Findings
- Severity: Medium | Area: review-preflight launch portability
  - summary: review-preflight still requires system `python3` to provide `PyYAML`; non-venv hosts fail even when retrospective preflight succeeds.
  - evidence:
    - Unconditional `import yaml` in `parallelus/engine/bin/subagent_manager.sh:844`.
    - `python3 -c 'import yaml'` -> `ModuleNotFoundError: No module named 'yaml'`.
    - `pytest -q parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started` fails with `ModuleNotFoundError: No module named 'yaml'`.
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py` -> `5 passed in 8.86s`.
  - impact: launch behavior remains environment-sensitive outside venv-pinned execution paths.
  - remediation notes:
    - Resolve/validate interpreter dependencies before launch parsing, or
    - Replace this YAML parse path with a stdlib-only front-matter parser for the constrained key set.

- Severity: Low | Area: bootstrap base-branch fallback path canonicalization
  - summary: fallback check in `agents-ensure-feature` can mis-detect bundle presence when `ENGINE_ROOT` and git root use different path aliases (for example `/var` vs `/private/var`), producing false fallback warnings and potentially selecting the current branch unnecessarily.
  - evidence:
    - Relative-path derivation depends on raw string prefix stripping at `parallelus/engine/bin/agents-ensure-feature:41`.
    - Existence check and fallback branch rewrite at `parallelus/engine/bin/agents-ensure-feature:107` through `parallelus/engine/bin/agents-ensure-feature:113`.
    - `PATH="$PWD/.venv/bin:$PATH" make ci` emitted: `agents-ensure-feature: base branch 'main' does not contain /var/folders/.../parallelus/engine; using 'main' as bootstrap base`.
  - impact: branch ancestry choice may become path-spelling dependent in symlinked/canonicalized working-directory scenarios.
  - remediation notes:
    - Canonicalize both paths (`realpath`/`pwd -P`) before computing `engine_rel`.
    - Add a regression test that runs bootstrap through alternate path aliases.

- Severity: Low | Area: bundle manifest/schema contract parity
  - summary: runtime sentinel validation still under-enforces schema constraints.
  - evidence:
    - Validator checks type/non-empty only in `parallelus/engine/bin/deploy_agents_process.sh:342` and `parallelus/engine/bin/deploy_agents_process.sh:354`.
    - Schema requires `layout_version >= 1` and `installed_on` `date-time` format in `parallelus/schema/bundle-manifest.v1.json:22` and `parallelus/schema/bundle-manifest.v1.json:34`.
  - impact: malformed-but-type-correct sentinels can still pass runtime validation.
  - remediation notes:
    - Enforce full schema parity in runtime validator.
    - Add negative tests for `layout_version < 1` and invalid `installed_on` format.

## Tests & Evidence Reviewed
- `git rev-parse HEAD`
- `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'`
- `git diff --stat origin/main..142c97a9123c66f29599394f2c74f5c4e299d04c | tail -1`
- `git diff --stat 429c6dcc7e4824671a79ec600d52c26479ab1628..142c97a9123c66f29599394f2c74f5c4e299d04c | tail -1`
- `git diff --name-status 429c6dcc7e4824671a79ec600d52c26479ab1628..142c97a9123c66f29599394f2c74f5c4e299d04c`
- `PATH="$PWD/.venv/bin:$PATH" bash -n parallelus/engine/bin/agents-ensure-feature parallelus/engine/bin/agents-merge parallelus/engine/bin/agents-session-logging-active parallelus/engine/bin/agents-session-start parallelus/engine/bin/agents-turn-end parallelus/engine/bin/install-hooks`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py parallelus/engine/tests/test_bundle_namespace_detection.py parallelus/engine/tests/test_session_paths.py`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py`
- `pytest -q parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started`
- `python3 -c 'import yaml'`
- `PATH="$PWD/.venv/bin:$PATH" make ci`

## Conclusion
- The prior High-severity vendor-runtime breakage has been remediated, and `PHASE-06` acceptance gates are satisfied on current `HEAD`.
- Approval is granted for this commit with one Medium and two Low follow-up items tracked above.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
