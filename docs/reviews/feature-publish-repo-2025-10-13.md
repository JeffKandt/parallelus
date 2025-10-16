Reviewed-Branch: feature/publish-repo
Reviewed-Commit: 61aec4acdd976ca5d84721c201c7f86f0d4e455f
Reviewed-On: 2025-10-17
Decision: changes requested

## Findings
- **Severity: High** – Guardrail toggles are wired to the wrong agentrc keys (`.agents/agentrc:16`, `.agents/bin/verify-retrospective:8`, `.agents/bin/retro-marker:8`). The new config adds `AGENTS_REQUIRE_RETRO` / `AGENTS_REQUIRE_SENIOR_REVIEW`, but the enforcement scripts still read `REQUIRE_AGENT_CI_AUDITS` (and related knobs). As a result, the shipped settings never engage, so `make turn_end` / senior-review checks cannot be disabled or reconfigured as documented. Align the loaders with the new key names (or rename the keys back) and cover both retro and review guards.
- **Severity: Medium** – The CI audit scope template promises branch/marker parameterisation, yet `create_scope_file` just copies it verbatim, leaving `{{PARENT_BRANCH}}` / `{{MARKER_PATH}}` placeholders in the generated scope (`docs/agents/templates/ci_audit_scope.md:3`, `.agents/bin/subagent_manager.sh:244`). Subagents still have to fill the values manually, so the template does not deliver the claimed automation. Render the template with actual branch and marker data at launch time (or rewrite it without placeholders) before handing it to the auditor.

## Summary
Process guardrails, tmux work, and documentation look solid, but the new retrospective/review enforcement knobs are inert and the CI audit scope template is still manual, so ship is blocked until those are fixed.

## Recommendations
1. Fix the guardrail flag wiring and add coverage so configuration updates are exercised by tests/tooling.
2. Populate the CI audit scope placeholders programmatically (or drop them) so auditors receive concrete branch/marker context out of the box.
