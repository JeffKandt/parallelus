# Senior Architect Review – feature/sa-review-subagent-guardrail

Reviewed-Branch: feature/sa-review-subagent-guardrail
Reviewed-Commit: 8d9de71392f31868e1fd26fa5ff337fbcfd625a2
Reviewed-On: 2025-11-02
Decision: changes-required
Reviewer: senior-review-s0ywER

## Summary
- Monitor auto-exit generally works, but the new numeric parsing can crash the loop for otherwise valid configurations.

## Findings
- Severity: Medium | Area: Monitoring | Summary: Setting `MONITOR_AUTO_EXIT_STALE_POLLS` to a value with a leading zero that also contains an `8` or `9` (e.g. `08`) causes the monitor to exit immediately with `value too great for base`, because Bash interprets the string as octal.  
  - Evidence: `.agents/bin/agents-monitor-loop.sh:46`  
  - Recommendation: Normalize the environment value with base-10 expansion (e.g. `AUTO_EXIT_POLLS=$((10#$AUTO_EXIT_POLLS_RAW))`) or reject inputs with leading zeros to prevent arithmetic errors while `set -e` is active.

## Tests & Evidence Reviewed
- `git show 8d9de71392f31868e1fd26fa5ff337fbcfd625a2`
- Manual inspection of `.agents/bin/agents-monitor-loop.sh` and `.agents/bin/agents-merge`

## Follow-Ups / Tickets
- [ ] Harden `MONITOR_AUTO_EXIT_STALE_POLLS` parsing so base-10 values with leading zeros do not terminate the monitor.

## Provenance
- Model: gpt-5-codex
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
