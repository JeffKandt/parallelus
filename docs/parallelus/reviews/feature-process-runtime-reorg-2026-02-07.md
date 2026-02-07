# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 950f2d2f19874486fa681a08917ad216feb44ca2
Reviewed-On: 2026-02-07
Decision: approved
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...950f2d2f19874486fa681a08917ad216feb44ca2`).
- Focused verification of commits since the prior approved review point (`3d1325a7a3824bdc6f1abd0e486703b15954fabd..950f2d2f19874486fa681a08917ad216feb44ca2`), including `PHASE-05` customization-hook rollout.

## Gate Evaluation
- Gate: Scope + metadata aligned to requested branch/commit.
  - gate satisfied? yes
  - evidence:
    - `git rev-parse HEAD` -> `950f2d2f19874486fa681a08917ad216feb44ca2`.
    - `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'` -> `feature/process-runtime-reorg 950f2d2f19874486fa681a08917ad216feb44ca2`.
    - `git diff --stat origin/main..HEAD | tail -1` -> `208 files changed, 7130 insertions(+), 825 deletions(-)`.
  - remaining risks: none.

- Gate: Hooks execute at documented lifecycle events.
  - gate satisfied? yes
  - evidence:
    - Lifecycle hook invocations are wired in `parallelus/engine/bin/agents-ensure-feature:40`, `parallelus/engine/bin/agents-session-start:39`, `parallelus/engine/bin/agents-turn-end:34`.
    - Contract test coverage in `parallelus/engine/tests/test_custom_hooks.py:66` validates `pre/post` execution for bootstrap, start_session, and turn_end.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_custom_hooks.py -q` -> `4 passed in 5.42s`.
  - remaining risks: host-defined hook scripts can still introduce non-determinism/perf cost; mitigated by timeout controls.

- Gate: `pre_*` failure behavior blocks as configured; `post_*` failure behavior warns.
  - gate satisfied? yes
  - evidence:
    - Policy enforcement in `parallelus/engine/bin/agents-custom-hook:192` and post-hook non-abort safety override in `parallelus/engine/bin/agents-custom-hook:228`.
    - Blocking/warn behavior tests in `parallelus/engine/tests/test_custom_hooks.py:130` and `parallelus/engine/tests/test_custom_hooks.py:150`.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_custom_hooks.py -q` -> `4 passed in 5.42s`.
  - remaining risks: none beyond expected operator-owned hook quality.

- Gate: Disabled/custom-missing modes are no-op and safe.
  - gate satisfied? yes
  - evidence:
    - No-op handling paths in `parallelus/engine/bin/agents-custom-hook:279` and `parallelus/engine/bin/agents-custom-hook:282`.
    - Targeted validation in `parallelus/engine/tests/test_custom_hooks.py:189`.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_custom_hooks.py -q` -> `4 passed in 5.42s`.
  - remaining risks: invalid config for `pre_*` hooks still fails closed by design (`parallelus/engine/bin/agents-custom-hook:275`).

## Findings
- Severity: Medium | Area: `review-preflight` launch portability
  - summary: `subagent_manager.sh review-preflight` still depends on `python3` having `PyYAML`; on hosts where system `python3` lacks `yaml`, launch fails after retrospective checks.
  - evidence:
    - Unconditional `import yaml` in `parallelus/engine/bin/subagent_manager.sh:805`.
    - `which python3` -> `/opt/homebrew/bin/python3`; `python3 -c 'import yaml'` -> `ModuleNotFoundError: No module named 'yaml'`.
    - `pytest parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started -q` -> fails with `ModuleNotFoundError`.
    - `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_review_preflight.py -q` -> `3 passed in 5.37s`.
  - impact: launch behavior is environment-sensitive and can fail in otherwise valid operator shells.
  - remediation notes:
    - Add explicit dependency precheck with actionable error before launch.
    - Prefer stdlib front-matter parsing or force venv-resolved interpreter consistently in the launcher path.

- Severity: Low | Area: Bundle manifest/schema contract parity
  - summary: runtime sentinel validation does not enforce all schema constraints declared in `bundle-manifest.v1.json`.
  - evidence:
    - Validator only checks `layout_version` type and non-empty `installed_on` in `parallelus/engine/bin/deploy_agents_process.sh:263` and `parallelus/engine/bin/deploy_agents_process.sh:275`.
    - Schema requires `layout_version` minimum `1` and `installed_on` `date-time` format in `parallelus/schema/bundle-manifest.v1.json:22` and `parallelus/schema/bundle-manifest.v1.json:34`.
  - impact: malformed-but-type-correct manifests can pass detection, weakening migration/install safety checks.
  - remediation notes:
    - Validate sentinel content against `parallelus/schema/bundle-manifest.v1.json` (or enforce equivalent constraints in script).
    - Add negative tests for below-minimum `layout_version` and invalid timestamp formats.

## Tests & Evidence Reviewed
- `git rev-parse HEAD`
- `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'`
- `git diff --stat origin/main..HEAD | tail -1`
- `git diff --stat 3d1325a7a3824bdc6f1abd0e486703b15954fabd..HEAD | tail -1`
- `PATH="$PWD/.venv/bin:$PATH" make ci`
- `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests -q`
- `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_custom_hooks.py -q`
- `PATH="$PWD/.venv/bin:$PATH" pytest parallelus/engine/tests/test_review_preflight.py -q`
- `pytest parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started -q`
- `PATH="$PWD/.venv/bin:$PATH" pytest tests -q`

## Conclusion
- No Blocker/High findings identified at `950f2d2f19874486fa681a08917ad216feb44ca2`.
- Approval stands with one medium and one low follow-up.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
