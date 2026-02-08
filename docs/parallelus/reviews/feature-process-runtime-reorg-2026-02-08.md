# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 429c6dcc7e4824671a79ec600d52c26479ab1628
Reviewed-On: 2026-02-08
Decision: changes_requested
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...429c6dcc7e4824671a79ec600d52c26479ab1628`).
- Focused verification of commits since the prior approved review point (`950f2d2f19874486fa681a08917ad216feb44ca2..429c6dcc7e4824671a79ec600d52c26479ab1628`), including `PHASE-06` migration flow and preflight wrapper updates.

## Gate Evaluation
- Gate: Scope + metadata aligned to requested branch/commit.
  - gate satisfied? yes
  - evidence:
    - `git rev-parse HEAD` -> `429c6dcc7e4824671a79ec600d52c26479ab1628`.
    - `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'` -> `feature/process-runtime-reorg 429c6dcc7e4824671a79ec600d52c26479ab1628`.
    - `git diff --stat origin/main..HEAD | tail -1` -> `215 files changed, 9266 insertions(+), 1680 deletions(-)`.
  - remaining risks: none.

- Gate: `Migration works from: legacy pre-reorg repo state`
  - gate satisfied? yes
  - evidence:
    - `parallelus/engine/tests/test_upgrade_migration.py:86` (`test_overlay_upgrade_migrates_legacy_layout_and_writes_report`) validates migration from `.agents`, `docs/plans`, `docs/progress`, `docs/reviews`, `docs/self-improvement`, and `sessions` into the reorg layout.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_upgrade_migration.py -q` -> `4 passed in 3.01s`.
  - remaining risks: legacy migration assertions are strong for `parallelus/` installs but do not cover vendor-root post-upgrade command usability.

- Gate: `Migration works from: mixed/interrupted state`
  - gate satisfied? yes
  - evidence:
    - `parallelus/engine/tests/test_upgrade_migration.py:130` (`test_overlay_upgrade_classifies_mixed_interrupted_state`) verifies mixed-state classification and successful run.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_upgrade_migration.py -q` -> `4 passed in 3.01s`.
  - remaining risks: test coverage for mixed state validates classification/result status but not full post-upgrade command-path execution.

- Gate: `Migration works from: already-reorged state (idempotent no-op or safe update)`
  - gate satisfied? yes
  - evidence:
    - `parallelus/engine/tests/test_upgrade_migration.py:147` (`test_overlay_upgrade_rerun_on_reorg_repo_is_safe`) validates rerun success, `reorg_deployment` classification, and sentinel continuity.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_upgrade_migration.py -q` -> `4 passed in 3.01s`.
  - remaining risks: current test uses in-place `parallelus/` namespace only.

- Gate: `Re-running migration does not duplicate/corrupt artifacts.`
  - gate satisfied? yes
  - evidence:
    - Re-run behavior is explicitly exercised in `parallelus/engine/tests/test_upgrade_migration.py:158` through `parallelus/engine/tests/test_upgrade_migration.py:167`.
    - `parallelus/engine/bin/deploy_agents_process.sh:946`, `parallelus/engine/bin/deploy_agents_process.sh:975`, `parallelus/engine/bin/deploy_agents_process.sh:1002`, `parallelus/engine/bin/deploy_agents_process.sh:1030`, and `parallelus/engine/bin/deploy_agents_process.sh:1047` use non-overwriting `rsync_copy ... --ignore-existing` for migration steps.
  - remaining risks: idempotence validation does not yet include vendor-root command execution after migration.

## Findings
- Severity: High | Area: vendor-root upgrade runtime viability
  - summary: when namespace detection locks to `vendor/parallelus`, core bootstrap flow is broken because helper scripts still call hardcoded `parallelus/engine/...` paths.
  - evidence:
    - Namespace lock to vendor is expected for ambiguous repos (`parallelus/engine/bin/deploy_agents_process.sh:163`, `parallelus/engine/bin/deploy_agents_process.sh:1546`).
    - `agents-ensure-feature` uses hardcoded runtime path `parallelus/engine/bin/agents-detect` (`parallelus/engine/bin/agents-ensure-feature:71`) and similarly hardcodes `parallelus/engine/bin/*` in related hooks (`parallelus/engine/bin/agents-ensure-feature:40`, `parallelus/engine/bin/agents-ensure-feature:50`).
    - Repro:
      - `deploy_agents_process.sh --detect-namespace <clean-repo>` -> `NAMESPACE_DECISION=vendor/parallelus`.
      - `deploy_agents_process.sh --overlay-upgrade <clean-repo>` completes with `Locked bundle root: vendor/parallelus`.
      - `eval "$(make start_session)" && make bootstrap slug=vendor-test` fails: `agents-ensure-feature: line 71: parallelus/engine/bin/agents-detect: No such file or directory`.
  - impact: a valid upgrade path yields non-functional command entrypoints (`make bootstrap` and any flow depending on hardcoded paths), blocking normal operator workflow.
  - remediation notes:
    - Replace hardcoded `parallelus/engine/bin/...` invocations with script-dir-derived paths or shared path resolvers already used elsewhere in the branch.
    - Add migration coverage for vendor-root end-to-end lifecycle (`start_session` + `bootstrap` + `turn_end`) to prevent regressions.

- Severity: Medium | Area: review-preflight launch portability
  - summary: `review-preflight` still depends on `python3` having `PyYAML`; hosts without `yaml` fail during launch even when retrospective steps succeed.
  - evidence:
    - Unconditional `import yaml` in `parallelus/engine/bin/subagent_manager.sh:844`.
    - `python3 -c 'import yaml'` -> `ModuleNotFoundError: No module named 'yaml'`.
    - `pytest parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started -q` fails with `ModuleNotFoundError: No module named 'yaml'`.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_review_preflight.py -q` -> `5 passed in 9.47s`.
  - impact: launch behavior is environment-sensitive and can fail in valid shells that are not venv-pinned.
  - remediation notes:
    - Add a dependency precheck with explicit remediation before parsing role front matter.
    - Prefer stdlib parsing for the small YAML front-matter surface or enforce venv interpreter resolution in launcher code.

- Severity: Low | Area: bundle manifest/schema contract parity
  - summary: runtime sentinel validation still under-enforces schema constraints (`minimum` and `date-time` format).
  - evidence:
    - Validator checks only type/non-empty for `layout_version` and `installed_on` (`parallelus/engine/bin/deploy_agents_process.sh:342`, `parallelus/engine/bin/deploy_agents_process.sh:354`).
    - Schema requires `layout_version` minimum and `installed_on` date-time format (`parallelus/schema/bundle-manifest.v1.json:22`, `parallelus/schema/bundle-manifest.v1.json:34`).
  - impact: malformed-but-type-correct manifests can pass namespace validation.
  - remediation notes:
    - Validate sentinel payload against `parallelus/schema/bundle-manifest.v1.json` (or mirror all schema constraints exactly in code).
    - Add negative tests for `layout_version < 1` and invalid `installed_on` formats.

## Tests & Evidence Reviewed
- `git rev-parse HEAD`
- `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'`
- `git diff --stat origin/main..HEAD | tail -1`
- `git diff --stat 950f2d2f19874486fa681a08917ad216feb44ca2..HEAD | tail -1`
- `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_upgrade_migration.py -q`
- `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_review_preflight.py -q`
- `PATH="$PWD/.venv/bin:$PATH" make ci`
- `python3 -c 'import yaml'`
- `pytest parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started -q`
- `deploy_agents_process.sh --detect-namespace <temp-repo>`
- `deploy_agents_process.sh --overlay-upgrade <temp-repo>`
- `eval "$(make start_session)" && make bootstrap slug=vendor-test` (in vendor-root upgraded temp repo)

## Conclusion
- `PHASE-06` migration gates are mostly demonstrated for the tested in-place namespace scenarios.
- Approval is withheld due one **High** regression: vendor-root upgrades can produce non-functional bootstrap/runtime command paths.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
