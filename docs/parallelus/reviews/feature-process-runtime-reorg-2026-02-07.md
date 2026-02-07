# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 3d1325a7a3824bdc6f1abd0e486703b15954fabd
Reviewed-On: 2026-02-07
Decision: approved
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...3d1325a7a3824bdc6f1abd0e486703b15954fabd`).
- Emphasis on phase-04 changes: runtime/manual namespace relocation completion, serialized `senior_review_preflight` orchestration, and launch-state hardening.

## Gate Evaluation
- Scope + metadata aligned to requested branch/commit — **Yes**.
  - Evidence:
    - `git rev-parse HEAD` -> `3d1325a7a3824bdc6f1abd0e486703b15954fabd`.
    - `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'` -> `feature/process-runtime-reorg 3d1325a7a3824bdc6f1abd0e486703b15954fabd`.
    - `git diff --stat origin/main..3d1325a...` -> `202 files changed, 6135 insertions(+), 825 deletions(-)`.
  - Residual risk: None.
- Required acceptance gates are explicitly evaluated with evidence and actionable residual risks — **Yes**.
  - Evidence: this report includes per-gate status, command outputs, line-level references, and remediation items.
  - Residual risk: Medium/Low findings below remain open.
- Validation coverage for changed orchestration/runtime behavior — **Yes**.
  - Evidence:
    - `make ci` -> pass (`agents smoke test passed`, adapter checks pass, project tests pass).
    - `PATH="$(pwd)/.venv/bin:$PATH" pytest parallelus/engine/tests -q` -> `26 passed`.
    - `pytest tests -q` -> `1 passed`.
  - Residual risk: command-path sensitivity remains for direct non-adapter runs (Finding 1).
- Review metadata targets the scoped branch + commit — **Yes**.
  - Evidence: header fields in this report (`Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`, `Decision`).
  - Residual risk: None.

## Findings
- Severity: Medium | Area: Review preflight launch portability
  - Summary: `review-preflight` launch path depends on `python3` having `PyYAML`; when missing, the flow aborts after retrospective verification instead of transitioning to launch/manual-launch status.
  - Evidence:
    - `parse_role_config()` imports `yaml` unconditionally (`parallelus/engine/bin/subagent_manager.sh:805`).
    - `pytest parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started -q` fails with `ModuleNotFoundError: No module named 'yaml'`.
    - The same test passes when PATH is pinned to the project venv (`PATH="$(pwd)/.venv/bin:$PATH" ...`).
  - Impact:
    - `make senior_review_preflight`/`subagent_manager.sh review-preflight` behavior is environment-dependent; operators outside adapter-managed PATH can hit a hard failure in the launch phase.
  - Remediation:
    - Add an explicit dependency precheck with actionable error text before launch, and/or parse role front matter without non-stdlib dependencies.
    - Standardize interpreter invocation for helper Python blocks (e.g., consistent venv-resolved python) so launch behavior is deterministic.

- Severity: Low | Area: Bundle sentinel/schema parity
  - Summary: bundle-manifest sentinel validation remains weaker than the declared schema contract.
  - Evidence:
    - Validator checks only `layout_version` type and non-empty `installed_on` (`parallelus/engine/bin/deploy_agents_process.sh:263`, `parallelus/engine/bin/deploy_agents_process.sh:275`).
    - Schema requires `layout_version >= 1` and `installed_on` `date-time` (`parallelus/schema/bundle-manifest.v1.json:22`, `parallelus/schema/bundle-manifest.v1.json:34`).
  - Impact:
    - Invalid manifests can be accepted during namespace detection, reducing confidence in upgrade/install safety checks.
  - Remediation:
    - Validate against `parallelus/schema/bundle-manifest.v1.json` (or mirror all constraints exactly) and add negative tests for below-minimum/incompatible values.

## Tests & Evidence Reviewed
- `git rev-parse HEAD`
- `git branch --list 'feature/process-runtime-reorg' --format='%(refname:short) %(objectname)'`
- `git diff --stat origin/main..3d1325a7a3824bdc6f1abd0e486703b15954fabd`
- `make ci`
- `PATH="$(pwd)/.venv/bin:$PATH" pytest parallelus/engine/tests -q`
- `pytest tests -q`
- `pytest parallelus/engine/tests/test_review_preflight.py::test_review_preflight_default_launch_marks_awaiting_when_not_started -q`

## Conclusion
- No Blocker/High findings identified at `3d1325a7a3824bdc6f1abd0e486703b15954fabd`.
- Merge is approved with one medium and one low follow-up.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
