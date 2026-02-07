# Senior Architect Review - feature/process-runtime-reorg

Reviewed-Branch: feature/process-runtime-reorg
Reviewed-Commit: 6caff9b5339311ada452af26f0b8a6ffd187e9fb
Reviewed-On: 2026-02-07
Decision: changes_requested
Reviewer: senior-review-gpt-5

## Scope
- Full feature-branch delta intended for merge to `main` (`origin/main...6caff9b5339311ada452af26f0b8a6ffd187e9fb`).
- Focused review on PHASE-03 namespace migration/runtime scripts, subagent lifecycle hardening, and new regression coverage.

## Gate Evaluation
- Scope + metadata aligned to requested branch/commit — **Yes**.
  - Evidence: `git rev-parse HEAD` == `6caff9b5339311ada452af26f0b8a6ffd187e9fb`; review metadata updated accordingly.
- Core adapter/runtime path changes remain functionally validated — **Yes (with caveat)**.
  - Evidence:
    - `python -m pytest -q tests` -> `1 passed`.
    - `python -m pytest -q .agents/tests/test_bundle_namespace_detection.py` -> `7 passed`.
    - `python -m pytest -q .agents/tests/test_subagent_manager.py` -> `4 passed`.
    - `python -m pytest -q .agents/tests/test_bundle_namespace_detection.py .agents/tests/test_session_paths.py -k 'not deploy_scaffold_gitignore_includes_parallelus_runtime_dir'` -> `15 passed, 1 deselected`.
- Newly added regression suite is deterministic and non-destructive — **No**.
  - Evidence:
    - `python -m pytest -q .agents/tests` -> `4 failed, 19 passed`.
    - Repro command: `python -m pytest -q .agents/tests/test_session_paths.py::test_deploy_scaffold_gitignore_includes_parallelus_runtime_dir` returns pass, but mutates repo context from `HEAD/6caff9b` to `feature/my-feature/e8acd8b`.

## Findings
- Severity: Blocker | Area: Test safety + deploy script execution model
  - Summary: A newly introduced test invokes deploy scaffolding from the live repository root, and deploy templates use unquoted heredocs with Markdown backticks. Backticks are command-substituted by the shell, so running the test executes unintended commands (`make bootstrap`, `make archive`, `make merge`, etc.) against the caller repo.
  - Evidence:
    - `.agents/tests/test_session_paths.py:257` runs `deploy_agents_process.sh` with `cwd=REPO_ROOT` and only asserts `.gitignore` content.
    - `.agents/bin/deploy_agents_process.sh:583` and `.agents/bin/deploy_agents_process.sh:851` use `<<EOF` blocks containing backticks (for example at `.agents/bin/deploy_agents_process.sh:587`, `.agents/bin/deploy_agents_process.sh:858`).
    - Runtime repro from this review:
      - Before: `HEAD/6caff9b`
      - After single deploy-scaffold test: `feature/my-feature/e8acd8b`
      - `stderr` contains executed command fallout (for example `slug= is required, e.g. make bootstrap slug=my-feature`).
  - Impact:
    - Test execution mutates reviewer/operator branch state and can trigger unrelated workflow commands.
    - Full `.agents/tests` becomes order-dependent and fails with misleading downstream assertions in `test_subagent_manager.py`.
    - This violates guardrail expectations for read-only validation and undermines merge confidence.
  - Remediation:
    - Convert affected heredocs to quoted delimiters (`<<'EOF'`) or escape backticks so template text is rendered literally.
    - Isolate deploy-scaffold testing to a temp repo context only; do not execute deploy with `cwd=REPO_ROOT`.
    - Add an explicit invariant test: capture `git rev-parse --abbrev-ref HEAD`/`git rev-parse HEAD` before and after deploy-scaffold execution and assert unchanged.

- Severity: Low | Area: Manifest schema parity
  - Summary: Runtime bundle sentinel validation remains weaker than the checked-in JSON schema.
  - Evidence:
    - `.agents/bin/deploy_agents_process.sh:263` only enforces integer type for `layout_version` (no `minimum: 1`).
    - `.agents/bin/deploy_agents_process.sh:274` only enforces non-empty string for `installed_on` (no `date-time` format check).
    - `parallelus/schema/bundle-manifest.v1.json:22` and `parallelus/schema/bundle-manifest.v1.json:34` require those stricter constraints.
  - Remediation:
    - Validate sentinel payloads directly against `parallelus/schema/bundle-manifest.v1.json` (or enforce equivalent checks), and add negative tests for `layout_version < 1` and invalid `installed_on` timestamps.

## Drift Incident Log
- During validation, branch context drifted from the scoped detached commit to `feature/my-feature` whenever the deploy-scaffold session-path test ran. The review flow repeatedly restored `HEAD` to `6caff9b5339311ada452af26f0b8a6ffd187e9fb` before collecting further evidence.

## Conclusion
- Merge approval is blocked pending remediation of the deploy-scaffold command-substitution/test-isolation issue above.
- After fixes land, rerun at minimum:
  - `python -m pytest -q .agents/tests`
  - `python -m pytest -q tests`
  - A dedicated no-worktree-mutation assertion around deploy scaffold behavior.

## Provenance
- Model: GPT-5 Codex
- Sandbox Mode: danger-full-access
- Approval Policy: never
- Session Mode: synchronous subagent
