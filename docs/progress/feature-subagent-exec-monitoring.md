# Branch Progress — feature/subagent-exec-monitoring

## 2026-01-23 05:01:26 UTC
**Objectives**
- improve exec-mode monitoring output and cleanup reliability

**Work Performed**
- investigated why some subagent panes looked like the TUI and why a pane was left open
- confirmed the leftover pane was a tmux pane titled `20260123-044827-senior-review` and closed it
- started a focused branch to improve exec stream visibility and tmux cleanup

**Artifacts**
- `.agents/bin/codex_exec_stream_filter.py`
- `.agents/bin/subagent_manager.sh`
- `docs/plans/feature-subagent-exec-monitoring.md`
- `docs/progress/feature-subagent-exec-monitoring.md`

**Next Actions**
- update exec stream summaries to include command + exit code
- add a cleanup fallback that kills tmux panes by title when registry metadata is missing

## 2026-01-23 05:06:00 UTC
**Objectives**
- validate the exec-mode monitoring output on a real senior architect review run

**Work Performed**
- re-read `docs/agents/subagent-session-orchestration.md` (subagent gate)
- re-read `docs/agents/manuals/senior-architect.md` (review gate)

**Next Actions**
- launch a senior architect review subagent and confirm exec output and cleanup behavior

## 2026-01-23 05:19:53 UTC
**Objectives**
- validate exec-mode output and cleanup end-to-end

**Work Performed**
- identified the root cause of “TUI launches”: `launch_subagent.sh` wrote literal `\n` into exports and the generated inner script called `is_enabled` without defining it, so exec-mode was never entered
- fixed `launch_subagent.sh` to emit real newlines for exec exports and define `is_enabled`/`is_falsey` inside the generated inner script
- reran a senior architect review subagent and confirmed the pane shows exec-mode summaries with command/exit/output hints
- confirmed cleanup closes the tmux pane after harvest/cleanup

## 2026-01-23 05:29:01 UTC
**Objectives**
- make exec-mode subagent pane output feel closer to the TUI (human readable tool calls + progress)

**Work Performed**
- reviewed Parallelus agent guardrails in `AGENTS.md`
- reviewed `.agents/custom/README.md`
- ran `make read_bootstrap` and confirmed we are on `feature/subagent-exec-monitoring`
- started session `20251045-20260123052845-ce41ec`

**Next Actions**
- update `.agents/bin/codex_exec_stream_filter.py` to render exec events in a TUI-like format (without printing hidden reasoning text)
- validate via a senior architect review subagent run and confirm tmux panes clean up

## 2026-01-23 05:33:02 UTC
**Objectives**
- validate the new exec-mode rendering on a real subagent run

**Work Performed**
- re-read `docs/agents/subagent-session-orchestration.md` (subagent gate)
- re-read `docs/agents/manuals/senior-architect.md` (review gate)

## 2026-01-23 05:35:16 UTC
**Objectives**
- make exec-mode command summaries match TUI readability

**Work Performed**
- improved the exec event renderer to unwrap `/bin/zsh -lc '…'` and `/bin/bash -lc '…'` wrappers (including multiline commands) into a single-line summary suitable for tmux capture-pane

## 2026-01-23 05:39:12 UTC
**Objectives**
- validate the exec-mode renderer in a real tmux subagent pane

**Work Performed**
- launched a senior architect review subagent (`20260123-053350-senior-review`) and verified the pane output is now capture-pane-friendly with readable `Run …` / `Ran … (exit …)` lines
- harvested `docs/reviews/feature-subagent-exec-monitoring-2026-01-23.md` and forced cleanup after confirming the tmux pane had exited

## 2026-01-23 05:54:29 UTC
**Objectives**
- add a mid-flight checkpoint log so monitoring sees “why/what/next” during exec runs

**Work Performed**
- updated subagent prompt generation to require checkpoint updates in `subagent.progress.md`
- updated `subagent_tail.sh` to prefer `subagent.progress.md` before event streams
- updated `subagent_manager.sh status` to treat `subagent.progress.md` mtime as a heartbeat source
- exported `SUBAGENT_PROGRESS_PATH` inside the sandbox runner and ensured the file exists
- documented the new checkpoint artifact in `docs/agents/subagent-session-orchestration.md` and the scope template

## 2026-01-23 06:01:16 UTC
**Objectives**
- validate checkpoint-based monitoring and fix any launch/monitor regressions

**Work Performed**
- fixed an indentation regression in the `subagent_manager.sh` registry payload generator (blocked launches)
- ran a throwaway `checkpoint-demo` subagent to confirm:
  - `SUBAGENT_PROGRESS_PATH` is set inside the sandbox
  - `subagent.progress.md` is created and tail-able
  - `subagent_manager.sh status` prefers checkpoint timestamps for log age
  - `subagent_tail.sh` prefers last message, then checkpoints, then event streams

## 2026-01-27 17:32:51 UTC
**Objectives**
- assess deploy/upgrade safety and artifact layout options

**Work Performed**
- reviewed deployment docs/script, subagent orchestration manual, and current repo artifact layout
- identified deployment parity gaps (canonical plan/progress + self-improvement scaffolding) and upgrade risks (AGENTS.md + Makefile overlays)
- recorded proposed direction for safer upgrades (split upstream vs project-specific guardrails) and layout options in `docs/deployment-upgrade-and-layout-notes.md`

**Artifacts**
- `docs/deployment-upgrade-and-layout-notes.md`
- `docs/plans/README.md`
- `docs/progress/README.md`
- `docs/plans/feature-subagent-exec-monitoring.md`

**Next Actions**
- [ ] decide on a safe AGENTS.md customization/upgrades policy (project overlay file vs inline edits)
- [ ] update deploy script/docs to scaffold canonical `docs/PLAN.md`, `docs/PROGRESS.md`, and `docs/self-improvement/` on initial deployment

## 2026-01-27 17:34:25 UTC
**Objectives**
- confirm guardrails before deployment work

**Work Performed**
- reviewed `AGENTS.md` and `.agents/custom/README.md` prior to editing process artifacts

## 2026-01-27 17:38:12 UTC
**Objectives**
- close deployment parity gaps and harden overlay safety

**Work Performed**
- updated deploy script to scaffold canonical `docs/PLAN.md`, `docs/PROGRESS.md`, and `docs/self-improvement/` plus `.gitkeep` files
- added overlay backups for in-place edits (Makefile and `.gitignore`) and expanded overlay collision warnings
- added optional helper-script copy when a target Makefile references `remember_later` or `capsule_prompt`
- refreshed deployment documentation to reflect the new scaffolding and helper-script behavior

**Artifacts**
- `.agents/bin/deploy_agents_process.sh`
- `docs/agents/deployment.md`
- `docs/deployment-upgrade-and-layout-notes.md`

**Next Actions**
- [ ] decide on a safe AGENTS.md customization/upgrades policy (project overlay file vs inline edits)

## 2026-01-27 17:41:30 UTC
**Objectives**
- implement AGENTS.md split (upstream vs project-specific)

**Work Performed**
- updated `AGENTS.md` to reference a project-specific guardrails file
- added `PROJECT_AGENTS.md` as the recommended home for project-specific policies

**Artifacts**
- `AGENTS.md`
- `PROJECT_AGENTS.md`

## 2026-01-27 17:43:20 UTC
**Objectives**
- require project guardrails review at session start

**Work Performed**
- updated `AGENTS.md` to mandate reading `PROJECT_AGENTS.md` (or `AGENTS.project.md`) when present

**Artifacts**
- `AGENTS.md`

## 2026-01-27 17:54:10 UTC
**Objectives**
- move retrospective audit to merge time and capture failed tool calls

**Work Performed**
- removed turn-end audit requirement and added merge-time failures collection (`make collect_failures`)
- added failures summary generator and merge guardrails requiring it before merge
- updated auditor prompt, scope template, and core docs to review failures and run audits before merge
- scaffolded failures directory during deployment

**Artifacts**
- `.agents/bin/collect_failures.py`
- `.agents/make/agents.mk`
- `.agents/bin/agents-merge`
- `.agents/bin/retro-marker`
- `.agents/agentrc`
- `.agents/prompts/agent_roles/continuous_improvement_auditor.md`
- `.agents/bin/subagent_manager.sh`
- `docs/agents/templates/ci_audit_scope.md`
- `docs/agents/core.md`
- `docs/agents/git-workflow.md`
- `docs/agents/subagent-session-orchestration.md`
- `docs/self-improvement/README.md`
- `docs/agents/deployment.md`
- `docs/deployment-upgrade-and-layout-notes.md`

## 2026-01-27 18:01:15 UTC
**Objectives**
- finish merge-time audit rollout and scaffolds

**Work Performed**
- added failures scaffold (`docs/self-improvement/failures/.gitkeep`) and updated structure/CI guidance
- updated subagent scope templating to include failures summary path
- updated continuous improvement notes to emphasize failures capture

**Artifacts**
- `docs/self-improvement/failures/.gitkeep`
- `docs/agents/project/structure.md`
- `docs/agents/project/continuous_improvement.md`
- `.agents/bin/subagent_manager.sh`

## 2026-01-27 18:04:30 UTC
**Objectives**
- refresh branch plan after audit workflow changes

**Work Performed**
- updated branch plan to reflect merge-time audit validation steps

**Artifacts**
- `docs/plans/feature-subagent-exec-monitoring.md`

## 2026-01-27 18:08:05 UTC
**Objectives**
- enforce CI audit before senior architect review

**Work Performed**
- added merge guardrail to require audit report + failures summary in the senior review commit
- updated process docs to require audit before the senior review

**Artifacts**
- `.agents/bin/agents-merge`
- `AGENTS.md`
- `docs/agents/git-workflow.md`
- `docs/agents/subagent-session-orchestration.md`

## 2026-01-27 18:12:20 UTC
**Objectives**
- block senior review when audit is missing

**Work Performed**
- added pre-launch guard in subagent manager to require failures summary + audit report
- documented the new guard in subagent orchestration manual

**Artifacts**
- `.agents/bin/subagent_manager.sh`
- `docs/agents/subagent-session-orchestration.md`

## 2026-01-27 18:20:30 UTC
**Objectives**
- make session logs mandatory

**Work Performed**
- added auto-logging setup to `make start_session` and enforced non-empty session logs at `make turn_end`
- documented mandatory session logging in core guardrails and Codex integration notes

**Artifacts**
- `.agents/bin/agents-session-start`
- `.agents/bin/agents-turn-end`
- `.agents/agentrc`
- `AGENTS.md`
- `docs/agents/core.md`
- `docs/agents/integrations/codex.md`
- `docs/agents/project/structure.md`

## 2026-01-27 18:26:15 UTC
**Objectives**
- enforce `make start_session` before turn_end

**Work Performed**
- added session-required markers on `make bootstrap` and cleared them on `make start_session`
- blocked `make turn_end` if the session marker is still present
- documented the enforcement in core workflow docs

**Artifacts**
- `.agents/bin/agents-ensure-feature`
- `.agents/bin/agents-session-start`
- `.agents/bin/agents-turn-end`
- `docs/agents/core.md`
- `docs/agents/git-workflow.md`

## 2026-01-27 18:34:40 UTC
**Objectives**
- require session start via eval and run read_bootstrap automatically

**Work Performed**
- changed `make start_session` to output shell exports (for `eval` usage)
- made session start print `make read_bootstrap` so recon runs after logging is enabled
- updated core docs and manuals to instruct `eval "$(make start_session)"` as the session entrypoint

**Artifacts**
- `.agents/make/agents.mk`
- `.agents/bin/agents-session-start`
- `.agents/agentrc`
- `AGENTS.md`
- `docs/agents/core.md`
- `docs/agents/integrations/codex.md`
- `docs/agents/git-workflow.md`
- `docs/agents/adapters/python.md`
- `docs/agents/runtime-matrix.md`
- `docs/agents/subagent-session-orchestration.md`
- `docs/agents/deployment.md`

## 2026-01-27 18:39:10 UTC
**Objectives**
- block `make read_bootstrap` without logging

**Work Performed**
- added guard to `make read_bootstrap` to require active session logging
- updated core guardrails to reflect the new requirement

**Artifacts**
- `.agents/make/agents.mk`
- `AGENTS.md`
- `docs/agents/core.md`

## 2026-01-27 18:41:05 UTC
**Objectives**
- fix guardrails typo after logging changes

**Work Performed**
- corrected a stray bullet prefix in `AGENTS.md`

**Artifacts**
- `AGENTS.md`

## 2026-01-28 13:50:34 UTC
**Objectives**
- start session and confirm guardrails

**Work Performed**
- reviewed `AGENTS.md` and `PROJECT_AGENTS.md`
- started session `20251046-20260128134959-2a223d`

## 2026-01-28 13:52:28 UTC
**Objectives**
- capture custom guardrails acknowledgement before workflow validation

**Work Performed**
- reviewed `.agents/custom/README.md`

## 2026-01-28 17:26:59 UTC
**Objectives**
- bring worktree hook fixes into main feature branch

**Work Performed**
- cherry-picked worktree-safe hook installation changes from `feature/audit-workflow-validate`

**Artifacts**
- `.agents/bin/agents-merge`
- `.agents/bin/install-hooks`

## 2026-01-28 17:52:22 UTC
**Objectives**
- redact sensitive strings in failures summaries

**Work Performed**
- added redaction patterns to `collect_failures.py` so failures summaries mask likely secrets from logs and exec events

## 2026-01-28 18:01:44 UTC
**Objectives**
- prevent secrets from appearing in review/audit artifacts

**Work Performed**
- updated auditor and senior architect prompts to forbid secrets and require redaction
- added `review_secret_scan.py` and wired it into `agents-merge` to block merges if reviews contain likely secrets

## 2026-01-28 20:38:36 UTC
**Objectives**
- enable rollout transcript extraction with redaction

**Work Performed**
- added `extract_codex_rollout.py` to locate rollout JSONL by nonce and write a redacted copy under `docs/guardrails/runs/`
- captured the current session rollout using nonce `3e655d20-b117-42c9-94b3-7e4341dbb6d3`
