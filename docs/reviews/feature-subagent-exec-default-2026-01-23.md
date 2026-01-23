# Senior Architect Review – feature/subagent-exec-default

Reviewed-Branch: feature/subagent-exec-default
Reviewed-Commit: ac6c31129e49f53e151d65df1ee3b3478c7fbc35
Reviewed-On: 2026-01-23
Decision: approved
Reviewer: senior-review-d53ehj

## Summary
- Fixes role/front-matter boolean handling so explicit `false` values for exec-related flags no longer get treated as “enabled” by virtue of being non-empty strings.
- Improves subagent UX by extending the launch helper to emit correct manual commands for both `codex` and `codex exec`, and by adding `subagent_manager.sh resume` for follow-up prompts in exec-mode sessions.
- Hardens exec-mode operation by ensuring the stream-filter helper is present inside the sandbox even when the sandbox commit differs from the current working tree.

## Findings
- Severity: Medium — Env-var precedence for exec flags is potentially surprising: `launch_subagent.sh` treats `PARALLELUS_CODEX_USE_EXEC` / `PARALLELUS_CODEX_EXEC_JSON` as additive, so a globally-enabled `PARALLELUS_*` can effectively re-enable exec-mode even when a role config sets `use_exec: false`. Consider making `SUBAGENT_CODEX_USE_EXEC` (when set, including falsey) take precedence over `PARALLELUS_CODEX_USE_EXEC`, and similarly for `*_EXEC_JSON`.
- Severity: Low — `is_falsey` does not trim whitespace, so values like `false ` won’t disable a flag; this is likely fine given the controlled emitters, but worth noting if operators set env vars manually.

## Tests & Evidence Reviewed
- Manual inspection of `.agents/bin/launch_subagent.sh` and `.agents/bin/subagent_manager.sh`.
- `bash -n` on the modified shell scripts.
- `python3 -m py_compile` on `.agents/bin/codex_exec_stream_filter.py`.

## Residual Risks
- `launch_subagent.sh` best-effort copies the exec stream filter (`cp ... || true`); if the copy fails unexpectedly and the sandbox does not already contain the helper, exec-mode output piping will fail at runtime.

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
