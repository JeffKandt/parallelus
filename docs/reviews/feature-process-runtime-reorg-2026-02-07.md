# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: fead9ea8e7360b2d85e7150590bf3ea5a7de31fe
Reviewed-On: 2026-02-07
Decision: approved
Reviewer: senior-review-gpt-5

## Summary
- `PHASE-01` acceptance scope is implemented and evidenced: sentinel schema added, namespace detection logic added to deploy tooling, and targeted tests cover precedence/override/failure behavior.
- Detection behavior is observable via `--detect-namespace` and reported during overlay runs, with explicit outputs for chosen namespace, sentinel validity, and legacy signal matches.
- Regression coverage is present and passing for the new detection matrix.

## Findings
- Severity: Low | Area: Test isolation | Summary: Detection tests inherit the full parent process environment, so pre-set `PARALLELUS_UPGRADE_FORCE_IN_PLACE` or `PARALLELUS_UPGRADE_FORCE_VENDOR` variables could make nominal-path tests flaky outside CI defaults.
  - Evidence: `.agents/tests/test_bundle_namespace_detection.py:16` builds `run_env = os.environ.copy()` and only merges overrides.
  - Remediation: In `_run_detect`, explicitly remove the two override env vars unless a test intentionally sets them.

## Remediation Notes
- Finding is non-blocking for this phase and does not invalidate current pass results, but should be addressed before broadening detection test usage across varied environments.

## Evidence Reviewed
- `git diff origin/main...HEAD` with focus on:
  - `.agents/bin/deploy_agents_process.sh`
  - `.agents/tests/test_bundle_namespace_detection.py`
  - `parallelus/schema/bundle-manifest.v1.json`
  - `.agents/bin/collect_failures.py`
  - `.agents/bin/extract_codex_rollout.py`
- Test execution:
  - `pytest -q .agents/tests/test_bundle_namespace_detection.py` (7 passed)
- Runtime check:
  - `.agents/bin/deploy_agents_process.sh --detect-namespace <repo-clone>`

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
