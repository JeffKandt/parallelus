# Senior Architect Review — feature/publish-repo

Reviewed-Branch: feature/publish-repo  
Reviewed-Commit: 6fdb91f7f97260492d73a4abbf53c0c368796322  
Reviewed-On: 2025-10-16  
Decision: changes requested

## Findings

### Blocker — Role parsing requires PyYAML but the dependency is missing
- Evidence: `.agents/bin/subagent_manager.sh:314` imports `yaml`, yet no runtime dependency provides it; `requirements.txt:1-4` only adds `black`, `ruff`, and `pytest`.
- Impact: On a clean machine the very first `subagent_manager.sh --role …` call exits with `ModuleNotFoundError: No module named 'yaml'`, so the new guardrails for role front matter and CI audits are unusable.
- Remediation: Add `PyYAML` (or another YAML parser) to the managed environment — e.g. pin it in `requirements.txt` and ensure the adapter installs it — or refactor the parsing logic to avoid the extra dependency.

### High — Role overrides pass JSON-quoted strings to Codex
- Evidence: `role_config_to_env` serialises every value with `json.dumps` (`.agents/bin/subagent_manager.sh:374-381`), so a role specifying `profile: gpt-oss` exports `SUBAGENT_CODEX_PROFILE="\"gpt-oss\""`. `launch_subagent.sh` then forwards that literal (`.agents/bin/launch_subagent.sh:160-193`), causing Codex to receive `--profile "gpt-oss"` (quotes included) and reject the profile.
- Impact: Any non-default model/profile/sandbox overrides set in a role prompt fail at launch, defeating the purpose of wiring those knobs into front matter.
- Remediation: Use plain shell quoting for strings (e.g. `shlex.quote(val)` without wrapping via `json.dumps`) and reserve JSON encoding for composite types such as lists/dicts.

### High — `SUBAGENT_CODEX_CONFIG_OVERRIDES` leaks across launches
- Evidence: Role overrides populate `SUBAGENT_CODEX_CONFIG_OVERRIDES` via `role_config_to_env` (`.agents/bin/subagent_manager.sh:374-379`), but `cmd_launch` only snapshots/restores a subset of env vars (`.agents/bin/subagent_manager.sh:702-709`), so the override persists after `run_launch`. Subsequent launches inherit the stale overrides even when no role requests them.
- Impact: After one senior review sets `config_overrides: { reasoning_effort: high }`, every later subagent silently runs with the same Codex tuning, violating principle-of-least-surprise and potentially increasing cost.
- Remediation: Track `SUBAGENT_CODEX_CONFIG_OVERRIDES` (and any future override vars) in the restore list or otherwise scope them to each launch.

## Summary
The tmux socket integration and transcript capture work are promising, but the new role-normalisation path cannot succeed end-to-end today. Missing PyYAML support blocks role-based launches outright, and even once that is fixed, quoting/restore bugs will keep Codex overrides from behaving predictably.

## Follow-ups
- Add the YAML dependency and verify `subagent_manager.sh --role …` succeeds on a fresh checkout.
- Correct the quoting/restore logic and rerun both the Continuous Improvement auditor and senior review flows to confirm overrides behave as expected.
