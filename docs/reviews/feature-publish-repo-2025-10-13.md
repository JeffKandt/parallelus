Reviewed-Branch: feature/publish-repo
Reviewed-Commit: f3302c6d9946d4223f10b24b449ba6c3e558ece0
Reviewed-On: 2025-10-16
Decision: changes requested

## Findings
- **Severity: Blocker** – Subagent launches without an explicit role prompt crash under `set -u`. `create_prompt_file` sets `role_read_only` only inside the `if [[ -n "$role_prompt" ]]` branch `.agents/bin/subagent_manager.sh:445-474`, but the subsequent dispatch unconditionally reads `role_read_only` in the `elif` branch `.agents/bin/subagent_manager.sh:503`. Launching a standard throwaway sandbox (`subagent_manager.sh launch --type throwaway --slug foo`) now raises `bash: role_read_only: unbound variable`, aborting orchestration before the scope/prompt land in the sandbox. This regresses every happy-path subagent launch that relied on default prompts. Move the `local role_read_only="false"` declaration outside the conditional (or guard the later read with `${role_read_only:-false}`) and add coverage to keep `set -u` compatible with no-role runs.

## Summary
Most guardrail, tmux, and tooling updates look directionally correct, but the new role-normalization logic broke the default subagent workflow: we can no longer launch a sandbox unless `--role` is provided. Until the orchestration script handles that case safely, the branch cannot merge.

## Recommendations
1. Initialize `role_read_only` to `"false"` before the `if [[ -n "$role_prompt" ]]` block (or use a `${role_read_only:-false}` read) so the variable is defined when no role is supplied.
2. Add a smoke test for `subagent_manager.sh launch --type throwaway --slug <slug>` without `--role` to prevent regressions when extending the prompt-loader.
