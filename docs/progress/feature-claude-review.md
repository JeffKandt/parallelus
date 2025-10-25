# Branch Progress — feature/claude-review

## 2025-10-20 14:22:31 UTC
**Objectives**
- Capture the two uncommitted CLAUDE documentation files on a dedicated feature branch and bring supporting guardrail artifacts up to date.

**Work Performed**
- Reviewed `AGENTS.md` guardrails on 2025-10-20 and seeded session `20251020-20251020142213-4fe453`.
- Bootstrapped branch `feature/claude-review`, restored the CLAUDE documentation files, and committed them alongside plan/progress updates.
- Logged top three improvement suggestions from `docs/claude-review.md` into the branch plan for future execution.
- Captured action item to draft a design document consolidating testing strategy and guardrail improvements.
- Authored `docs/claude-review-design.md` covering automated testing design, downstream guidance, and guardrail hardening tasks.
- Expanded downstream guidance to clarify how repo-specific unit/integration suites can hook into guardrail entry points.
- Clarified the design doc to describe the single existing path-based exemption (merge-only) and the motivation for a shared config.
- Refined the timeout/recovery section to reflect the current monitor-loop behaviour (threshold breaches exit) and outline automated follow-up actions.
- Added deliverable manifest gating (applied to every subagent type, including CI audits) so completion depends on verified outputs rather than ad-hoc signals.
- Noted that once automated recovery is trustworthy, we’ll shrink monitor thresholds to catch completions faster, accepting occasional re-check cycles.
- Highlighted that the monitor must manage multiple simultaneous subagents and remain active until all registered runs finish.
- Implemented the first tranche of monitor hardening: per-ID investigations, tmux nudges, manifest-aware JSON telemetry, and continued polling until every subagent completes.
- Smoke-checked the loop via `.agents/bin/agents-monitor-loop.sh --iterations 1`; `pytest` unavailable locally (command missing) so broader tests deferred.
- Tightened default monitor thresholds (interval 30s, log 90s, runtime 240s) to force early-break scenarios during ongoing validation.
- Codified a reusable monitor scenario harness at `tests/guardrails/manual_monitor_scenario.sh` that spins up representative subagent behaviours for manual testing today and future automated coverage.
- Extended the monitor to capture tmux pane snapshots on alerts, giving us transcripts for analysing prompts and improving automated guidance.
- Updated the manual monitor harness to keep its tmux session visible by default (when already inside tmux), making live observation of subagent panes straightforward.
- Adjusted the harness layout to match production UX (main pane on the left, subagents stacked in the right half) so manual runs look exactly like real multi-subagent sessions.

## 2025-10-21 05:01:46 UTC
**Objectives**
- Validate the synthetic subagent monitor harness end-to-end and confirm the monitor loop closes without manual intervention.

**Work Performed**
- Ran `tests/guardrails/manual_monitor_scenario.sh` in synthetic mode; observed the `await-prompt` worker stay blocked after the nudge, leaving the monitor loop waiting indefinitely.
- Confirmed no deliverables were harvested because subagent stubs never exited; no verification/cleanup path exercised.
- Manually killed lingering tmux panes and removed temporary sandboxes/registry entries to restore a clean baseline for the next session.

**Artifacts**
- .parallelus/test-monitor-scenario/ (removed after run)
- docs/agents/subagent-registry.json (synthetic entries pruned)

**Next Actions**
- Modify the synthetic harness so nudged workers log the response and exit, allowing the monitor to finish without manual cleanup.
- Re-run the synthetic scenario to ensure panes auto-close and logs reflect the completed runs before implementing the real Codex harness.

**Artifacts**
- CLAUDE.md
- docs/claude-review.md
- docs/plans/feature-claude-review.md
- docs/progress/feature-claude-review.md

**Next Actions**
- Monitor for requested revisions or follow-up tasks related to CLAUDE documentation.
- Scope automated guardrail tooling tests and define approach.
- Consolidate documentation-only path patterns via shared configuration.
- Plan timeout and recovery enhancements for subagent management workflow.
- Draft guardrail design document covering testing strategy and repo adoption guidance.
- Socialize design document with reviewers and iterate on feedback.
- Monitor the hardened subagent loop in real scenarios and collect follow-up tuning notes (threshold adjustment, additional nudges).
- Re-evaluate thresholds after collecting telemetry to ensure they balance responsiveness with noise.
- Review captured pane snapshots to design smarter, context-aware nudging and potential main-agent handoffs.

## 2025-10-21 05:06:40 UTC
**Objectives**
- Unblock the synthetic monitor scenario so nudged workers log activity and exit cleanly, allowing the monitor loop to finish without manual cleanup.

**Work Performed**
- Reviewed `AGENTS.md` on 2025-10-21 before continuing work and initiated session `20251022-20251021050635-41c436`.
- Confirmed outstanding next steps from the previous run and inspected `tests/guardrails/manual_monitor_scenario.sh` to understand current nudge handling.

**Next Actions**
- Implement logging/exit handling for the synthetic `await-prompt` worker when nudged.
- Re-run the synthetic harness to verify panes close automatically and monitor output reports a successful nudge response.

## 2025-10-21 05:15:20 UTC
**Objectives**
- Ensure the synthetic monitor scenario exits cleanly after a nudge by updating worker behaviour and validating the loop.

**Work Performed**
- Updated `tests/guardrails/manual_monitor_scenario.sh` so the `await-prompt` worker times out safely, logs the received nudge (with timestamp), and exits with success once input arrives; failures now surface if no nudge is delivered.
- Hardened tmux pane management by replacing the negative index lookup with an explicit last-index calculation to avoid bash array errors in detached sessions.
- Attempted to run the synthetic harness headlessly via `tmux new-session` and directly within the current tmux session; both runs showed the worker timing out without detecting the injected nudge, indicating further investigation needed into monitor-to-pane signalling in this environment.

**Next Actions**
- Re-run `tests/guardrails/manual_monitor_scenario.sh` within an interactive tmux workspace to confirm the nudge path triggers log updates and clean exits (the automated headless runs still timed out).
- If the nudge continues to miss, instrument `agents-monitor-loop.sh` to capture the pane targets and confirm `send-keys` succeeds during the synthetic scenario.

## 2025-10-21 05:37:12 UTC
**Objectives**
- Diagnose why tmux panes linger between synthetic monitor runs and ensure cleanup doesn’t disrupt the user’s workspace.

**Work Performed**
- Began another harness run with additional logging; user observed multiple `await-prompt-fail` panes stacking because KEEP_SESSION left panes open and runs overlapped. Stopped the harness and manually closed panes `%112`, `%118`, `%124` to restore a single active pane.
- Captured monitor output (`/private/var/folders/.../tmp.QEbfMr6OaF`) and confirmed nudges still don’t register; registry entries continue to miss the pane IDs despite harness debug logging.

**Next Actions**
- Investigate why `launcher_handle.pane_id` is empty for synthetic entries (verify tmux output handling or string escaping) before rerunning the scenario.
- Add explicit pane cleanup when KEEP_SESSION=0 completes, so repeated runs don’t accumulate stale panes even if the monitor loop exits abnormally.

## 2025-10-21 07:10:37 UTC
**Objectives**
- Stop the runaway harness loops, capture why the monitor still isn’t nudging, and avoid leaving tmux panes behind during debugging.

**Work Performed**
- Added a harness-level timeout (`HARNESS_TIMEOUT`) and optional persistent monitor log path so synthetic runs terminate after a fixed window instead of hanging indefinitely; cleanup now culls panes/sandboxes automatically on timeout.
- Patched `agents-monitor-loop.sh` table parsing to tolerate prefix markers (`!`, `^`, `?`) and keep the handle column intact, then instrumented the alerts path (`MONITOR_DEBUG=1`) to dump the computed alert sets for inspection.
- Ran the harness twice with the new timeout (60 s) and confirmed panes were cleaned up automatically; monitor logs now show alerts being detected but the Python helper still emits `IndexError` traces when handling stale cases, so nudges continue to be skipped.

**Next Actions**
- Fix the `investigate_alerts` Python helper so it handles empty log/runtime fields without raising `IndexError`, then re-run a short synthetic scenario to verify the nudge message appears and the worker logs “received nudge”.
- Once nudges succeed, drop the temporary debug logging and rerun the full expectation checks to ensure the harness exits cleanly without relying on the timeout safeguard.

## 2025-10-21 07:44:00 UTC
**Objectives**
- Stabilise the monitor loop so the synthetic harness exits without human intervention and expectation checks pass.

**Work Performed**
- Patched `agents-monitor-loop.sh` to pass log paths into the Python helper, guard against parsing gaps, join payloads with a non-whitespace separator, and emit debug traces when enabled; the monitor now sends tmux nudges and logs responses without spurious `IndexError`s.
- Improved `tests/guardrails/manual_monitor_scenario.sh` by adding a harness timeout, exposing a persistent monitor log option, adding long-sleep heartbeats, ensuring the `await-prompt` worker records the received nudge, and preventing the fail case from spoofing a positive response; expectation parser now lower-cases events and derives case slugs from run IDs.
- Re-ran the harness (`HARNESS_TIMEOUT=120`) and confirmed it completes automatically with “Monitor scenario expectations satisfied.”; monitor log (`.parallelus/monitor_log.txt`) shows nudges and expected manual attention outcomes, no panes left behind.

**Next Actions**
- Strip the temporary `MONITOR_DEBUG` traces from `agents-monitor-loop.sh` once we finish analysis, and keep the harness timeout configurable (defaulting to 60s).
- Capture these fixes in the branch plan and prep follow-up automation (CI entry point, targeted test) before reverting debug knobs.

## 2025-10-21 20:31:49 UTC
**Objectives**
- Capture design notes for a future `HARNESS_MODE=real` so we have a durable reference before implementing it.

**Work Performed**
- Confirmed via `launch_subagent.sh` that real subagents already stream transcripts through `script -qa` into each sandbox’s `subagent.log`; closing the tmux pane terminates the wrapper script and therefore the Codex process.
- Documented requirements for a real-mode harness: scope limited to purpose-built prompts that mimic synthetic behaviours (sleep, heartbeat, prompt wait); credentials supplied via existing out-of-repo config; results recorded in the branch plan/progress logs pending a formal design addendum.
- Noted that real mode will be opt-in only (no CI invocation) and depends on the existing monitor cleanup paths; logging/telemetry will reuse the current subagent registry plus monitor snapshots.

**Next Actions**
- Flesh out the real-mode harness prompts and operator guidance so the new script can be exercised end-to-end, then capture follow-up automation tasks in the branch plan.

## 2025-10-24 18:17:18 UTC
**Objectives**
- Implement the real-mode monitor harness and wire it into the test wrapper so future runs exercise the production flow.

**Work Performed**
- Authored `.agents/bin/agents-monitor-real.sh`, which launches deterministic real-mode subagents, drives `make monitor_subagents` with 15/30/300 thresholds, inspects deliverables/transcripts, and force-cleans sandboxes. The script requires `HARNESS_MODE=real` and emits per-scenario summaries.
- Replaced `tests/guardrails/manual_monitor_real_scenario.sh` with a thin wrapper that simply invokes the production harness, keeping tests and operators on the same path.

**Next Actions**
- Fill in production-ready prompt language and document the operator workflow (deliverable checks, log review, escalation) before enabling the harness outside ad-hoc runs.

## 2025-10-25 12:29:03 UTC
**Summary**
- summary

**Artifacts**
- TODO: list touched files.

**Next Actions**
- [ ] TODO: follow-up
