# Project Progress

## 2025-10-31

### 17:59:00 UTC — feature/sa-review-subagent-guardrail

**Objectives**
- Prevent rebase hangs by codifying the non-interactive continuation workflow.

**Work Performed**
- Added `.agents/bin/agents-rebase-continue`, a helper that exports `GIT_EDITOR=true` before calling `git rebase --continue`, ensuring the guardrail works in sandboxed shells.
- Documented the helper in `AGENTS.md` so operators reach for it instead of the raw Git command.
- Updated the senior architect manual to reference `.agents/bin/subagent_manager.sh` explicitly, preventing path resolution failures.
- Prevented double-launches by blocking `subagent_manager launch` when a slug has uncleared registry entries or stale tmux panes (now suffix-matched to avoid false positives).
- Clarified the senior architect manual with explicit close-after-harvest guidance, standardized monitoring via `make monitor_subagents`, and restored/enhanced the reviewer prompt's "Subagent Operating Context" guardrails (manual-reading boundaries, fresh-review reminder).

**Next Actions**
- Roll the helper into normal rebase docs and update any manuals referencing the old interactive flow if they appear.

## 2025-10-12

### 10:27:29 UTC — feature-process-review-gate

**Objectives**
- Finalise retrospective workflow and validation ahead of merge.

**Work Performed**
- Re-ran `make ci` (pass) to validate hook/deployment changes after disabling the Swift adapter.
- Persisted senior architect defaults, added read-only retrospective auditor prompt, and enforced audit-before-turn_end with marker validation and updated smoke tests.
- Captured senior architect approval (`docs/reviews/feature-process-review-gate-20251012.md`) and retrospective report aligned to the latest marker.

**Artifacts**
- `AGENTS.md`, `.agents/bin/retro-marker`, `.agents/bin/agents-merge`, `.agents/hooks/pre-merge-commit`, `.agents/config/*.yaml`, `.agents/prompts/agent_roles/agent_auditor.md`, `docs/self-improvement/markers/feature-process-review-gate.json`, `docs/self-improvement/reports/feature-process-review-gate--2025-10-12T10:20:26.400945+00:00.json`.

**Next Actions**
- None pending; branch ready for merge.

### 16:11:06 UTC — feature-publish-repo

**Objectives**
- Prepare the repository for publication by wiring it to the new GitHub remote and pushing the current state.

**Work Performed**
- Reviewed `AGENTS.md` guardrails per session requirements.
- Ran `make bootstrap slug=publish-repo` to create `feature/publish-repo` branch scaffolding.
- Started session `20251012-121110-20251012161110-fdbc55` with prompt “Publishing repo to GitHub”.
- Added `origin` remote pointing to `git@github.com:JeffKandt/parallelus.git`.
- Pushed `main` and `feature/publish-repo` to the new GitHub repository.
- Replaced the top-level `README.md` with a comprehensive public overview of the Parallelus agent process, adoption paths, and workflow.
- Updated `.agents/bin/agents-alert` to allow interactive sessions without TTYs (e.g., tmux) to emit audio while keeping CI/subagents quiet unless overridden.
- Defaulted audible alerts to the macOS `Alex` voice via `AUDIBLE_ALERT_VOICE` so the speech synthesis path works consistently in headless shells.
- Marked subagent launch scripts with `SUBAGENT=1` (and default `CI=true`) so the alert helper can silence them automatically.
- Set `AUDIBLE_ALERT_REQUIRE_TTY=0` default in `.agents/agentrc` to align with the new behaviour.
- Expanded the README prerequisites and workflow notes to cover tmux requirements, status-bar config, Codex shell helpers, and the deploy script for reusable rollouts.
- Added Codex profile support to subagent launches (including the `--profile` flag, registry tracking, and prompt visibility) for hosted models like `gpt-oss`.
- Updated materials (README and `docs/agents/subagent-session-orchestration.md`) so humans see the new profile/tmux behaviour without digging into the code.
- Moved senior architect and auditor role configuration into YAML front matter within their prompts, removed the legacy `.agents/config/*.yaml`, and wired `subagent_manager` to parse/validate overrides (model, sandbox, approval, profile, allowed writes).
- Added the `--role` launch option plus prompt override summaries so operators know which runtime adjustments are in effect.
- Plumbed `config_overrides` through front matter so roles can inject Codex `-c key=value` settings (e.g., reasoning effort) without relying on named profiles and ensured dangerous sandbox flags are only skipped when a sandbox override is supplied.
- Renamed the retrospective role to `continuous_improvement_auditor`, introduced guardrail toggles/role selectors (`REQUIRE_AGENT_CI_AUDITS`, `AGENT_CI_AGENT_ROLE`, `REQUIRE_CODE_REVIEWS`, `CODE_REVIEW_AGENT_ROLE`), and wired `make turn_end` to require the configured audit report.

**Artifacts**
- docs/plans/feature-publish-repo.md
- docs/progress/feature-publish-repo.md
- README.md
- .agents/bin/agents-alert
- .agents/bin/launch_subagent.sh
- .agents/agentrc
- .agents/bin/subagent_manager.sh
- docs/agents/subagent-session-orchestration.md

**Next Actions**
- Verify the GitHub repo lists expected branches and files.
- Coordinate next feature work or documentation updates as requested.

### 19:32:51 UTC — feature-publish-repo

**Summary**
- Removed execution setup reminder blocks from the role prompts and captured reasoning-effort overrides directly in YAML front matter.

**Artifacts**
- .agents/prompts/agent_roles/senior_architect.md
- .agents/prompts/agent_roles/continuous_improvement_auditor.md

**Next Actions**
- None (informational cleanup only).

### 19:50:02 UTC — feature-publish-repo

**Summary**
- Exercised the new retrospective guardrail to confirm `make turn_end` fails without a report.

**Artifacts**
- docs/self-improvement/markers/feature-publish-repo.json
- docs/self-improvement/reports/feature-publish-repo--2025-10-12T16:11:06+00:00.json

**Next Actions**
- None pending; guardrail validated.

### 23:36:44 UTC — feature-publish-repo

**Objectives**
- Ensure `make read_bootstrap` applies the Parallelus tmux overlay when Codex runs inside a clean-environment tmux session.

**Work Planned**
- Update the read bootstrap helper to honor `PARALLELUS_TMUX_SOCKET`.
- Confirm whether other tmux-touching scripts need adjustments.

**Work Performed**
- Taught `.agents/make/agents.mk` to pass `-S $PARALLELUS_TMUX_SOCKET` to tmux commands and refresh the overlay on Codex start.
- Propagated the socket-aware tmux lookup to subagent tooling (`launch_subagent.sh`, `subagent_manager.sh`, `resume_in_tmux.sh`, `get_current_session_id.sh`) so they export `TMUX` when the clean Codex environment lacks it.
- Updated `agents-session-start` to emit the tmux exports via the provided socket for future session shells.
- Verified the behaviour by standing up a temporary tmux server, running `PARALLELUS_TMUX_SOCKET=... make read_bootstrap`, and inspecting the status configuration applied to that server.

**Validation**
- `PARALLELUS_TMUX_SOCKET=/tmp/parallelus-test.sock make read_bootstrap`
- `tmux -S /tmp/parallelus-test.sock show-option -g status-left`

**Next Actions**
- Monitor other tmux-integrated scripts for socket-awareness needs as they come up.

### 23:49:32 UTC — feature-publish-repo

**Objectives**
- Tweak the tmux overlay layout to show the branch next to the session name and move phase/window indicators to the right status segment.

**Work Performed**
- Updated `.agents/tmux/parallelus-status.tmux` so `status-left` renders the session name plus current branch, and `status-right` now includes phase, worktree, git state, window index, and heartbeat.
- Revalidated the overlay by loading it into a temporary tmux server with `PARALLELUS_TMUX_SOCKET=/tmp/parallelus-test.sock make read_bootstrap` and inspecting the resulting status strings.

**Validation**
- `tmux -S /tmp/parallelus-test.sock show-option -g status-left`
- `tmux -S /tmp/parallelus-test.sock show-option -g status-right`

**Next Actions**
- Confirm the updated layout meets operator expectations during live Codex runs.

### 23:56:42 UTC — feature-publish-repo

**Objectives**
- Clarify the base worktree indicator and fine-tune status ordering per operator feedback.

**Work Performed**
- Changed `.agents/bin/subagent_prompt_phase.py` to emit `•` when running in the primary checkout so it no longer collides with branch names.
- Restructured the right-hand status string to lead with the active window id/title and keep phase, worktree marker, git state, and heartbeat separated by consistent dividers.
- Reloaded the tmux overlay on the active Codex socket to apply the new layout.

**Next Actions**
- Observe the new indicator in daily workflows and adjust the symbol if further clarity is needed.


## 2025-10-13

### 00:52:09 UTC — feature-publish-repo

**Objectives**
- Kick off the Continuous Improvement audit for the current branch work.

**Work Performed**
- Launched `subagent_manager` with the CI auditor role; the generated scope reused the default bootstrap checklist, so the sandbox failed immediately on dirty-tree checks.
- Stopped the stray tmux pane (`tmux kill-pane -t %1`), forced cleanup of registry entry `20251013-004814-ci-audit`, and removed the temporary sandbox directory.

**Next Actions**
- Prepare a minimal CI-audit scope/prompt and re-run the auditor so the JSON report reflects today's changes before the next `make turn_end`.

### 01:08:22 UTC — feature-publish-repo

**Objectives**
- Deliver a successful Continuous Improvement audit run with a scope tailored to the current branch state.

**Work Performed**
- Added `docs/agents/templates/ci_audit_scope.md` as a reusable scope and enhanced `subagent_manager.sh` to normalize role prompts, pass the parent branch into CI-auditor instructions, and avoid bootstrap steps for that role.
- Updated the tmux prompt generator and related helpers to respect `PARALLELUS_TMUX_SOCKET`, then launched `subagent_manager.sh launch --type throwaway --slug ci-audit --scope ... --role continuous_improvement_auditor.md` via tmux.
- Captured the auditor's JSON findings and wrote them to `docs/self-improvement/reports/feature-publish-repo--2025-10-12T16:11:06+00:00.json`, then cleaned the sandbox registry entry and deleted `.parallelus/` artifacts.
- Re-read `docs/agents/subagent-session-orchestration.md` and recorded this acknowledgement here so future subagent launches meet the guardrail expectation.

**Validation**
- Verified the parsed JSON report contents before saving and confirmed `subagent_manager.sh status` reports no running entries.

**Next Actions**
- Address the auditor's follow-up items as we continue refining the CI audit tooling.

### 02:01:29 UTC — feature-publish-repo

**Objectives**
- Re-run the Continuous Improvement audit with the updated scope and capture the full transcript.

**Work Performed**
- Relaunched `subagent_manager.sh` with the CI auditor role and the new scope template; let the subagent complete without manual prompts.
- Captured the auditor pane to `docs/logs/ci-audit-20251013T015421.txt`, parsed the JSON output, and updated `docs/self-improvement/reports/feature-publish-repo--2025-10-12T16:11:06+00:00.json`.
- Cleaned the registry entry `20251013-015421-ci-audit` and deleted the throwaway sandbox directory.
- Documented the operator preference to store future subagent transcripts under `docs/logs/` and avoid manual prompts unless coordinated.
- Recreated the Python virtual environment, added `black`, `ruff`, and `pytest` to `requirements.txt`, and ran `make ci` to confirm lint and test targets now pass locally.
- Recorded the directive to archive the full main-agent console transcript for every session and fold transcript retrospectives into the turn-end checklist.

**Validation**
- `cat docs/logs/ci-audit-20251013T015421.txt`
- `cat docs/self-improvement/reports/feature-publish-repo--2025-10-12T16:11:06+00:00.json`
- `make ci`

### 03:53:50 UTC — feature-review-feature-publish-repo

**Objectives**
- Review guardrails, build an actionable plan, and diagnose the tmux overlay prompt injection.

**Work Performed**
- Read `AGENTS.md` as required at session start.
- Ran `make read_bootstrap` to confirm repo state (remote-connected, branch `feature/review-feature-publish-repo`).
- Attempted to start a new session with `SESSION_PROMPT="Investigate tmux overlay prompt injection" make start_session`; hit `/Users/jeff/Code/parallelus/.agents/bin/agents-session-start: line 163: tmux_args[@]: unbound variable`.
- Updated branch plan and progress notebooks with current objectives and troubleshooting steps.
- Patched `.agents/bin/agents-session-start` and `.agents/make/agents.mk` to guard tmux argument expansion and avoid prompting the terminal for device attributes.
- Re-ran `make read_bootstrap` and `SESSION_PROMPT="Investigate tmux overlay prompt injection" make start_session` successfully; new session `sessions/20251017-20251013040143-627b29` created without prompt leakage.

**Artifacts**
- docs/plans/feature-review-feature-publish-repo.md
- docs/progress/feature-review-feature-publish-repo.md

**Next Actions**
- Confirm the tmux overlay prompt leak no longer reproduces in an iTerm-driven session.
- Document the root cause and remediation steps for maintainers.
- Review whether additional tmux helpers need regression tests for control-mode fallbacks.

### 05:10:44 UTC — feature-review-feature-publish-repo

**Objectives**
- Address the blocking review findings for the feature/publish-repo guardrails.

**Work Performed**
- Re-read `AGENTS.md` to confirm session guardrails and reopened the branch plan/progress notebooks.
- Updated the branch plan to prioritise the subagent env export fix and retrospective verifier slug handling.
- Captured the reviewer's outstanding findings to frame the remediation scope.

**Next Actions**
- Patch `role_config_to_env` to stop JSON-wrapping scalar role values and verify Codex respects the exports.
- Normalise branch names in `verify-retrospective` so missing markers for slash branches block `make turn_end`.
- Summarise the remediation and verification outcomes for maintainers.

### 05:16:19 UTC — feature-review-feature-publish-repo

**Objectives**
- Validate the role front-matter exports by running the CI agent audit subagent.

**Work Performed**
- Reviewed `docs/agents/subagent-session-orchestration.md` in full per the subagent launch gate.
- Confirmed the branch plan still reflects the outstanding remediation tasks.

**Next Actions**
- Launch the CI agent audit via the updated subagent tooling and confirm it runs without quoted scalar exports.
- Capture audit outcomes and incorporate any follow-up tasks into the plan.

### 05:19:01 UTC — feature-review-feature-publish-repo

**Objectives**
- Validate that the CI auditor role launches with correctly quoted env overrides.

**Work Performed**
- Fired `.agents/bin/agents-alert` before kicking off the audit helper.
- Ran `.agents/bin/subagent_manager.sh launch --type throwaway --slug ci-audit --scope docs/agents/templates/ci_audit_scope.md --role continuous_improvement_auditor.md`; inspected the generated `SUBAGENT_PROMPT.txt` and sandbox log to confirm `Codex profile: default (danger-full-access)` and the additional constraints string render without extra JSON quoting.
- Cleaned the throwaway sandbox via `subagent_manager.sh cleanup --id 20251013-051736-ci-audit --force` once verification was complete.

**Next Actions**
- Capture a brief remediation summary for maintainers (plan + docs update).
- Prepare to launch the senior architect review once the summary is ready.

### 05:26:45 UTC — feature-review-feature-publish-repo

**Objectives**
- Let the CI auditor finish and archive its findings without interrupting the sandbox.

**Work Performed**
- Relaunched `.agents/bin/subagent_manager.sh launch --type throwaway --slug ci-audit --scope docs/agents/templates/ci_audit_scope.md --role continuous_improvement_auditor.md` and left both tmux panes active until completion.
- Captured the transcript to `docs/logs/ci-audit-20251013T052311.txt` and parsed the JSON payload into `docs/self-improvement/reports/feature-review-feature-publish-repo--2025-10-13T05:23:00Z.json`.
- Cleaned the registry entry with `subagent_manager.sh cleanup --id 20251013-052311-ci-audit --force` once the output was saved.

**Next Actions**
- Fold the auditor follow-ups into the branch plan and remediation summary.
- Close the extra tmux pane left from the failed attempt to keep the workspace tidy.

### 05:38:50 UTC — feature-review-feature-publish-repo

**Objectives**
- Plan the guardrail updates so subagent monitoring and cleanup become policy.

**Work Performed**
- Updated the branch plan to include the tmux-safe wrapper work, monitor-loop enforcement, and documentation tasks.

**Next Actions**
- Implement the wrapper/cleanup changes in the tooling.
- Capture the new workflow guidance in the manual and notebooks once the code changes land.

### 05:42:48 UTC — feature-review-feature-publish-repo

**Objectives**
- Bake the tmux socket guard and monitor-loop requirements into the tooling.

**Work Performed**
- Added `.agents/bin/tmux-safe` and updated `subagent_manager.sh` to route every tmux call through it, including launch hints and cleanup teardown.
- Hardened `subagent_manager.sh cleanup` to refuse live sessions unless `--force` is passed and surfaced `.agents/bin/agents-monitor-loop.sh --id <entry>` as the canonical way to decide when cleanup is safe.
- Logged the new guidance in `docs/agents/subagent-session-orchestration.md`.

**Next Actions**
- Incorporate the CI auditor follow-ups into the remediation summary and plan.
- Trigger the senior architect review once the summary is ready.

### 05:45:27 UTC — feature-review-feature-publish-repo

**Objectives**
- Summarise the remediation work for maintainers and capture CI auditor follow-ups.

**Work Performed**
- Drafted a maintainer-facing summary covering the scalar export fix, retrospective verifier slug guard, CI auditor validation, and the new monitor-loop/cleanup guardrails now logged in the manual.
- Listed the CI auditor follow-ups that still need resolution (missing marker for `feature/publish-repo`, ensuring audits run on the feature branch instead of `main`, and rehydrating that branch’s plan/progress notebooks).

**Next Actions**
- Decide whether to restore the `feature/publish-repo` marker/notebooks within this branch or delegate to the owning feature branch.
- Prep the senior architect review package once the above decision is recorded.

### 05:57:55 UTC — feature-review-feature-publish-repo

**Objectives**
- Complete the senior architect review to validate the role front-matter flow.

**Work Performed**
- Launched `subagent_manager.sh` with `--slug senior-review --role senior_architect.md` and monitored it via `agents-monitor-loop.sh --id 20251013-054559-senior-review`.
- After the monitor loop flagged a stale heartbeat, inspected the tmux pane, captured the final findings, sent `Ctrl+C` to terminate the idle Codex prompt, and only then forced cleanup.
- Archived the subagent log to `docs/logs/senior-review-20251013T054559.txt` and synced the reviewer’s findings into `docs/reviews/feature-publish-repo-2025-10-13.md`.

**Review Outcome**
- `requirements.txt` needs the Python toolchain (`ruff`, `black`, `pytest`) so the adapter-driven `make ci` succeeds.
- `tracked_env_vars` in `subagent_manager.sh` must also restore `SUBAGENT_CODEX_CONFIG_OVERRIDES` to prevent role bleed-through.
- The tmux heartbeat overlay should surface the maximum log age, not the minimum, to expose stalled subagents.

**Next Actions**
- Prioritise fixes for the three review findings (either within this branch or delegated with a recorded plan).
- Re-run targeted checks (CI + monitor overlay) once fixes land, then loop back for review sign-off.
- Update the guardrails to mandate durable, versioned mitigations (no branch-only fixes) so the monitor-loop expectation is baked into the repo.

### 06:24:31 UTC — feature-review-feature-publish-repo

**Objectives**
- Knock down the senior architect review blockers.

**Work Performed**
- Added `SUBAGENT_CODEX_CONFIG_OVERRIDES` to the tracked/restore set in `.agents/bin/subagent_manager.sh` so role overrides no longer bleed into subsequent launches.
- Updated `.agents/bin/subagent_prompt_phase.py` to report the maximum log age across running subagents, restoring the intended stale-heartbeat signal.

**Next Actions**
- Rerun the relevant validation (e.g., `make monitor_subagents` during the next subagent launch) to demonstrate the heartbeat fix.
- Confirm the Python toolchain dependency change remains intact and ready for CI rerun.

### 07:03:00 UTC — feature-review-feature-publish-repo

**Objectives**
- Stabilise throwaway sandbox creation and capture remaining TODOs.

**Work Performed**
- Switched throwaway sandbox creation to `git clone` the current commit instead of invoking `.agents/bin/deploy_agents_process.sh`, avoiding implicit `make bootstrap` calls that clobbered the main repo.
- Logged the repo-level TODOs (refresh `docs/agents/project/`, lock down subagent allowed writes) in `docs/PLAN.md`.

**Next Actions**
- Rerun the senior architect review with `make monitor_subagents` now that sandbox creation is isolated.
- Follow through on the plan-level TODOs after review sign-off.

### 07:43:30 UTC — feature-review-feature-publish-repo

**Objectives**
- Re-run the senior architect review on the committed branch.

**Work Performed**
- Launched `subagent_manager.sh launch --type throwaway --slug senior-review --scope docs/agents/templates/senior_architect_scope.md --role senior_architect.md` against commit `feba011`; monitored it via `make monitor_subagents ARGS="--id 20251013-072554-senior-review …"` until the log heartbeat stalled at the 3-minute mark.
- Captured the subagent’s analysis up to the stall (log confirms review drafting started) and force-cleaned the sandbox to avoid leaving a running entry.
- Restarted the review (`id=20251013-074311-senior-review`) but paused work here so the next session can continue with a fresh monitor loop.

**Next Actions**
- Resume the latest senior-review run (`make monitor_subagents ARGS="--id 20251013-074311-senior-review"`) and let it finish; capture the generated review file in the main repo.
- If the subagent still stalls, investigate the missing `python3` tooling inside the sandbox before relaunching.


## 2025-10-15

### 21:41:28 UTC — feature-review-feature-publish-repo

**Objectives**
- Reconfirm guardrails and capture the current branch/subagent context.

**Work Performed**
- Reviewed the Parallelus Agent Core Guardrails and noted the acknowledgement here before continuing.
- Ran `make read_bootstrap` to snapshot repo state ahead of investigating the branch divergence.

**Next Actions**
- Clean up the leftover `senior-review-kE0C7y` subagent sandbox and remove the `.parallelus` artefacts before committing.
- Ensure the branch plan reflects the latest remediation/status updates once cleanup is complete.


## 2025-10-16

### 04:56:39 UTC — feature-review-feature-publish-repo

**Objectives**
- Automate collection of senior-review artifacts and surface deliverable status in the tooling.

**Work Performed**
- Extended `subagent_manager.sh launch` with `--deliverable` support; registry entries now capture expected artifacts and expose a `Deliverables` status column.
- Added `subagent_manager.sh harvest` to copy sandbox outputs into the repo and update registry metadata.
- Taught `agents-monitor-loop.sh` to flag entries with pending deliverables and display the harvest command on exit.
- Updated the subagent orchestration manual to document the new flow and inserted follow-up actions into the branch plan.

**Next Actions**
- Test the deliverable harvest workflow on the next senior-review run and capture the resulting review/log files via the new helper.
- Continue working through remaining review follow-ups (CI auditor fixes, documentation refresh) before reattempting the senior architect review.

### 05:49:20 UTC — feature-review-feature-publish-repo

**Objectives**
- Prep for another senior architect review run after updating the orchestration flow.

**Work Performed**
- Re-read the updated `docs/agents/subagent-session-orchestration.md` to confirm the log-tail workflow and captured this acknowledgement prior to launching/monitoring new subagents.

**Next Actions**
- Launch the senior-review subagent with explicit deliverables and monitor it through completion.

### 06:21:11 UTC — feature-review-feature-publish-repo

**Objectives**
- Diagnose the stalled monitor loop after launching the senior-review subagent.

**Work Performed**
- Reviewed the subagent log snippet showing the expected write-permission warning (review-only sandbox).
- Captured the registry state (`status=running`, deliverables pending) after the subagent completed, confirming the monitor loop never triggered the heartbeat threshold.
- Identified the regression in `agents-monitor-loop.sh`: the new Deliverables column shifted field positions, so the AWK parser no longer read runtime/log columns, preventing the 10-minute timeout from firing.
- Patched the monitor script to reference the updated column layout and avoid false negatives.
- Logged follow-up TODOs in the branch plan, including adding a completion signal for the monitor.
- Verified the fix by rerunning the loop (`make monitor_subagents ARGS="--id …"`), which now flags the heartbeat breach immediately.
- Harvested only the review artifact (after briefly copying the transcript to satisfy the stale `docs/logs` deliverable) and removed the accidental `docs/docs/` duplication; noted the plan update to drop the log deliverable going forward.

**Next Actions**
- Re-run the monitor loop with the fixed script to verify it now exits when log age exceeds the threshold (keeping the existing subagent pane open for analysis).
- Implement and test a sentinel-based completion signal so future loops can detect finished runs without relying solely on log age.

### 06:40:24 UTC — feature-review-feature-publish-repo

**Objectives**
- Address the senior-review findings (PyYAML dependency, override quoting/restoration) and tidy the harvested artifacts.

**Work Performed**
- Closed the idle senior-review tmux pane, removed the mistaken `docs/docs` duplication, and pruned the temporary log copy so only the review artifact remains.
- Logged plan updates to drop the extra `docs/logs` deliverable and queued TODOs for the completion sentinel.

**Next Actions**
- Add `PyYAML` to the managed dependencies and verify role parsing works on a clean environment.
- Fix scalar quoting/override restoration in `subagent_manager.sh`, then run smoke launches to confirm no bleed-through.

### 06:47:33 UTC — feature-review-feature-publish-repo

**Objectives**
- Relaunch the senior architect review with the monitoring fix and reduced deliverables.

**Work Performed**
- Confirmed `PyYAML` imports succeed after the dependency pin so role prompts load.
- Prepared to relaunch the review with only the `docs/reviews/` deliverable.

**Next Actions**
- Fire the senior-review subagent and monitor via `make monitor_subagents` to validate the heartbeat exit/harvest flow end-to-end.

### 07:06:37 UTC — feature-review-feature-publish-repo

**Objectives**
- Validate the senior-review workflow end-to-end with the monitor fix in place.

**Work Performed**
- Launched the senior-review subagent (`20251016-064757-senior-review`) with only the `docs/reviews/` deliverable, monitored it, and confirmed the loop exits once the heartbeat exceeds the 3-minute threshold.
- Harvested the review artifact, updated the registry entry, and cleaned the sandbox after ensuring no live pane remained.

**Next Actions**
- Fold the new review notes into the remediation plan and proceed with addressing the remaining TODOs before the next rerun.

### 07:15:22 UTC — feature-review-feature-publish-repo

**Objectives**
- Prevent future senior-review launches on dirty worktrees and refresh the manual.

**Work Performed**
- Added a clean-worktree guard in `subagent_manager.sh` that blocks senior architect launches when local edits exist, ensuring reviews always run against committed state.
- Documented the requirement in the orchestration manual so operators know to commit or stash before requesting review.

**Next Actions**
- Stage and commit the PyYAML/override fixes so the next senior-review run sees the updated environment.


## 2025-10-17

### 02:45:29 UTC — feature/backlog-improvements

**Objectives**
- Align user- and agent-facing documentation with the clarified partnership philosophy and reinforce tmux setup guidance.

**Work Performed**
- Rewrote the human-facing README to emphasise outcome-based dialogue and examples for parallel subagent work.
- Updated guardrail manuals (`AGENTS.md`, git workflow, subagent orchestration) to remind the agent to communicate in outcomes and absorb project-specific overrides from `.agents/custom/`.
- Replaced `docs/agents/project/` with Parallelus-focused domain, structure, and continuous-improvement notes plus guidance for downstream adopters.
- Authored a tmux setup manual describing the required compiled build, per-repo sockets, and use of `.agents/bin/tmux-safe`; added a sidecar area for host project customisations.

**Next Actions**
- Share the updated docs with maintainers and gather feedback on the folding workflow and queue improvements.
- Monitor tmux helper behaviour in daily use and refine the codex launcher recommendations as needed.

## 2025-10-28

### 00:19:00 UTC — feature/claude-review

**Objectives**
- Secure senior architect approval for the monitor-loop regression fix and document the run for archival.

**Work Performed**
- Launched subagent `20251028-001950-senior-review` against commit `d886dfa18cddd0863706087a245eb017889f8507`, monitored the session, and harvested the approval deliverable once the report was committed.
- Registered the run in `docs/agents/subagent-registry.json`, copied the deliverable into `docs/guardrails/runs/20251028-001950-senior-review/`, and noted the missing transcript due to cleanup timing.
- Updated branch notebooks and plan to track the follow-up on automating log harvest ahead of sandbox removal.

**Next Actions**
- Fold remaining notebooks, implement automated log harvesting before cleanup, and proceed with merging the fixes into `main`.

### 2025-10-23 — codex/investigate-context-cloning-for-subagents

**Objectives**
- Capture design and tooling for "context capsules" that let the main agent hand rich session context to subagents.

**Work Performed**
- Documented capsule design (`docs/agents/prototypes/context-capsule.md`) and prompt template (`docs/agents/templates/context_capsule_prompt.md`).
- Added helper scripts (`scripts/capsule_prompt.py`, `scripts/remember_later.py`) plus a notes inbox (`docs/agents/capsules/remember-later.md`).
- Logged operator workflows and TODOs in the codex branch plan/progress notebooks (now folded into canonical docs).

**Next Actions**
- Pilot the capsule workflow alongside standard progress logging, socialise prompt usage, and scope implementation spikes for automation.
