# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: a483ebef1f550656b66ea7b65877c394ad35f2e8
Reviewed-On: 2026-02-08
Decision: approved
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...a483ebef1f550656b66ea7b65877c394ad35f2e8`).
- Focused verification for this refresh: commits since prior review point `142c97a9123c66f29599394f2c74f5c4e299d04c`, including `PHASE-07` decommissioning and retrospective-artifact refresh.

## Gate Evaluation
- Gate: Scope + metadata aligned to requested branch/commit.
  - gate satisfied? yes
  - evidence:
    - `git rev-parse HEAD` -> `a483ebef1f550656b66ea7b65877c394ad35f2e8`.
    - `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'` -> `feature/process-runtime-reorg a483ebef1f550656b66ea7b65877c394ad35f2e8`.
    - `git diff --stat origin/main..a483ebef1f550656b66ea7b65877c394ad35f2e8 | tail -1` -> `227 files changed, 10093 insertions(+), 1789 deletions(-)`.
    - `git diff --stat 142c97a9123c66f29599394f2c74f5c4e299d04c..a483ebef1f550656b66ea7b65877c394ad35f2e8 | tail -1` -> `35 files changed, 644 insertions(+), 439 deletions(-)`.
  - remaining risks: none.

- Gate: `Full make ci passes.`
  - gate satisfied? yes
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" make ci` -> pass (`All checks passed!`, `agents smoke test passed`, `1 passed in 2.44s`).
  - remaining risks: smoke still emits the known path-alias warning from `agents-ensure-feature` (documented as Low finding).

- Gate: `Manual smoke of core workflow passes on clean clone/worktree.`
  - gate satisfied? yes
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" parallelus/engine/tests/smoke.sh` -> pass (`agents smoke test passed`) on a fresh temp repo/worktree.
  - remaining risks: smoke validates canonical flow and fast-fail guards, but not every host shell/path alias variant.

- Gate: `Pre-reorg upgrade simulation passes end-to-end.`
  - gate satisfied? yes
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py` -> `5 passed in 5.40s`.
    - Coverage includes legacy, mixed/interrupted, vendor namespace bootstrap viability, rerun idempotency, and dry-run reporting (`parallelus/engine/tests/test_upgrade_migration.py:86`, `parallelus/engine/tests/test_upgrade_migration.py:130`, `parallelus/engine/tests/test_upgrade_migration.py:147`, `parallelus/engine/tests/test_upgrade_migration.py:169`, `parallelus/engine/tests/test_upgrade_migration.py:192`).
  - remaining risks: simulation coverage is strong but still synthetic; unusual host customizations may expose migration edge cases not represented in fixtures.

## Findings
- Severity: Medium | Area: senior-review preflight launch portability
  - summary: `review-preflight` still requires `python3` to provide `PyYAML`; non-venv hosts fail in role front-matter parsing even when preflight sequencing is otherwise valid.
  - evidence:
    - `python3 -c 'import yaml'` -> `ModuleNotFoundError: No module named 'yaml'`.
    - `pytest -q parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started` -> fails with `ModuleNotFoundError` at runtime.
    - `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py` -> `6 passed in 12.79s`.
    - Unconditional dependency path remains in `parallelus/engine/bin/subagent_manager.sh:894` and `parallelus/engine/bin/subagent_manager.sh:896`.
  - impact: review launch behavior remains environment-sensitive outside venv-pinned execution paths.
  - remediation notes:
    - Switch to stdlib-only parsing for the constrained front-matter key set, or
    - Enforce interpreter/venv selection before any YAML parse and fail with explicit dependency guidance.

- Severity: Low | Area: bootstrap base-branch fallback path canonicalization
  - summary: the fallback check still compares non-canonical path spellings, producing false warnings (`/var/...` vs `/private/var/...`) in clean smoke/CI runs.
  - evidence:
    - `PATH="$PWD/.venv/bin:$PATH" parallelus/engine/tests/smoke.sh` and `PATH="$PWD/.venv/bin:$PATH" make ci` both emit: `agents-ensure-feature: base branch 'main' does not contain /var/.../parallelus/engine; using 'main' as bootstrap base`.
    - Relative-path derivation remains string-prefix based in `parallelus/engine/bin/agents-ensure-feature:41` and checked in `parallelus/engine/bin/agents-ensure-feature:109`.
  - impact: noisy branch-base warnings and potential path-spelling-dependent branch selection in aliased filesystem contexts.
  - remediation notes:
    - Canonicalize both `repo_root` and `ENGINE_ROOT` (`pwd -P`/`realpath`) before deriving `engine_rel`.
    - Add regression coverage for `/var` vs `/private/var` style aliases.

- Severity: Low | Area: bundle manifest/schema parity
  - summary: runtime validation still under-enforces schema constraints for sentinel metadata.
  - evidence:
    - Runtime validator only checks type/non-empty for some fields in `parallelus/engine/bin/deploy_agents_process.sh:342` and `parallelus/engine/bin/deploy_agents_process.sh:354`.
    - Schema requires stricter constraints (`minimum: 1`, `date-time`) in `parallelus/schema/bundle-manifest.v1.json:22` and `parallelus/schema/bundle-manifest.v1.json:34`.
  - impact: malformed-but-type-correct manifests can pass runtime validation.
  - remediation notes:
    - Enforce full schema-equivalent checks in runtime validation.
    - Add negative tests for below-minimum `layout_version` and invalid timestamp format.

## Tests & Evidence Reviewed
- `git rev-parse HEAD`
- `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'`
- `git diff --stat origin/main..a483ebef1f550656b66ea7b65877c394ad35f2e8 | tail -1`
- `git diff --stat 142c97a9123c66f29599394f2c74f5c4e299d04c..a483ebef1f550656b66ea7b65877c394ad35f2e8 | tail -1`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py parallelus/engine/tests/test_session_paths.py parallelus/engine/tests/test_subagent_manager.py`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_upgrade_migration.py`
- `PATH="$PWD/.venv/bin:$PATH" parallelus/engine/tests/smoke.sh`
- `PATH="$PWD/.venv/bin:$PATH" make ci`
- `python3 -c 'import yaml'`
- `pytest -q parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started`
- `PATH="$PWD/.venv/bin:$PATH" pytest -q parallelus/engine/tests/test_review_preflight.py`

## Conclusion
- `PHASE-07` acceptance gates are satisfied on `a483ebef1f550656b66ea7b65877c394ad35f2e8` with explicit evidence.
- No Blocker/High findings were identified; approval is granted with one Medium and two Low follow-up items.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
