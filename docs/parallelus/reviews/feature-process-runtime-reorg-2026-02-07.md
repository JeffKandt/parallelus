# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 2361fcecac45181e63602bc801d72cb627705721
Reviewed-On: 2026-02-07
Decision: approved
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...2361fcecac45181e63602bc801d72cb627705721`).
- Focused review on docs/runtime namespace migration, session/subagent guardrail hardening, and the latest deploy-scaffold safety fixes.

## Gate Evaluation
- Scope + metadata aligned to requested branch/commit — **Yes**.
  - Evidence:
    - `git rev-parse --abbrev-ref HEAD` -> `HEAD` (detached at scoped commit).
    - `git rev-parse HEAD` -> `2361fcecac45181e63602bc801d72cb627705721`.
- Prior blocker (deploy heredoc command-substitution + test isolation drift) is remediated — **Yes**.
  - Evidence:
    - Backticks are escaped in deploy-scaffold generated Markdown text (`.agents/bin/deploy_agents_process.sh:556`, `.agents/bin/deploy_agents_process.sh:844`).
    - Deploy scaffold regression test now runs from an isolated temp runner repo and asserts branch/HEAD invariance (`.agents/tests/test_session_paths.py:256`, `.agents/tests/test_session_paths.py:266`).
- Required validation coverage for changed control-plane scripts/tests — **Yes**.
  - Evidence:
    - `pytest .agents/tests` -> `23 passed in 9.45s`.
    - `pytest tests` -> `1 passed in 2.34s`.
    - `make ci` -> completed successfully (`agents smoke test passed`, adapter checks clean, project tests pass).
- Remaining risks explicitly identified and actionable — **Yes**.

## Findings
- Severity: Low | Area: Bundle manifest validation parity
  - Summary: runtime sentinel validation remains less strict than the checked-in schema and can classify schema-invalid values as valid.
  - Evidence:
    - Validator only checks `layout_version` is `int` and `installed_on` is non-empty text (`.agents/bin/deploy_agents_process.sh:263`, `.agents/bin/deploy_agents_process.sh:274`).
    - Schema requires stronger constraints (`layout_version >= 1`, `installed_on` `date-time`) in `parallelus/schema/bundle-manifest.v1.json:22` and `parallelus/schema/bundle-manifest.v1.json:34`.
  - Impact:
    - Namespace-detection sentinel integrity can drift from contract truth, increasing risk of false-positive “valid” manifests during upgrades.
  - Remediation:
    - Validate manifests against `parallelus/schema/bundle-manifest.v1.json` directly (or mirror its exact constraints), and add negative tests for `layout_version < 1`, boolean `layout_version`, and invalid `installed_on` timestamps.

## Conclusion
- No Blocker/High findings remain at `2361fcecac45181e63602bc801d72cb627705721`.
- Review is approved for merge with one low-severity follow-up.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
