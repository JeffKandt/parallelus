Reviewed-Branch: feature/publish-repo
Reviewed-Commit: d56535dfad1894fc1df1efca42e8cb4c2f99c7a0
Reviewed-On: 2025-10-16
Decision: changes requested

## Findings
- **Severity: High** – Guardrail toggles never engage. `.agents/agentrc:16-17` introduces `AGENTS_REQUIRE_RETRO` / `AGENTS_REQUIRE_SENIOR_REVIEW`, but the enforcement scripts still read the legacy keys. `docs/self-improvement` gating continues to check `REQUIRE_AGENT_CI_AUDITS` via `.agents/bin/verify-retrospective:8-46`, and `retro-marker` references the same constant at `.agents/bin/retro-marker:11-120`. Because the new knobs are ignored, operators cannot disable / switch auditors as documented, and future branches could silently bypass the retrospective requirement by setting the old key back to 0. Align the loader constants (and the senior-review hook, once it exists) with the new names, add regression coverage, and ensure both retro and review gates honour the documented configuration.

## Summary
The tmux socket awareness, subagent orchestration improvements, CI-audit template fixes, and tooling docs look solid. However, the guardrail configuration shipped in `.agents/agentrc` is inert—the verification helpers still listen for the previous key names—so the most critical gating feature remains miswired. Ship is blocked until the configuration flag mismatch is resolved and covered by tests or automated checks.

## Recommendations
1. Update `verify-retrospective`, `retro-marker`, and any related hooks to consume `AGENTS_REQUIRE_RETRO` / `AGENTS_REQUIRE_SENIOR_REVIEW` (or rename the agentrc entries back to the legacy keys) and add a quick self-check that fails when the expected flag is missing.
2. Add a follow-up to wire the senior-review requirement gate to `AGENTS_REQUIRE_SENIOR_REVIEW` so the documented flag actually controls the launch/merge guard.
