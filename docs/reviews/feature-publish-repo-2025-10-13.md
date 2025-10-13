Reviewed-Branch: feature/publish-repo
Reviewed-Commit: ed185908f1916adb711eadc711afbfc0c82d23ce
Reviewed-On: 2025-10-13
Decision: changes requested

## Findings

1. Severity: Blocker — `make ci` cannot succeed without the Python toolchain dependencies
   - Location: requirements.txt:1
   - Details: The new Python adapter bootstraps the environment by installing `requirements.txt` before running `ruff`, `black --check`, and `pytest` (`.agents/adapters/python/env.sh:24-33`, `.agents/agentrc:12-14`). The requirements file is effectively empty, so the virtualenv never receives those tools and `make ci` will fail with `command not found` errors. That breaks the stated “CI readiness” objective and leaves the guardrails unusable.
   - Recommendation: Populate `requirements.txt` (or a dedicated dev requirements file loaded here) with the lint/test dependencies (`ruff`, `black`, `pytest`, plus any transitive needs) so the adapter provisions everything it later invokes.

2. Severity: High — Role config overrides leak into subsequent launches
   - Location: .agents/bin/subagent_manager.sh:717
   - Details: `create_prompt_file` evaluates `role_config_to_env`, which can export `SUBAGENT_CODEX_CONFIG_OVERRIDES`. The restoration list omits that variable, so once a role sets overrides they remain in the parent shell and affect every later subagent, even when the role should not carry them. That violates least surprise and can silently skew Codex behaviour.
   - Recommendation: Add `SUBAGENT_CODEX_CONFIG_OVERRIDES` (and any future role-controlled vars) to `tracked_env_vars` so the manager faithfully restores the caller’s environment after each launch.

3. Severity: High — Heartbeat overlay reports the freshest log instead of the stalest
   - Location: .agents/bin/subagent_prompt_phase.py:104
   - Details: The tmux status overlay computes `value = min(ages)` across running subagents. With two sessions (one quiet for 12 minutes, one just wrote), the display shows `00:05`, masking that a subagent is stalled. The overlay is meant to surface stale logs, so this regression defeats the safety signal.
   - Recommendation: Track the maximum age (worst case) when summarising heartbeat data so the status bar reflects the oldest log timestamp and still turns “ready” only when no subagents are active.

## Summary

The guardrail refresh heads in the right direction, but missing Python dependencies, leaky role overrides, and an inverted heartbeat metric undermine CI confidence and observability. Address those regressions before retrying review.

## Follow-ups

- Add the lint/test toolchain packages to `requirements.txt` (or adjust `env.sh`/commands) and verify `make ci` succeeds in a clean venv.
- Extend the environment restoration array to include `SUBAGENT_CODEX_CONFIG_OVERRIDES`, then smoke-test alternating roles to confirm no leakage.
- Switch the heartbeat aggregation to report the maximum log age and validate the tmux overlay flags long-running idle subagents correctly.
