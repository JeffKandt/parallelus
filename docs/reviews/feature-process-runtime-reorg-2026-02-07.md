# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: c0a8ef53a60959f9e407fc882256477200e862eb
Reviewed-On: 2026-02-07
Decision: approved
Reviewer: senior-review-gpt-5

## Summary
- `PHASE-01` scope is implemented and validated at the reviewed commit: sentinel schema, namespace detection precedence, override handling, and deterministic tests.
- The prior low-risk flake vector (inherited override env vars in tests) is fixed in `_run_detect`.
- Validation evidence confirms syntax, test coverage, and runtime detection output behavior for current `HEAD`.

## PHASE-01 Gate Evaluation
- Gate: managed `parallelus/` precedence when both sentinels are valid — **Yes** (`test_detection_prefers_parallelus_when_both_manifests_are_valid`).
- Gate: managed `vendor/parallelus/` detection when `parallelus/` sentinel is missing — **Yes** (`test_detection_uses_vendor_manifest_when_parallelus_manifest_missing`).
- Gate: no-sentinel legacy heuristic fallback — **Yes** (`test_detection_legacy_fallback_without_manifests`).
- Gate: malformed sentinel handling with safe fallback — **Yes** (`test_detection_skips_malformed_parallelus_manifest`).
- Gate: override support (`PARALLELUS_UPGRADE_FORCE_IN_PLACE`, `PARALLELUS_UPGRADE_FORCE_VENDOR`) — **Yes** (`test_detection_override_force_in_place`, `test_detection_override_force_vendor`).
- Gate: conflicting overrides fail fast — **Yes** (`test_detection_conflicting_overrides_fail_fast`; runtime command exits non-zero).

## Findings
- Severity: Low | Area: Sentinel validation parity | Summary: Runtime manifest validation is looser than the new schema and can classify semantically invalid manifests as valid.
- Evidence: `.agents/bin/deploy_agents_process.sh:263` accepts any Python `int` (including boolean), `.agents/bin/deploy_agents_process.sh:275` only checks non-empty `installed_on`, while `parallelus/schema/bundle-manifest.v1.json:22` requires `layout_version >= 1` and `parallelus/schema/bundle-manifest.v1.json:34` requires `date-time` format.
- Remediation: Either validate sentinels against `parallelus/schema/bundle-manifest.v1.json` during detection, or tighten inline checks (`type(...) is int`, minimum bound, date-time parse) and add negative tests for these cases.

## Remediation Notes
- The finding is non-blocking for `PHASE-01` acceptance because precedence/override/error-path behavior is correctly implemented and tested.
- Tightening schema parity should be completed before namespace decisions become write-path authoritative in later phases.

## Evidence Reviewed
- `git diff origin/main...HEAD` with focus on:
- `.agents/bin/deploy_agents_process.sh`
- `.agents/tests/test_bundle_namespace_detection.py`
- `parallelus/schema/bundle-manifest.v1.json`
- `.agents/bin/collect_failures.py`
- `.agents/bin/extract_codex_rollout.py`
- Validation run on reviewed commit:
- `bash -n .agents/bin/deploy_agents_process.sh` (`bash_syntax_ok`)
- `.agents/adapters/python/env.sh >/dev/null && ./.venv/bin/pytest -q .agents/tests/test_bundle_namespace_detection.py` (`7 passed in 0.39s`)
- `.agents/bin/deploy_agents_process.sh --detect-namespace .` (reported `NAMESPACE_DECISION=parallelus`, `NAMESPACE_REASON=legacy_parallelus`)
- `PARALLELUS_UPGRADE_FORCE_IN_PLACE=1 PARALLELUS_UPGRADE_FORCE_VENDOR=1 .agents/bin/deploy_agents_process.sh --detect-namespace .` (error + non-zero exit)

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
