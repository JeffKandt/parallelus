# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 2256785bcc5a192a82b5ac24fa4f84664c6c5fd6
Reviewed-On: 2026-02-08
Decision: approved
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...2256785bcc5a192a82b5ac24fa4f84664c6c5fd6`).
- Focused verification for this refresh: commits since prior approved review point `a483ebef1f550656b66ea7b65877c394ad35f2e8..2256785bcc5a192a82b5ac24fa4f84664c6c5fd6` (review-freshness enforcement and managed-hook drift auto-sync).
- Phase-gate source: `PHASE-07` acceptance gate in `docs/deployment-upgrade-and-layout-EXECUTION-PLAN.md`.

## Gate Evaluation
- Gate: Scope + metadata aligned to requested branch/commit.
  - gate satisfied? yes
  - evidence:
    - `git rev-parse HEAD` -> `2256785bcc5a192a82b5ac24fa4f84664c6c5fd6`.
    - `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'` -> `feature/process-runtime-reorg 2256785bcc5a192a82b5ac24fa4f84664c6c5fd6`.
    - `git diff --stat origin/main..2256785bcc5a192a82b5ac24fa4f84664c6c5fd6 | tail -1` -> `229 files changed, 10489 insertions(+), 1789 deletions(-)`.
    - `git diff --stat a483ebef1f550656b66ea7b65877c394ad35f2e8..2256785bcc5a192a82b5ac24fa4f84664c6c5fd6 | tail -1` -> `12 files changed, 456 insertions(+), 60 deletions(-)`.
  - remaining risks: none.

- Gate: `Full make ci passes.`
  - gate satisfied? yes
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" make ci` -> pass (`agents smoke test passed`, `All checks passed!`, `1 passed in 2.36s`).
  - remaining risks: CI output still emits the known bootstrap path-alias warning in temporary `/var` vs `/private/var` layouts.

- Gate: `Manual smoke of core workflow passes on clean clone/worktree.`
  - gate satisfied? yes
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" parallelus/engine/tests/smoke.sh` -> pass (`agents smoke test passed`) on fresh temporary repo/worktree.
  - remaining risks: smoke covers canonical flow and guardrails, not all host shell/path alias variants.

- Gate: `Pre-reorg upgrade simulation passes end-to-end.`
  - gate satisfied? yes
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py` -> `5 passed in 6.87s`.
  - remaining risks: simulation remains fixture-driven; unusual real-world repo customizations may still expose edge cases.

## Findings
- Severity: Medium | Area: senior-review preflight launch portability
  - summary: launch-time role front-matter parsing still hard-depends on `PyYAML` in system `python3`, so non-venv execution fails even when preflight sequencing and artifacts are valid.
  - evidence:
    - `python3 -c 'import yaml; print("yaml-ok")'` -> `ModuleNotFoundError: No module named 'yaml'`.
    - `pytest -q parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started` -> fails with `ModuleNotFoundError: No module named 'yaml'`.
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py parallelus/engine/tests/test_hook_sync.py` -> `10 passed in 17.62s`.
    - Dependency path remains in `parallelus/engine/bin/subagent_manager.sh:898` and `parallelus/engine/bin/subagent_manager.sh:900`.
  - impact: senior-review launch behavior remains environment-sensitive outside venv-pinned shells.
  - remediation notes:
    - Replace front-matter parsing with a stdlib-only parser for the constrained key set, or
    - force a known interpreter (`$PWD/.venv/bin/python`) for that parser path and fail early with explicit guidance when unavailable.

- Severity: Low | Area: bootstrap base-path canonicalization noise
  - summary: fallback base-branch check still compares non-canonical path spellings, producing false warnings in smoke/CI temporary paths.
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" make ci` and `PATH="$PWD/.venv/bin:$PATH" parallelus/engine/tests/smoke.sh` emit `agents-ensure-feature: base branch 'main' does not contain /var/.../parallelus/engine; using 'main' as bootstrap base`.
    - String-prefix derivation/check remains in `parallelus/engine/bin/agents-ensure-feature:41` and `parallelus/engine/bin/agents-ensure-feature:109`.
  - impact: noisy bootstrap diagnostics and path-spelling-dependent behavior in aliased filesystem contexts.
  - remediation notes:
    - Canonicalize both `repo_root` and `ENGINE_ROOT` (`pwd -P` or `realpath`) before deriving `engine_rel`.
    - Add regression coverage for `/var` versus `/private/var` aliasing.

- Severity: Low | Area: bundle manifest/schema parity
  - summary: runtime sentinel validation still under-enforces schema constraints.
  - evidence:
    - Runtime validator checks type/non-empty only in `parallelus/engine/bin/deploy_agents_process.sh:342` and `parallelus/engine/bin/deploy_agents_process.sh:354`.
    - Schema requires stricter constraints (`minimum: 1`, `format: date-time`) in `parallelus/schema/bundle-manifest.v1.json:22` and `parallelus/schema/bundle-manifest.v1.json:34`.
  - impact: malformed-but-type-correct manifests can pass runtime validation.
  - remediation notes:
    - Enforce schema-equivalent checks in runtime validation.
    - Add negative tests for `layout_version < 1` and invalid `installed_on` timestamps.

## Tests & Evidence Reviewed
- `git rev-parse HEAD`
- `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'`
- `git diff --stat origin/main..2256785bcc5a192a82b5ac24fa4f84664c6c5fd6 | tail -1`
- `git diff --stat a483ebef1f550656b66ea7b65877c394ad35f2e8..2256785bcc5a192a82b5ac24fa4f84664c6c5fd6 | tail -1`
- `PATH="$PWD/.venv/bin:$PATH" make ci`
- `PATH="$PWD/.venv/bin:$PATH" parallelus/engine/tests/smoke.sh`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py parallelus/engine/tests/test_hook_sync.py`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py`
- `python3 -c 'import yaml; print("yaml-ok")'`
- `pytest -q parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started`
- `rg -n "import yaml|yaml.safe_load" parallelus/engine/bin/subagent_manager.sh`

## Conclusion
- `PHASE-07` acceptance gates are satisfied on `2256785bcc5a192a82b5ac24fa4f84664c6c5fd6` with explicit evidence.
- No Blocker/High findings identified; approval is granted with one Medium and two Low follow-up items.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
