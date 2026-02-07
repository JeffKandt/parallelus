# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 96d8968c4586c016af62be46c2a1ef719e76d4d0
Reviewed-On: 2026-02-07
Decision: approved
Reviewer: senior-review-gpt-5

## Summary
- PHASE-01 and PHASE-02 guardrail changes are implemented and validated at the reviewed commit, with one non-blocking schema-parity gap remaining in namespace sentinel validation.

## PHASE-02 Gate Evaluation
- Gate: New sessions write to `./.parallelus/sessions/` — **Yes**.
  - Evidence: `.agents/tests/test_session_paths.py::test_session_start_writes_to_parallelus_sessions_root`, `.agents/tests/smoke.sh`, and `./.venv/bin/pytest -q .agents/tests/test_bundle_namespace_detection.py .agents/tests/test_session_paths.py` (`13 passed`).
- Gate: Legacy `sessions/` remains readable — **Yes**.
  - Evidence: `.agents/tests/test_session_paths.py::test_turn_end_reads_legacy_session_directory`, `.agents/tests/test_session_paths.py::test_collect_failures_scans_new_and_legacy_session_logs`, `.agents/tests/test_session_paths.py::test_default_output_dir_uses_legacy_session_when_env_dir_not_set`.
- Gate: Marker/failure extraction/folding still works on existing branches — **Yes**.
  - Evidence: `.agents/tests/test_session_paths.py::test_collect_failures_dedupes_overlapping_parallelus_globs`, `./.venv/bin/pytest ...` pass, and earlier phase validation command `AGENTS_ALLOW_FOLD_WITHOUT_TURN_END=1 .agents/bin/fold-progress apply --target "$(mktemp)" docs/progress/feature-process-runtime-reorg.md`.
- Remaining risks: One non-blocking low-severity manifest schema/runtime parity gap remains (see finding below).

## Findings
- Severity: Low | Area: Bundle sentinel validation parity | Summary: Runtime manifest validation remains looser than the checked-in JSON schema and may classify semantically invalid sentinels as valid.
  - Evidence: `deploy_agents_process.sh` accepts any Python `int` for `layout_version` without the schema minimum check and only checks `installed_on` as non-empty text (`.agents/bin/deploy_agents_process.sh` at reviewed commit lines ~263-276), while the schema requires `layout_version >= 1` and `installed_on` `date-time` format (`parallelus/schema/bundle-manifest.v1.json` lines 20-35).
  - Recommendation: Validate against `parallelus/schema/bundle-manifest.v1.json` directly during detection, or tighten inline checks (`type(...) is int` with lower bound and RFC3339/date-time validation) and add negative tests.

## Tests & Evidence Reviewed
- Branch/commit under review: `feature/process-runtime-reorg` @ `96d8968c4586c016af62be46c2a1ef719e76d4d0`.
- Diff scope reviewed: `git diff origin/main...96d8968c4586c016af62be46c2a1ef719e76d4d0` (focus on session-path migration, failure collection, rollout extraction, namespace detection, and related tests/docs).
- Validation run in isolated detached worktree pinned to reviewed commit:
  - `bash -n .agents/bin/deploy_agents_process.sh` (`bash_syntax_ok`)
  - `.agents/adapters/python/env.sh >/dev/null`
  - `./.venv/bin/pytest -q .agents/tests/test_bundle_namespace_detection.py .agents/tests/test_session_paths.py` (`13 passed`)
  - `.agents/bin/deploy_agents_process.sh --detect-namespace .` (`NAMESPACE_DECISION=parallelus`, `NAMESPACE_REASON=legacy_parallelus`)

## Follow-Ups / Tickets
- [ ] Tighten manifest validation parity in `.agents/bin/deploy_agents_process.sh` and add explicit negative tests for `layout_version` minimum and `installed_on` date-time validation.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
