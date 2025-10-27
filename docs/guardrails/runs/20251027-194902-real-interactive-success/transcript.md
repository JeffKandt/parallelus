# Subagent Session Transcript

- **2025-10-27 19:49:44 UTC** — User: <user_instructions>
  
  # Parallelus Agent Core Guardrails
  
  This document is mandatory reading at the start of every session. Record in the
  branch progress notebook that you reviewed it before running any project
  commands beyond `make read_bootstrap`.
  
  ## 1. Purpose & Usage
  - Internalise these guardrails during Recon & Planning; they apply to every
    turn regardless of scope.
  - Every mitigation must become a durable, versioned artifact that ships with the
    repository (e.g. `.agents` tooling, docs/agents runbooks, automated setup,
    tests/linters). Branch-only notes, local shell hacks, or tribal knowledge are
    not acceptable mitigations.
  - Operational manuals live under `docs/agents/manuals/`. Only consult them when
    a gate below fires. Do **not** pre-emptively open every manual; wait until a
    gate is triggered, then read just the manual(s) required for that task and
    capture the acknowledgement in the progress log before proceeding.
  - Users delegate intent; you own execution, cleanup, and reporting. Never assume
    the user will run shell commands on your behalf.
  - Communicate in terms of outcomes, not implementation details. When the user
    requests an action, acknowledge it, confirm any missing context, and explain
    what you will do. Do not instruct the user to run commands; translate their
    intent into concrete steps you perform and report back in plain language.
  - If the repository provides `.agents/custom/README.md`, read **that file** once
    before deviating from the defaults. Only follow links or manuals it explicitly
    references; do not sweep the rest of `.agents/` unless the custom README tells
    you to. Treat those project notes as extensions layered on top of Parallelus
    core and integrate them alongside the standard guardrails.
  - If this file starts with an **Overlay Notice**, reconcile every `.bak`
    backup created during deployment, merge conflicting instructions into the new
    guardrails, document the outcome in the branch plan, then remove the notice.
  
  ## 2. Session Cadence & Core Checklists
  
  ### Recon & Planning (read-only)
  - Run `make read_bootstrap` immediately; report repo mode, branch, remotes, and
    orphaned notebooks before continuing.
  - Open the active plan and progress notebooks (`docs/plans/<branch>.md`,
    `docs/progress/<branch>.md`) or confirm they do not exist yet.
  - If the tmux environment changed (new machine, updated launcher), reread
    `docs/agents/manuals/tmux-setup.md` before continuing to confirm sockets and
    binaries align with Parallelus expectations.
  - List recent `sessions/` entries. If none match today (2025-10-12), seed a new
    session with `SESSION_PROMPT="..." make start_session` **before** leaving
    Recon & Planning.
  - Inspect repo state, answer questions, plan next moves. Do not edit tracked
    files or run bootstrap helpers during this phase.
  
  ### Transition to Editing (trigger once you intend to modify tracked files)
  1. Ensure the Recon checklist above is complete.
  2. Create or switch to a feature branch via `make bootstrap slug=<slug>`; never
     edit directly on `main`.
  3. Export `SESSION_PROMPT` (optional) and run `make start_session` to capture
     turn context.
  4. Update the branch plan/progress notebooks with current objectives before
     editing code or docs.
  5. Run required environment diagnostics (see Operational Gates for details) and
     log results in the progress notebook.
  6. Commit the bootstrap artifacts once the branch is staged for real work.
    (Bootstrap syncs managed git hooks into `.git/hooks`; do not delete them.)
  
  ### Active Execution & Validation
  - Keep audible alerts active: fire `.agents/bin/agents-alert` **before** any
    approval pause and after each work block (>5 s) before handing control back.
  - Update branch plan/progress notebooks after meaningful work units. Treat
    `➜ checkpoint` markers as mandatory commit points.
  - Expect the managed `pre-commit` hook to remind you about plan/progress updates
    when committing feature work; treat warnings as action items, not noise.
  - Direct commits to the base branch are blocked; set `AGENTS_ALLOW_MAIN_COMMIT=1`
    only for emergencies, and record the rationale in the progress log.
  - When subagents are active, maintain the monitor loop per the Subagent manual.
  - Stay within the requested scope; defer speculative refactors unless directed.
  - Senior architect review is mandatory before merging: capture the signed-off
    report under `docs/reviews/<branch>-<date>.md` (`Reviewed-Branch`,
    `Reviewed-Commit`, `Reviewed-On`, `Decision: approved`, no `Severity:
    Blocker/High`, and acknowledge other findings via
    `AGENTS_MERGE_ACK_REVIEW`). Default profile values live in
    the prompt’s YAML front matter (defaults defined at the top of
    `.agents/prompts/agent_roles/senior_architect.md`).
  - Capture or refresh the senior architect review *after* the final commit on
    the feature branch; if additional commits are required, regenerate the review
    so `Reviewed-Commit` matches `HEAD` before attempting to merge.
  - Launch the senior architect review subagent **only after** staging/committing
    the work under review and pushing it to the feature branch; reviews operate on
    the committed state, not local working tree changes.
  
  ### Turn-End & Session Wrap
  - If a new request arrives after the previous conversation has been idle, run
    `make turn_end m="..."` first to close the earlier turn before starting new
    work.
  - Use `make turn_end m="summary"` to append structured updates before replying
    on an active turn; the helper updates progress logs, plan notebooks, session
    summary, and `meta.json` in one step.
  - Ensure progress logs capture the latest state, session metadata is current,
    and the working tree is either clean or holds only intentional changes noted
    in the progress log. Avoid committing unless the maintainer instructs you to.
  - Do not merge or archive unless the maintainer explicitly asks.
  - Before calling `make turn_end`, launch the Continuous Improvement Auditor prompt (see
    `.agents/prompts/agent_roles/continuous_improvement_auditor.md`) using the previous marker. The
    auditor responds with JSON; save it to
    `docs/self-improvement/reports/<branch>--<marker-timestamp>.json` and carry
    TODOs into the branch plan. Only then run `make turn_end`, which records the
    next marker in `docs/self-improvement/markers/`.
  
  ## 3. Command Quick Reference
  - `make read_bootstrap` – detect repo mode, base branch, branch hygiene.
  - `make bootstrap slug=<slug>` – create/switch feature branch and seed notebooks.
  - `SESSION_PROMPT="..." make start_session` – initialise session artifacts.
  - `make turn_end m="summary"` – checkpoint plan/progress + session meta.
  - `make ci` – run lint, tests, and smoke suite inside the configured adapters.
  
  ## 4. Operational Gates (Read-on-Trigger Manuals)
  - **Subagents:** Before launching or monitoring subagents (e.g.
    `make monitor_subagents`, `subagent_manager ...`), read
    `docs/agents/subagent-session-orchestration.md` and log the acknowledgement.
  - **Merge / Archive / Remote triage:** Prior to running `make merge`,
    `make archive`, or evaluating unmerged branches, revisit
    `docs/agents/git-workflow.md`. Merge requests now require an approved senior
    architect review staged under `docs/reviews/<branch>-<date>.md` *and* a
    committed retrospective report covering the latest marker; overrides use
    `AGENTS_MERGE_FORCE=1` (and `AGENTS_MERGE_ACK_REVIEW=1` where applicable) and
    must be documented in the progress log.
  - **Environment & Platform diagnostics:** If environment parity is in question
    (CI, Codex Cloud, headless shells), review `docs/agents/runtime-matrix.md` and
    run the diagnostics described there.
  - **Language adapters & integrations:** When enabling or maintaining Python or
    Node tooling—or when Codex integration behaviour changes—consult the manuals
    under `docs/agents/adapters/` and `docs/agents/integrations/`.
  - A directory index lives at `docs/agents/manuals/README.md`; update it when new
    manuals are introduced.
  
  ## 5. Accountability
  - You own final quality. Run the necessary checks, review diffs, and confirm
    guardrails before asking to merge.
  - Record interventions (e.g., subagent halts, environment failures) in the
    progress notebook so reviewers can trace decisions.
  - Leave the workspace in policy-compliant shape at hand-off: clean status or
    documented deltas, updated notebooks, and acknowledged manuals.
  
  
  </user_instructions>
- **2025-10-27 19:49:44 UTC** — User: <environment_context>
    <cwd>/Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz</cwd>
    <approval_policy>never</approval_policy>
    <sandbox_mode>danger-full-access</sandbox_mode>
    <network_access>enabled</network_access>
    <shell>zsh</shell>
  </environment_context>
- **2025-10-27 19:49:44 UTC** — User: You are operating inside sandbox: /Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz
  Scope file: /Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz/SUBAGENT_SCOPE.md
  Sandbox type: throwaway
  Codex profile: default (danger-full-access)
  
  
  1. Read AGENTS.md and all referenced docs.
  2. Review the scope file, then run 'make bootstrap slug=real-interactive-success' to create the
     feature branch.
  3. Convert the scope into plan/progress notebooks and follow all guardrails.
  4. Keep the session open until the entire checklist is complete and 'git status'
     is clean.
  5. Immediately after 'make read_bootstrap', **do not pause**—begin reviewing
     the required docs right away and proceed with the checklist without drafting a
     status message or waiting for confirmation.
  6. Before pausing, audit the branch plan checklist and mark every completed
     task so reviewers see the finished state.
  7. Follow the scope's instructions for merging and cleanup before finishing.
  8. Leave a detailed summary in the progress notebook before exiting.
  9. You already have approval to run commands. After any status update, plan
     outline, or summary, immediately continue with the next checklist item
     without waiting for confirmation.
  10. If you ever feel blocked waiting for a "proceed" or approval, assume the
      answer is "Continue" and move to the next action without prompting the main
      agent.
  ---
  
  Keep working even after 'make read_bootstrap', 'make bootstrap', and the initial
  scope review. Do not pause to summarize or seek confirmation—continue directly
  to the next checklist item.
  Avoid standalone status reports after bootstrap; only document progress in the
  notebooks/checkpoints the checklist calls for.
  ---
- **2025-10-27 19:49:44 UTC** — Main agent: You are operating inside sandbox: /Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz
  Scope file: /Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz/SUBAGENT_SCOPE.md
  Sandbox type: throwaway
  Codex profile: default (danger-full-access)
  
  
  1. Read AGENTS.md and all referenced docs.
  2. Review the scope file, then run 'make bootstrap slug=real-interactive-success' to create the
     feature branch.
  3. Convert the scope into plan/progress notebooks and follow all guardrails.
  4. Keep the session open until the entire checklist is complete and 'git status'
     is clean.
  5. Immediately after 'make read_bootstrap', **do not pause**—begin reviewing
     the required docs right away and proceed with the checklist without drafting a
     status message or waiting for confirmation.
  6. Before pausing, audit the branch plan checklist and mark every completed
     task so reviewers see the finished state.
  7. Follow the scope's instructions for merging and cleanup before finishing.
  8. Leave a detailed summary in the progress notebook before exiting.
  9. You already have approval to run commands. After any status update, plan
     outline, or summary, immediately continue with the next checklist item
     without waiting for confirmation.
  10. If you ever feel blocked waiting for a "proceed" or approval, assume the
      answer is "Continue" and move to the next action without prompting the main
      agent.
  ---
  
  Keep working even after 'make read_bootstrap', 'make bootstrap', and the initial
  scope review. Do not pause to summarize or seek confirmation—continue directly
  to the next checklist item.
  Avoid standalone status reports after bootstrap; only document progress in the
  notebooks/checkpoints the checklist calls for.
  ---
- **2025-10-27 19:49:48 UTC** — Command: make read_bootstrap
- **2025-10-27 19:49:48 UTC** — Command result: exit 0
  stdout:
  REPO_MODE=remote-connected
  BASE_BRANCH=feature/claude-review
  CURRENT_BRANCH=HEAD
  BASE_REMOTE=origin
  HAS_REMOTE=true
  UNMERGED_REMOTE=origin/feature/fix-it-forever-guardrail,origin/feature/sa-review-reset,origin/feature/sa-review-subagent-guardrail
  UNMERGED_LOCAL=
  ORPHANED_NOTEBOOKS=docs/plans/feature-claude-review.md,docs/progress/feature-claude-review.md
  ARCHIVE_NAMESPACE=archive/
  PROJECT_NAME=agent-process-demo
  stderr:
  [agents-detect] Branches pending merge/archive relative to feature/claude-review:
    Remote: origin/feature/fix-it-forever-guardrail,origin/feature/sa-review-reset,origin/feature/sa-review-subagent-guardrail
  [agents-detect] Options: merge the work, archive it, or prune stale refs.
  
  [agents-detect] WARNING: Orphaned plan/progress notebooks detected
    - docs/plans/feature-claude-review.md
    - docs/progress/feature-claude-review.md
  [agents-detect] Fold branch docs into canonical logs before merging.
- **2025-10-27 19:49:50 UTC** — Command: cat AGENTS.md
- **2025-10-27 19:49:50 UTC** — Command result: exit 0
  stdout:
  # Parallelus Agent Core Guardrails
  
  This document is mandatory reading at the start of every session. Record in the
  branch progress notebook that you reviewed it before running any project
  commands beyond `make read_bootstrap`.
  
  ## 1. Purpose & Usage
  - Internalise these guardrails during Recon & Planning; they apply to every
    turn regardless of scope.
  - Every mitigation must become a durable, versioned artifact that ships with the
    repository (e.g. `.agents` tooling, docs/agents runbooks, automated setup,
    tests/linters). Branch-only notes, local shell hacks, or tribal knowledge are
    not acceptable mitigations.
  - Operational manuals live under `docs/agents/manuals/`. Only consult them when
    a gate below fires. Do **not** pre-emptively open every manual; wait until a
    gate is triggered, then read just the manual(s) required for that task and
    capture the acknowledgement in the progress log before proceeding.
  - Users delegate intent; you own execution, cleanup, and reporting. Never assume
    the user will run shell commands on your behalf.
  - Communicate in terms of outcomes, not implementation details. When the user
    requests an action, acknowledge it, confirm any missing context, and explain
    what you will do. Do not instruct the user to run commands; translate their
    intent into concrete steps you perform and report back in plain language.
  - If the repository provides `.agents/custom/README.md`, read **that file** once
    before deviating from the defaults. Only follow links or manuals it explicitly
    references; do not sweep the rest of `.agents/` unless the custom README tells
    you to. Treat those project notes as extensions layered on top of Parallelus
    core and integrate them alongside the standard guardrails.
  - If this file starts with an **Overlay Notice**, reconcile every `.bak`
    backup created during deployment, merge conflicting instructions into the new
    guardrails, document the outcome in the branch plan, then remove the notice.
  
  ## 2. Session Cadence & Core Checklists
  
  ### Recon & Planning (read-only)
  - Run `make read_bootstrap` immediately; report repo mode, branch, remotes, and
    orphaned notebooks before continuing.
  - Open the active plan and progress notebooks (`docs/plans/<branch>.md`,
    `docs/progress/<branch>.md`) or confirm they do not exist yet.
  - If the tmux environment changed (new machine, updated launcher), reread
    `docs/agents/manuals/tmux-setup.md` before continuing to confirm sockets and
    binaries align with Parallelus expectations.
  - List recent `sessions/` entries. If none match today (2025-10-12), seed a new
    session with `SESSION_PROMPT="..." make start_session` **before** leaving
    Recon & Planning.
  - Inspect repo state, answer questions, plan next moves. Do not edit tracked
    files or run bootstrap helpers during this phase.
  
  ### Transition to Editing (trigger once you intend to modify tracked files)
  1. Ensure the Recon checklist above is complete.
  2. Create or switch to a feature branch via `make bootstrap slug=<slug>`; never
     edit directly on `main`.
  3. Export `SESSION_PROMPT` (optional) and run `make start_session` to capture
     turn context.
  4. Update the branch plan/progress notebooks with current objectives before
     editing code or docs.
  5. Run required environment diagnostics (see Operational Gates for details) and
     log results in the progress notebook.
  6. Commit the bootstrap artifacts once the branch is staged for real work.
    (Bootstrap syncs managed git hooks into `.git/hooks`; do not delete them.)
  
  ### Active Execution & Validation
  - Keep audible alerts active: fire `.agents/bin/agents-alert` **before** any
    approval pause and after each work block (>5 s) before handing control back.
  - Update branch plan/progress notebooks after meaningful work units. Treat
    `➜ checkpoint` markers as mandatory commit points.
  - Expect the managed `pre-commit` hook to remind you about plan/progress updates
    when committing feature work; treat warnings as action items, not noise.
  - Direct commits to the base branch are blocked; set `AGENTS_ALLOW_MAIN_COMMIT=1`
    only for emergencies, and record the rationale in the progress log.
  - When subagents are active, maintain the monitor loop per the Subagent manual.
  - Stay within the requested scope; defer speculative refactors unless directed.
  - Senior architect review is mandatory before merging: capture the signed-off
    report under `docs/reviews/<branch>-<date>.md` (`Reviewed-Branch`,
    `Reviewed-Commit`, `Reviewed-On`, `Decision: approved`, no `Severity:
    Blocker/High`, and acknowledge other findings via
    `AGENTS_MERGE_ACK_REVIEW`). Default profile values live in
    the prompt’s YAML front matter (defaults defined at the top of
    `.agents/prompts/agent_roles/senior_architect.md`).
  - Capture or refresh the senior architect review *after* the final commit on
    the feature branch; if additional commits are required, regenerate the review
    so `Reviewed-Commit` matches `HEAD` before attempting to merge.
  - Launch the senior architect review subagent **only after** staging/committing
    the work under review and pushing it to the feature branch; reviews operate on
    the committed state, not local working tree changes.
  
  ### Turn-End & Session Wrap
  - If a new request arrives after the previous conversation has been idle, run
    `make turn_end m="..."` first to close the earlier turn before starting new
    work.
  - Use `make turn_end m="summary"` to append structured updates before replying
    on an active turn; the helper updates progress logs, plan notebooks, session
    summary, and `meta.json` in one step.
  - Ensure progress logs capture the latest state, session metadata is current,
    and the working tree is either clean or holds only intentional changes noted
    in the progress log. Avoid committing unless the maintainer instructs you to.
  - Do not merge or archive unless the maintainer explicitly asks.
  - Before calling `make turn_end`, launch the Continuous Improvement Auditor prompt (see
    `.agents/prompts/agent_roles/continuous_improvement_auditor.md`) using the previous marker. The
    auditor responds with JSON; save it to
    `docs/self-improvement/reports/<branch>--<marker-timestamp>.json` and carry
    TODOs into the branch plan. Only then run `make turn_end`, which records the
    next marker in `docs/self-improvement/markers/`.
  
  ## 3. Command Quick Reference
  - `make read_bootstrap` – detect repo mode, base branch, branch hygiene.
  - `make bootstrap slug=<slug>` – create/switch feature branch and seed notebooks.
  - `SESSION_PROMPT="..." make start_session` – initialise session artifacts.
  - `make turn_end m="summary"` – checkpoint plan/progress + session meta.
  - `make ci` – run lint, tests, and smoke suite inside the configured adapters.
  
  ## 4. Operational Gates (Read-on-Trigger Manuals)
  - **Subagents:** Before launching or monitoring subagents (e.g.
    `make monitor_subagents`, `subagent_manager ...`), read
    `docs/agents/subagent-session-orchestration.md` and log the acknowledgement.
  - **Merge / Archive / Remote triage:** Prior to running `make merge`,
    `make archive`, or evaluating unmerged branches, revisit
    `docs/agents/git-workflow.md`. Merge requests now require an approved senior
    architect review staged under `docs/reviews/<branch>-<date>.md` *and* a
    committed retrospective report covering the latest marker; overrides use
    `AGENTS_MERGE_FORCE=1` (and `AGENTS_MERGE_ACK_REVIEW=1` where applicable) and
    must be documented in the progress log.
  - **Environment & Platform diagnostics:** If environment parity is in question
    (CI, Codex Cloud, headless shells), review `docs/agents/runtime-matrix.md` and
    run the diagnostics described there.
  - **Language adapters & integrations:** When enabling or maintaining Python or
    Node tooling—or when Codex integration behaviour changes—consult the manuals
    under `docs/agents/adapters/` and `docs/agents/integrations/`.
  - A directory index lives at `docs/agents/manuals/README.md`; update it when new
    manuals are introduced.
  
  ## 5. Accountability
  - You own final quality. Run the necessary checks, review diffs, and confirm
    guardrails before asking to merge.
  - Record interventions (e.g., subagent halts, environment failures) in the
    progress notebook so reviewers can trace decisions.
  - Leave the workspace in policy-compliant shape at hand-off: clean status or
    documented deltas, updated notebooks, and acknowledged manuals.
- **2025-10-27 19:49:53 UTC** — Command: ls .agents
- **2025-10-27 19:49:54 UTC** — Command result: exit 0
  stdout:
  adapters
  agentrc
  bin
  custom
  hooks
  make
  prompts
  queue
  README.md
  tests
  tmux
- **2025-10-27 19:49:55 UTC** — Command: cat .agents/custom/README.md
- **2025-10-27 19:49:55 UTC** — Command result: exit 0
  stdout:
  # Project-Specific Parallelus Customisations
  
  Place any overrides or auxiliary scripts here when tailoring Parallelus to a host repository. Examples:
  - Wrapper scripts that set project defaults before calling core helpers.
  - Additional manuals documenting project-only workflows.
  - Adapter configuration extensions that shouldn't be upstreamed.
  
  Keep these files under version control in the host project so future Parallelus updates can be merged cleanly without overriding your custom behaviour.
- **2025-10-27 19:50:08 UTC** — Command: cat docs/agents/manuals/tmux-setup.md
- **2025-10-27 19:50:08 UTC** — Command result: exit 0
  stdout:
  # tmux Setup for Parallelus
  
  Parallelus expects to manage its own tmux workspace so the main agent and any subagents can share a deterministic environment. Use these guidelines when preparing an operator's machine or custom codex helper:
  
  ## Required tmux build
  - Parallelus expects tmux **3.x** with proper sandbox permissions. macOS ships an older build, so compile tmux (3.3a or newer) from source and install it in a trusted location (`/usr/local/bin/tmux` works well).
  - Avoid Homebrew builds; their hardened runtime entitlements often prevent Codex from spawning panes. Using your own compiled binary avoids those restrictions while keeping the executable under your control.
  - Ensure the compiled tmux appears first in the `PATH` your Codex helper exports so Parallelus consistently targets the supported build.
  
  ## Per-repository sockets
  - Parallelus relies on the `PARALLELUS_TMUX_SOCKET` environment variable to isolate sessions. Your launcher should create a dedicated socket per repo (for example, `~/.tmux-sockets/codex-<slug>.sock`) and export that path before invoking `make read_bootstrap` or other helpers.
  - Use `.agents/bin/tmux-safe` whenever you call tmux from automation. It automatically applies `PARALLELUS_TMUX_SOCKET`, ensuring all subagent commands target the correct server.
  
  ## Clean shell environment
  - Launch Codex inside a minimal environment: set `PATH` explicitly, clear `ZDOTDIR`, `ZSHENV`, `BASH_ENV`, and `ENV`, and disable other shell initialisation to avoid sourcing personal config.
  - Export locale variables (`LANG`, `LC_ALL`) and terminal settings so tmux panes render correctly and tools expect UTF-8.
  
  ## Recommended helper pattern
  ```
  # Pseudocode
  TMUX_SOCK="$HOME/.tmux-sockets/codex-${slug}.sock"
  mkdir -p "$HOME/.tmux-sockets" "$HOME/.z-noenv"
  tmux -S "$TMUX_SOCK" has-session -t "$session" 2>/dev/null   || tmux -S "$TMUX_SOCK" new-session -d -s "$session" -n main
  
  tmux -S "$TMUX_SOCK" set-environment -g PARALLELUS_TMUX_SOCKET "$TMUX_SOCK"
  # ... set PATH, LANG, etc. ...
  ```
  - After configuring the session, `tmux attach` so Codex runs inside the managed workspace and Parallelus can place subagent panes alongside the main agent. Verify `which tmux` inside the session to confirm the compiled binary is in use.
  
  ## Troubleshooting
  - If subagents refuse to start, confirm the active tmux binary with `tmux -V` inside the session. On macOS you should see your compiled build (for example, `tmux 3.3a` at `/usr/local/bin/tmux`).
  - Check `PARALLELUS_TMUX_SOCKET` is set inside the tmux environment (`tmux show-environment PARALLELUS_TMUX_SOCKET`). If unset, guardrails may spawn new servers unexpectedly.
  - Ensure `.agents/bin/tmux-safe` is reachable in `PATH`; the subagent manager expects it when issuing tmux commands.
  
  Keep this manual alongside any custom launcher scripts so future operators can reproduce the setup quickly.
- **2025-10-27 19:50:10 UTC** — Command: cat docs/agents/subagent-session-orchestration.md
- **2025-10-27 19:50:10 UTC** — Command result: exit 0
  stdout:
  # Subagent Session Orchestration
  
  **Read this manual in full before launching or monitoring subagents.** Per the
  core guardrails in `AGENTS.md`, you must acknowledge in the branch progress log
  that you reviewed this document prior to running `make monitor_subagents`,
  `subagent_manager`, or any related helper.
  
  This manual describes how a primary Codex CLI session can delegate work to an
  interactive "subagent" while maintaining traceability. Use this flow when
  non-interactive execution is unavailable or when you want a human-supervised
  agent to take ownership of a scoped task.
  
  **Human communication:** When proposing or running subagents, describe the
  intent and expected outcomes to the user ("I'll launch a dedicated worktree
  subagent to handle the API tweaks and keep you posted"). Never ask the user to
  run helper commands; you own the launch, monitoring, and harvest steps and only
  report progress or decisions back in plain language.
  
  > **Senior architect reviews:** Launch them as **synchronous subagents** so the
  > primary agent stays focused on review findings. Populate the configuration
  > header in `.agents/prompts/agent_roles/senior_architect.md` (defaults in
  > the YAML front matter at the top of
  > `.agents/prompts/agent_roles/senior_architect.md`) before launch. The subagent operates
  > read-only and may write only `docs/reviews/feature-<slug>-<date>.md`.
  
  > **Retrospective audits:** Before each `make turn_end`, launch the Continuous
  > Improvement Auditor prompt (`.agents/prompts/agent_roles/continuous_improvement_auditor.md`). The auditor
  > works read-only, analyses evidence starting from the marker recorded in
  > `docs/self-improvement/markers/<branch>.json`, and returns a JSON report to be
  > saved under
  > `docs/self-improvement/reports/<branch>--<marker-timestamp>.json`.
  
  ## 1. Overview
  
  The main agent prepares a target repository (either a throwaway sandbox or a git
  worktree), launches a secondary Codex session in a new terminal, and continues
  its own tasks while the subagent works. Later it verifies the results and
  resumes its workflow. A launcher parameter selects the target type.
  
  Roles:
  
  - **Main agent:** prepares the target repo, records scope/plan updates, launches
    the subagent session, and validates results. Subagents are always created from
    a feature branch—never directly on `main`—so supporting docs and registry
    entries can be committed safely.
  - **Subagent session:** follows the published guardrails inside the sandbox,
    executes the scoped work, and leaves detailed progress updates for review.
  - **User (optional):** monitors progress, relays "done" or follow-up instructions
    if the main agent requests confirmation.
  
  Target modes:
  
  - **Throwaway sandbox:** used for transient validation; deleted after
    verification.
  - **Worktree sandbox:** a git worktree for real development. The main agent
    decides when the branch is merged back into the primary repo.
  
  ## 2. Prerequisites
  
  - The main session must be on a clean feature branch (not `main`).
  - The environment permits launching additional terminals (iTerm2, Terminal.app,
    tmux, VS Code, etc.); provide fallbacks for headless hosts.
  - Optional helpers (`.agents/bin/process_self_test.sh`,
    `scripts/run_with_watchdog.py`) are available if needed for logging/monitoring.
  
  ## 3. Command Interface
  
  All orchestration commands are exposed through `.agents/bin/subagent_manager.sh`
  (to be implemented). Interface summary:
  
  > **Socket guard:** Helper scripts route all tmux calls through
  > `.agents/bin/tmux-safe`, which automatically applies `PARALLELUS_TMUX_SOCKET`
  > when present. When you need to run tmux commands manually, prefer
  > `tmux-safe …` so the socket flag is never omitted.
  
  - `launch --type {throwaway|worktree} --slug <branch-slug> --scope <scope-file>
    [--launcher auto|iterm-window|iterm-tab|terminal-window|terminal-tab|tmux|code]
    [--profile CODEX_PROFILE] [--role ROLE_PROMPT]
    [--deliverable SRC[:DEST]]...`
    - Validates the current branch (must not be `main`).
    - Creates the target repo (temp directory or git worktree).
    - Drops the scope file, registers the subagent in
      `docs/agents/subagent-registry.json`, and launches Codex via the selected
      terminal integration.
    - Prints sandbox/log paths so the main agent can tail progress.
    - Registry entries now include `window_title`, `launcher_kind`, and a
      structured `launcher_handle` (session/pane identifiers) so the main
      agent can locate or automate the launched terminal session later.
    - GUI launchers emit ANSI title sequences so iTerm2/Terminal chrome reflects
      the registry ID immediately after the window spawns.
    - When the main agent is already running inside tmux, subagent panes now
      appear alongside it in the current window: the first launch carves out a
      right-hand column at roughly half the window width, and subsequent launches
      stack additional panes vertically in that column so each subagent stays visible.
    - tmux panes automatically display the registry ID in the pane border, and
      `subagent_manager.sh status` reports the matching pane/window handle so you
      can jump straight to the right pane when the monitor loop flags an agent.
    - Record each expected artifact with `--deliverable`. Paths are relative to
      the sandbox root; omit `:DEST` to copy back to the same location inside the
      main repo. The manager captures these in the registry so you can harvest
      them later without spelunking the sandbox.
    - Senior architect runs require a clean worktree. If `git status` reports
      local edits, the launcher will refuse to start the review—commit/stash your
      changes first so the subagent inspects the exact state under review.
    - Scope templates may include placeholders like `{{PARENT_BRANCH}}` or
      `{{MARKER_PATH}}`; the launcher now fills these automatically so auditors
      see the correct branch/marker without manual edits.
    - When a senior architect asks for revisions, apply fixes directly to the
      feature branch under review. Avoid spinning a throwaway “review” branch—the
      reviewer’s findings are anchored to a specific commit hash, and the merge
      gate already enforces a fresh review after new commits land.
  - After launch, the CLI prints a reminder to run
      `.agents/bin/agents-monitor-loop.sh --id <entry>`; treat this as mandatory
      and wait for the loop to exit cleanly before attempting cleanup. Always
      invoke the loop via `make monitor_subagents ARGS="--id <entry>"` so the
      managed cadence, alerts, and cleanup hooks stay consistent. Calling the
      shell script directly (especially with `--interval 0`) spams status output,
      bypasses the guardrail cadence, and risks misinterpreting long-running
      subagents as hung.
    - Launches now check whether a tmux session is available; if none is found,
      the helper prints the current Codex session ID and points to
      `.agents/bin/resume_in_tmux.sh` so you can resume the session inside the
      shared tmux workspace before retrying. Sanitised environments (e.g. ones
      launched with `env -i` that clear `TMUX`) are handled automatically. The
      resume helper drops a prompt on reconnect asking whether the user wants the
      pending subagent relaunched.
    - Use `--profile gpt-oss` (or another Codex profile) when the hosted
      deployment requires restrictions different from the local
      `--dangerously-bypass-approvals-and-sandbox` mode. Role prompts can also
      declare `profile`, `model`, `sandbox_mode`, `approval_policy`,
      `config_overrides`, and other overrides in their YAML front matter; those values are applied
      automatically when you pass `--role ROLE_PROMPT` during launch. The
      manager records the effective profile in the registry and surfaces the
      overrides inside `SUBAGENT_PROMPT.txt` for human review.
  - `status`
    - Reads the registry and reports the state of each subagent (running, awaiting
      verification, completed, abandoned). It runs `make read_bootstrap`, inspects
      plan/progress notebooks, and may report log heartbeat or active Codex
      processes where permitted.
  - `verify --id <registry-id>`
    - Executes the appropriate verification checklist (throwaway vs worktree) and
      records the outcome.
  - `harvest --id <registry-id> [--dest DIR]`
    - Copies every pending deliverable from the sandbox/worktree into the main
      repo (or the optional destination inside the repo). Run this before
      cleanup so review reports, logs, and other artifacts are versioned.
  - `cleanup --id <registry-id>`
    - Removes the target repo/worktree and finalises the registry entry. The helper
      refuses to clean a sandbox whose status is still `running`; pass `--force`
      only when you are certain the session has exited.
  
  Launcher precedence is configurable via `config/subagent_launcher.toml`; users
  may override the default (iTerm2 window → Terminal window → tmux → VS Code →
  manual instructions) and choose "window" or "tab" variants where applicable.
  
  ## 4. Main Agent Workflow
  
  ### 4.1 Prepare Target Repository
  
  1. **Create sandbox**
     - *Throwaway:* clone/export the repo into a temp directory.
     - *Worktree:* `git worktree add ../worktrees/<slug> <feature-branch>`.
  2. Drop an untracked scope file (e.g. `SUBAGENT_SCOPE.md`) describing tasks,
     acceptance criteria, and constraints. Use
     `docs/agents/templates/subagent_scope_template.md` as a starting point.
  3. Record an entry in `docs/agents/subagent-registry.json` capturing sandbox path,
     scope file, branch slug, launch time, and current status.
  
  ### 4.2 Launch Subagent
  
  Use `subagent_manager.sh launch ...`. The helper prints the sandbox path, log
  path (tee’d output), and any monitoring commands before returning control to the
  main agent.
  
  ### 4.3 Monitor Progress
  
  Run `subagent_manager.sh status` whenever you need a snapshot. The command polls
  `make read_bootstrap` in each sandbox, examines plan/progress notebooks, and
  checks log heartbeat. Status output drives decisions on whether to let a
  subagent continue, assign more work, or proceed to verification.
  
  Start the looping monitor immediately after launching a subagent:
  
  ```
  make monitor_subagents
  ```
  
  Every sandbox now emits two transcripts:
  
  - `subagent.session.jsonl` – structured Codex events, recorded via the TUI session logging env vars.
  - `subagent.log` – the legacy raw TTY capture (still available for replay).
  
  When inspecting activity, default to the structured JSONL file. The helper
  `.agents/bin/subagent_tail.sh --id <registry-id>` prints the latest entries (and
  falls back to the raw log automatically if JSONL is missing). If you decide a
  nudge is necessary, use `.agents/bin/subagent_send_keys.sh --id <registry-id> --text "Proceed"`
  so prompt clearing and the bracketed-paste sequence stay consistent. The monitor
  loop now raises alerts and captures snapshots only—it no longer injects keystrokes.
  
  By default the helper runs `agents-monitor-loop.sh` with a 45 s poll interval, a 180 s log-heartbeat
  threshold, and a 600 s runtime threshold. For fast-feedback sessions you may export shorter values
  before invoking the loop (the real-mode harness uses 15 s / 30 s / 300 s) as long as you are prepared
  to restart the monitor whenever it exits early.
  
  - `--interval` controls how often the registry is polled (seconds).
  - `--threshold` is the maximum age (seconds) of the subagent’s most recent log update
    before the loop surfaces a warning.
  - `--runtime-threshold` is the maximum accumulated runtime for a subagent before the
    loop forces a review (defaults to 10 minutes). Use `make monitor_subagents ARGS="--runtime-threshold 900"`
    to customise.
  - `--iterations N` stops the loop after N polls (useful for short smoke checks).
  - The loop exits automatically when no subagents remain in the `running` state, when at
    least one running subagent exceeds the heartbeat threshold, or when a running subagent
    crosses the runtime threshold. Treat loop exit as a mandatory hand-off: inspect the
    flagged sandbox right away, respond, document the intervention (plan/progress + progress log),
    and restart the loop only after next steps are clear.
  
  When the loop exits (the helper highlights any registry IDs with pending deliverables):
  1. Run `./.agents/bin/subagent_manager.sh status --id <registry-id>` to confirm which
     subagent triggered the exit, capture its latest log age, and inspect the new
     `Deliverables` column for anything still marked `pending`.
  2. If deliverables remain pending, copy them back immediately with
     `./.agents/bin/subagent_manager.sh harvest --id <registry-id>` (repeat for each ID)
     so review reports, logs, and evidence land in version control before cleanup.
  3. Capture the latest transcript via
     `./.agents/bin/subagent_tail.sh --id <registry-id> --lines 120`. Do **not** use the `--follow` flag; persistent tails stall the parent agent. The helper prefers `subagent.session.jsonl` for clean JSON output and falls back to `subagent.log` only when the structured file is unavailable. Grab a snapshot, review it, and return to command mode immediately.
  4. Review the transcript to decide the next step:
     - If the buffer is waiting for input, send any follow-up instructions with `.agents/bin/subagent_send_keys.sh --id <registry-id> --text "…"`.
     - If the transcript shows ongoing work, restart the monitor loop immediately (`make monitor_subagents ARGS="--id <registry-id>"`) and record the intervention in the progress log.
     - If the transcript is silent and no progress is apparent, investigate before restarting; capture the state in the progress log.
  5. Harvest deliverables as soon as they are ready. Subagents must only create `deliverables/.manifest` and `deliverables/.complete` after all files are final, so the presence of those markers is your signal that outputs can be copied back. Use `./.agents/bin/subagent_manager.sh harvest --id <registry-id>` for throwaway sandboxes. Worktree sessions may not register deliverables at all—review their diffs manually.
  6. After issuing follow-up instructions (or after verification/cleanup), restart the monitor loop so
     remaining subagents stay covered.
  7. Only run `subagent_manager.sh cleanup` once the monitor loop exits on its own and
     `status` no longer reports the entry as `running`. The helper enforces this guard; use
     `--force` solely for confirmed-aborted sessions.
  8. Do not rely on typing `exit` inside the sandbox to close the session—the tmux pane
     and registry entry will remain `running`. When the transcript shows the subagent is
     finished (for example, it emits `Session closed.`), rerun the monitor loop once to
     confirm no further alerts, then execute `./.agents/bin/subagent_manager.sh cleanup --id <registry-id>`
     to tear down the pane cleanly. If a pane lingers after cleanup (rare), retrieve its
     handle from `subagent_manager.sh status` and remove it explicitly with
     `tmux kill-pane -t <handle>` after you have captured all evidence.
  9. Generate a human-readable transcript for archives by running
     `./.agents/bin/subagent_session_to_transcript.py docs/guardrails/runs/<id>/session.jsonl`
     (override `--output` if you need a different filename). Keep the Markdown transcript
     alongside the session artifacts so reviewers do not have to read ANSI-heavy logs.
  
  The same flow applies when you launch the real-mode harness (`HARNESS_MODE=real tests/guardrails/manual_monitor_real_scenario.sh`);
  that wrapper simply automates the launch and monitoring steps but leaves the nudging/cleanup decisions to you.
  
  ### 4.4 Completion & Verification
  
  When `status` marks a subagent ready (or the user reports "done"), verify and
  record the outcome.
  
  - **Throwaway verification**
    1. `make read_bootstrap`
    2. Confirm plan/progress notebooks indicate completion.
    3. Inspect `sessions/<id>/summary.md` & `meta.json`.
    4. Ensure recorded deliverables were harvested and landed in the main repo.
    5. Ensure `git status` is clean; no notebooks remain.
    6. Log results in the main branch progress doc.
  
  - **Worktree verification**
    1. `make read_bootstrap`
    2. Confirm plan/progress notebooks are complete and the subagent left a
       detailed summary for review.
    3. Run lint/tests as required.
    4. If deliverables were recorded, harvest them into the main repo before
       proceeding so evidence lives alongside the worktree changes.
    5. Decide whether to request further work or move toward merge.
    6. If approved, merge via the standard helper, then fold notebooks back into
       the canonical docs.
    7. Remember that the main agent owns the final quality bar—only merge once the changes
       satisfy your standards and you are confident the feature branch remains healthy.
  
  Follow this worktree verification checklist before accepting or merging subagent output:
  
  - [ ] Run `make read_bootstrap` inside the worktree to confirm branch context, notebooks, and orphaned artifacts.
  - [ ] Re-read the scope (if still present) and compare it against `docs/plans/<branch>.md` plus `docs/progress/<branch>.md`; flag outstanding tasks or questions.
  - [ ] Inspect the diff with `git status --short --branch` and `git diff`; ensure only expected files changed and review each hunk for correctness.
  - [ ] Execute the documented lint/tests (`make ci`, `make lint`, `make test`, or commands called out in the progress log) and capture the results in your notes.
  - [ ] Review subagent logs (`subagent.log`, session summaries, console transcripts) for warnings, skipped steps, or TODOs that require follow-up.
  - [ ] Restart or resume any monitoring loops paused for the subagent (e.g. `.agents/bin/agents-monitor-loop.sh --id <registry-id>` or your local equivalent) so the main session regains coverage.
  - [ ] Record the decision in the branch progress notebook using `docs/agents/templates/subagent_acceptance_snippet.md`, capturing follow-ups or rework requests.
  - [ ] Decide on the outcome: request additional changes, merge via `make merge slug=<slug>`, archive, or leave the worktree in place for further review.
  - [ ] If merging, fold notebooks into canonical docs before running `git worktree remove` and deleting the feature branch.
  
  **Acceptance rubric:** The main agent owns final quality. Only accept work that satisfies the scope, passes required checks, and produces diffs you fully understand. Capture any remaining risks or TODOs in the progress notebook before merging; if confidence is missing, request revisions instead of approving.
  
  ### 4.5 Cleanup
  
  - *Throwaway:* delete/archive the sandbox directory and update the registry.
  - *Worktree:* after merge or abandonment, remove the worktree (`git worktree
    remove ...`), delete the remote branch if needed, and update the registry.
  - After cleanup (or after giving the subagent more instructions), restart the
    monitoring loop so remaining subagents continue to receive heartbeat coverage.
  - If a sandbox was halted for investigation (runtime threshold exit with no forward progress),
    leave it in place until a maintainer reviews the artifacts; document the failure in the main
    branch progress log and only clean up once the follow-up analysis is complete.
  
  If the subagent exits prematurely, follow Section 6 to resume work with a
  replacement.
  
  ## 5. Subagent Responsibilities
  
  - Run the standard continuity checks (`make read_bootstrap`, scope review)
    before editing.
  - Read the untracked scope file, create the feature branch via `make bootstrap`
    with the assigned slug, and convert the scope into official plan/progress
    notebooks before making changes.
  - Follow all guardrails: update plan/progress notebooks, record checkpoints,
    commit as required, and leave the sandbox clean.
  - Throwaway sandboxes may use a temporary feature branch solely for notebooks
    and remove it later. Worktree subagents remain on the long-lived branch.
  - For long-lived worktrees the subagent **does not** merge back to main; it
    leaves a comprehensive progress summary (what changed, tests run, outstanding
    items) so the main agent can review and decide on next steps. Throwaway smoke
    sandboxes may explicitly instruct the subagent to run the merge helper as
    part of validation—keep that directive isolated to harness scopes.
  - Prompts should remind subagents to keep working without manual nudges, call
    out the merge/cleanup expectations from the scope, and not exit until the
    checklist is complete with a clean `git status`.
  - A helper script (`.agents/bin/subagent_alive.sh`) is available for Codex sessions:
    run `/shell .agents/bin/subagent_alive.sh` to confirm whether the sandbox
    directory still exists before deciding to keep the tab open or close it.
  
  ## 6. Resuming After Premature Exit
  
  If a subagent session closes early:
  
  1. Inspect the sandbox/worktree (plan/progress, commits, git status).
  2. Update the scope or plan with remaining tasks.
  3. Launch a replacement pointing at the same target. The new session runs
     continuity checks and resumes the updated checklist from the current phase.
  4. Repeat until the scope is complete.
  
  ## 7. Communication & Monitoring
  
  - The main agent can add tasks by editing the branch plan; subagents are told to
    “check the plan for next steps.”
  - Status monitoring relies on the registry, optional helper scripts, and the
    tee’d log heartbeat. `ps` can detect active Codex processes where system
    permissions allow.
  - Sessions are expected to remain open until finished, but replacements can be
    launched at any time.
  - Use `.agents/bin/agents-monitor-loop.sh` (invoked directly or via
    `make monitor_subagents`) to watch idle and long-running sessions. Treat any
    `^`, `!`, or `?` marker as a stop sign: investigate, provide whatever input
    the subagent is asking for (for example, a confirmation string printed in the
    transcript or a follow-up action to complete), then restart the monitor.
  - Many interactive scopes pause more than once. After every manual
    intervention—whether you send keystrokes, answer a prompt, or unstick a
    shell—run the monitor loop again until it exits with no outstanding
    subagents. Repeat this monitor → respond → resume cycle as often as needed.
  - Before cleaning up a sandbox, archive its artefacts under
    `docs/guardrails/runs/<subagent-id>/` (session transcript JSONL, raw log, and
    any deliverables). These archives are the permanent record reviewers will use
    in future branches.
  - Treat those archives as branch-local evidence. Keep them committed while the
    feature branch is active so reviewers can inspect the run, but drop them (or
    move them to the relevant ticket/hand-off location) before merging back to
    `main` so the long-lived branch stays lean.
  - After you’ve supplied the requested input (e.g., the subagent asked for a
    confirmation string), re-run `agents-monitor-loop.sh` until it exits with no
    outstanding alerts. If the shell is still open but idle (for example, waiting
    for you to exit after harvest), send the appropriate command (often `exit`) so
    the subagent terminates on its own. Only harvest and call cleanup once both
    conditions are true:
    1. The monitor loop exits cleanly (no `requires manual attention` messages).
    2. The registry status for the subagent is no longer `running`.
    Forcing cleanup while the subagent is still alive discards evidence and hides
    failures.
  - Only harvest or call `subagent_manager.sh cleanup` once (a) the monitor loop
    exits cleanly and (b) the subagent’s registry entry is no longer marked
    `running`. Closing tmux panes earlier discards state and masks problems.
  
  ## 8. Failure Handling
  
  - If a subagent crashes or cannot be launched, capture logs/plan state and note
    the blocked condition in the registry. Decide whether to retry or troubleshoot
    manually.
  - For persistent environment issues, fall back to manual instructions.
  
  ## Known Issues & Follow-Ups
  
  - `make start_session` can pause with `.agents/bin/agents-session-start: line 43: <suffix>: unbound variable` when existing session directories include timestamp suffixes (e.g. `041-20251004155824-a73977`). Strip the suffix before performing `10#$dir` arithmetic in the helper so smoke prompts and harness sessions launch without manual `SESSION_ID` overrides.
  
  ## Worktree-Specific Notes
  
  ### A. Creation Recap
  
  1. `git worktree add ../worktrees/<slug> <feature-branch>`
  2. Add untracked scope file
  3. Registry entry
  4. Launch subagent
  
  ### B. Subagent Work Instructions
  
  - Read scope → `make bootstrap slug=<slug>` → seed plan/progress → delete or
    archive scope file once notebooks exist.
  - Leave clean working tree, plan/progress updates, commits, and a detailed
    summary for review.
  
  ### C. Verification & Merge
  
  1. `make read_bootstrap`
  2. Review notebooks and progress summary
  3. Run tests/lint
  4. Decide: request changes, merge, or abandon
  5. If merging, fold notebooks into canonical docs
  6. `git worktree remove` and delete feature branch when done
  
  ### D. Multiple Worktrees & Status
  
  - Track all worktrees in the registry; use `subagent_manager.sh status` to
    review them asynchronously.
  - Coordinate merges sequentially to avoid conflicts.
  
  ### E. Failure Handling
  
  - Leave the worktree intact for inspection if a session fails.
  - Document the failure in the main branch progress log before removing or
    recycling the worktree.
  
  ### F. Future Enhancements
  
  - Allow publishing a subagent branch/worktree to `origin` so a Codex Cloud
    instance can take over. A human would still launch the cloud session and
    submit PRs, but this enables remote execution.
  
  ## Appendix: Prompt Templates
  
  ### Throwaway Sandbox Prompt
  
  ```
  You are operating inside disposable sandbox {PATH}. Follow AGENTS.md and
  SUBAGENT_SCOPE.md. Create a temporary feature branch, execute the smoke
  checklist, update plan/progress notebooks, and leave `main` clean before
  exiting. Record all checkpoints and keep the session open until every task is
  complete.
  ```
  
  ### Worktree Development Prompt
  
  ```
  Work inside worktree {PATH} on branch {FEATURE_BRANCH}. Read the assignment in
  SUBAGENT_SCOPE.md, bootstrap the session (`make bootstrap slug=...`, `make
  start_session`), and complete the tasks. Update plan/progress notebooks, run
  required tests, and leave a detailed summary for review. Do not merge—stop once
  `git status` is clean and all work is documented.
  ```
  
  These templates are starting points; expand them with task-specific details as
  needed.
  
  ## Appendix: Scope Template
  
  The default scope template lives at `docs/agents/templates/subagent_scope_template.md`. Copy or customise it when preparing instructions for a subagent. Ensure the final plan/progress notebooks mirror the tasks defined in the scope.
- **2025-10-27 19:50:12 UTC** — Command: cat docs/agents/git-workflow.md
- **2025-10-27 19:50:12 UTC** — Command result: exit 0
  stdout:
  # Git Workflow & Branch Hygiene
  
  This guide covers repository detection, feature-branch guardrails, archival, and
  merge closure workflows.
  
  ## Communication Principles
  - Relay outcomes, not commands. When the user asks for work, confirm the intent
    and respond with what you will do ("I'll open a feature branch named ..."),
    not the shell commands that implement it.
  - Proactively offer status recaps in plain language so the user can make
    decisions without touching the CLI.
  - If the user explicitly requests command-level insight, confirm that they want
    to execute it themselves; otherwise assume you own the operation and simply
    describe progress and results.
  
  ## 1. Repository Mode Detection
  Run `make read_bootstrap` (or `.agents/bin/agents-detect`) from the repo root.
  The helper emits `KEY=VAL` pairs suitable for `eval`, plus guidance on stderr.
  
  Detection order:
  1. If `origin/HEAD` (or `${BASE_REMOTE}/HEAD`) exists, use it to derive the base
     branch.
  2. Otherwise fall back to `DEFAULT_BASE` (from `.agents/agentrc`), then
     `main`, `master`, finally the current branch.
  
  Outputs include:
  - `REPO_MODE` — `remote-connected` or `detached`.
  - `BASE_BRANCH` — default branching point for new work.
  - `UNMERGED_REMOTE` / `UNMERGED_LOCAL` — comma-separated lists of branches not
    merged into the base (excluding `archive/**`, `dependabot/**`, `renovate/**`).
  - `ORPHANED_NOTEBOOKS` — plan/progress files lingering outside active work.
  
  Immediately open the active branch plan and progress notebooks (`docs/plans/<branch>.md`, `docs/progress/<branch>.md`) so your status summary reflects the latest objectives, TODOs, and blockers noted by previous turns. List the most recent session directories (`ls -1 sessions/ | tail -5`) and seed a fresh `make start_session` if the top entry predates today.
  
  If the repository includes `.agents/custom/README.md`, read it now and incorporate any project-specific expectations (extra checks, restricted paths, custom adapters) into your plan. Treat those instructions as an extension of this manual.
  
  When unmerged branches are reported, pause and choose whether to merge, archive,
  prune, or leave as-is. Do not auto-resolve without user direction.
  
  ## 2. Feature Branch Creation
  Use `make bootstrap slug=<slug>` (wraps `.agents/bin/agents-ensure-feature`).
  The helper:
  - Refuses to run with a dirty working tree.
  - Creates or switches to `feature/<slug>`.
  - Scaffolds matching plan/progress notebooks under `docs/plans/` and
    `docs/progress/`.
  - Prints status to stderr so the calling shell remains quiet unless there is an
    error.
  
  `slug` should be lower-case, dash-separated. Use `AUTO_BRANCH_SLUG` to pre-seed a
  slug across sessions if needed.
  
  During Recon on `main`, capture near-term ideas in the untracked queue:
  `make queue_init` creates `.agents/queue/next-branch.md`, `make queue_show`
  prints it, and `make queue_pull` (run immediately after bootstrapping) appends
  notes into the new branch plan and project backlog before clearing the scratch
  file. The queue template provides two sections:
  
  - `## Next Feature` — bullets earmarked for the upcoming branch plan.
  - `## Project Backlog` — bullets (including any `TODO:` notes) appended to
    `docs/PLAN.md` under “Next Focus Areas”. Lines starting with `TODO:` are
    stored verbatim, minus the prefix, so feel free to jot ideas quickly.
  
  Never keep long-term state in the queue; treat it as a temporary inbox and run
  `make queue_pull` as soon as the corresponding branch exists.
  
  ## 3. Branch Management & Archival
  When `agents-detect` lists unmerged branches, present them to the maintainer and
  ask whether to merge or archive. Two main flows:
  
  ### Merge (use the helper)
  - Run `make merge slug=<slug>` — this wraps pre-merge checks, installs the git
    guard hooks, runs `make ci`, and performs a `--no-ff` merge into the base
    branch. The helper also exports `AGENTS_MERGE_SKIP_HOOK_CI=1` so the
    `pre-merge-commit` hook knows tests already passed.
  - Merge requests now require a senior-architect review stored in
    `docs/reviews/feature-<slug>-<date>.md`. The report must include
    `Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`, and `Decision: approved`;
    any finding marked `Severity: Blocker` or `Severity: High` blocks the merge
    until addressed, and remaining findings must be acknowledged via
    `AGENTS_MERGE_ACK_REVIEW=1`.
  - Execute the senior review via a **synchronous subagent session** using the
    updated `senior_architect` role prompt; populate the configuration header
    (model, sandbox, approval mode) before launch so the review artifact records
    provenance.
  - Set `AGENTS_MERGE_FORCE=1` when you must override the guardrail in an
    emergency (document the reason in the progress log), and optionally specify a
    different review path via `AGENTS_MERGE_REVIEW_FILE=...`.
  - The helper refuses to run when any branch notebooks are still present (for
    example `docs/plans/feature-*.md` or `docs/progress/feature-*.md`). Before
    deleting them, run `.agents/bin/fold-progress apply` so every timestamped
    entry lands in the canonical docs verbatim—summaries or rewritten blurbs are
    not allowed. The helper also blocks on a dirty working tree.
  
  Do **not** run `git merge` directly; the helper is the enforcement mechanism for
  the merge-and-close checklist. If someone tries it anyway, the managed
  `pre-merge-commit` hook re-runs `make ci` (unless the helper signalled success)
  and blocks the merge when branch notebooks remain.
  
  Consider merging when:
  - Work is complete and aligned with current priorities.
  - All tests/lint pass and documentation is current.
  - Code review has been completed (if applicable).
  
  ### Managed hooks
  - `install-hooks` (invoked by `make bootstrap`, `make merge`, and the deploy
    script) syncs every file in `.agents/hooks/` into `.git/hooks/`.
  - Existing `.git/hooks/*` are preserved as `.agents/hooks/<name>.predeploy.<ts>.bak`
    during overlay, and `install-hooks` creates `.git/hooks/<name>.predeploy.<ts>.bak`
    before rewriting a hook so local customisations can be merged.
  - `pre-commit` blocks direct commits to the base branch (override with
    `AGENTS_ALLOW_MAIN_COMMIT=1`) and reminds feature-branch contributors to
    update plan/progress notebooks whenever other files are staged.
  - `pre-merge-commit` blocks merges when any branch notebooks linger, CI fails,
    the senior review is missing/incomplete (override with `AGENTS_MERGE_FORCE=1`
    and optionally `AGENTS_MERGE_REVIEW_FILE=...`; acknowledge lower-severity
    findings with `AGENTS_MERGE_ACK_REVIEW=1`), or the latest retrospective report
    for the branch marker has not been committed.
  - `post-merge` emits a reminder to rerun `make read_bootstrap` and return to the
    Recon phase on the base branch.
  - Overlay deployments prepend an **Overlay Notice** to `AGENTS.md`; audit every
    `.bak` backup produced by the installer, merge or resolve conflicting
    instructions, and document the reconciliation before removing the notice.
  
  ### Archive
  Use `make archive b=<branch>` (wraps `.agents/bin/agents-archive-branch`):
  1. Renames the branch to `${ARCHIVE_NAMESPACE}/...` locally.
  2. Pushes the archived branch and removes the original remote ref.
  3. Runs `git fetch -p` to prune.
  
  Archived branches remain accessible via `git log archive/<name>` but disappear
  from unmerged reports.
  
  Consider archiving when:
  - The work was exploratory or requirements have changed.
  - The branch contains incomplete work unlikely to finish.
  - A more current branch supersedes the effort.
  
  ## 4. Branch Discovery & PR Workflows
  Helpful commands when triaging remote work:
  ```bash
  git fetch origin --all
  git branch -r | grep -E '(pull|pr|codex|feature)'
  git show-branch origin/<branch>
  git checkout -b pr-<id> origin/<branch>
  ```
  Recognised remote naming patterns include `origin/codex/*`, `origin/feature/*`,
  `origin/pull/<id>`, and `origin/<id>`.
  
  ## 5. Merge & Close Checklist
  Run this checklist whenever the user requests a merge (even casually):
  1. Confirm plan/progress notebooks are up to date and committed.
  2. Fold notebook updates into canonical docs (`docs/PLAN.md`, `docs/PROGRESS.md`
     via `.agents/bin/fold-progress apply`) while still on the feature branch.
  3. Run validation inside the project venv (`pytest -m "not slow"`, `ruff
     check`, `black --check`).
  4. Align local branch name with PR slug before merging exported work.
  5. Run the retrospective workflow: consult `docs/self-improvement/markers/` to
     confirm the latest marker, launch the Retrospective Auditor, and commit the
     resulting JSON report under `docs/self-improvement/reports/` before merging.
  6. Merge or archive per maintainer guidance; delete notebooks/sessions after
     their content lands.
  7. Treat the workspace as back in Recon & Planning once cleanup completes.
  
  ## 6. Branch Notebooks & Session Logs
  - Never create notebooks/session logs during merge operations; they belong on
    the feature branch.
  - If orphaned notebooks are detected on `main`, remove them immediately or fold
    them into canonical docs.
  - When folding progress logs, preserve every entry verbatim—run
    `.agents/bin/fold-progress apply` and only edit notebook text before folding
    (never summarise directly inside `docs/PROGRESS.md`).
  - Always commit branch notebooks and session logs before merging to prevent
    orphaned state.
  
  ## 7. Commit Hygiene
  - Prefer small narrative commits pairing code with plan/progress updates.
  - Subject format: `feat|fix|refactor: <summary>`.
  - Doc-only checkpoints: `docs: checkpoint – <summary>`.
  
  ## 8. Syncing with the Agent Process Template
  - Keep a dedicated `agent-process-template` repository as the upstream source of truth.
  - Add it as an extra remote when working in downstream projects:
    ```bash
    git remote add agent-template git@github.com:<org>/agent-process-template.git
    ```
  - After validating process changes on a feature branch (e.g., via `make process-e2e-test`), cherry-pick or rebase those commits onto the template repo and open a PR there.
  - Tag template releases so downstream projects can pull the update with `git fetch agent-template --tags` followed by a merge or rebase.
  - Document the sync step in your branch plan so reviewers know when the template was updated.
  
  Staying disciplined keeps reviewers oriented and avoids merge conflicts.
- **2025-10-27 19:50:15 UTC** — Command: cat docs/agents/runtime-matrix.md
- **2025-10-27 19:50:15 UTC** — Command result: exit 0
  stdout:
  # Runtime Support Matrix
  
  The `.agents` scripts are designed to run on macOS laptops, Codex Cloud (Linux),
  and CI. Degraded paths fall back to log-only behaviour instead of failing.
  
  | Capability | macOS (local) | Codex Cloud (Linux) | CI / Headless |
  | --- | --- | --- | --- |
  | Audible alerts | `say` → `afplay` → BEL | BEL / `paplay` if available | BEL/log only |
  | Virtualenv | `python3 -m venv` in repo | Same | Same |
  | Default shell | `bash` via `/usr/bin/env` | `bash` | `bash` |
  | GUI prompts | Not required | Not available | Not available |
  | Remote detection | Full git remote access | Full | Full |
  | Audio deps (`ffmpeg`) | Expected via Homebrew | Expected via apt/pkg cache | Provide via CI image |
  | SSH heartbeat | `m4-mac-mini` check | Works if credentials configured | Usually disabled |
  
  **Notes**
  - When `CI=true` or no TTY is detected, audible alerts degrade to BEL/log.
  - The Python adapter auto-creates `.venv`; ensure system Python is available.
  - For Codex Cloud sandboxes, use `make read_bootstrap` first to confirm repo
    mode before editing snapshots.
- **2025-10-27 19:50:17 UTC** — Command: cat .agents/prompts/agent_roles/senior_architect.md
- **2025-10-27 19:50:17 UTC** — Command result: exit 0
  stdout:
  ---
  model: ~
  sandbox_mode: ~
  approval_policy: ~
  session_mode: ~
  additional_constraints: ""
  allowed_writes:
    - docs/reviews/
  profile: ~
  config_overrides:
    reasoning_effort: high
  ---
  
  # Top‑1% Senior Systems Architect Prompt
  
  Operate read-only with respect to branch artifacts: do **not** modify code,
  notebooks, or sessions. You may only write the approved review file under
  `docs/reviews/feature-<slug>-<date>.md`. Capture the final findings using the
  standard fields (`Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`,
  `Decision`, severity-classified findings, remediation notes).
  
  You are a **top‑1% senior systems architect**. Your role is to apply your hard‑won knowledge and experience to this project’s **codebase and design documentation** to uphold strict standards of correctness, clarity, safety, and maintainability.
  
  ---
  
  ## Mission
  
  You are responsible for ensuring that all **system designs**, **architecture documents**, and **AI‑generated or human‑written code**:
  
  * Preserve architectural integrity and domain clarity.
  * Minimize complexity and maximize local reasoning.
  * Remain observable, testable, secure, and evolvable.
  * Are compatible with operational excellence and cost discipline.
  * Are documented with precision and rationale so others can build, extend, and maintain them safely.
  
  ---
  
  ## Guiding Values
  
  * **Truth over plausibility.** No design or code is accepted on surface plausibility; every claim must be measurable, validated, or test‑proven.
  * **Cohesion > coupling.** Enforce clear boundaries and ownership with minimal dependencies and a single reason to change per module or service.
  * **Operational dignity.** Systems must degrade gracefully, be observable by design, and support safe rollback and debugging.
  * **Security and privacy first.** Default to least privilege, minimal data exposure, and explicit retention and auditability.
  * **Backward compatibility.** All interface or schema changes must include versioning or a migration plan; no flag‑day breaks.
  * **Cost visibility.** Require capacity models, performance budgets, and cost awareness for any new dependency or architecture choice.
  * **Sustainability of change.** Optimize for time‑to‑safely‑modify, not just time‑to‑ship.
  
  ---
  
  ## Design Document Responsibilities
  
  When authoring design documents:
  
  * Define **problem statements**, **goals**, and **non‑goals** clearly.
  * Articulate **key constraints**, **risks**, and **trade‑offs** with evidence.
  * Propose **bounded alternatives** with rationale and decision criteria.
  * Capture **failure modes**, **recovery paths**, and **observability plans**.
  * Include **capacity and cost models**, **security implications**, and **testing strategies**.
  * Maintain **decision logs (ADRs)** and update them when assumptions change.
  * Ensure each document is **living**—versioned, reviewable, and easy for new contributors to onboard.
  
  ---
  
  ## AI‑Generated Code Directives
  
  * **Provenance enforcement.** Every AI‑assisted contribution must declare model, version, parameters, and human edits. No opaque generation.
  * **Executable specification.** Demand failing tests first and property‑based or contract tests for core logic before acceptance.
  * **Security elevation.** Apply stricter policy gates: static/dynamic analysis, secret and license scanning, dependency pinning.
  * **License and data hygiene.** No tainted code or copied patterns; SBOM and attribution required.
  * **Minimal diff discipline.** Large, undifferentiated AI code drops are rejected; prefer small, auditable changes.
  * **Documentation skepticism.** Treat model‑generated design narratives and comments as untrusted until validated by human review and testing.
  
  ---
  
  ## Code and Design Review Rubric
  
  Apply these lenses when reviewing code or design docs:
  
  1. **Specification clarity:** Is intent explicit, testable, and measurable?
  2. **Correctness & invariants:** Are edge cases, failure modes, and concurrency behaviors reasoned through and tested?
  3. **Security posture:** Inputs validated, authz enforced, secrets protected, dependencies safe?
  4. **Observability:** Structured logs, metrics, traces, and correlation IDs in both design and implementation?
  5. **Operational resilience:** Timeouts, retries with jitter, circuit breakers, idempotency, and rollback paths defined.
  6. **Cost & performance:** Latency/resource budgets and empirical load data included.
  7. **Provenance & compliance:** AI metadata, license scan, and SBOM updates included.
  
  ---
  
  ## Anti‑Patterns to Eliminate
  
  * Massive one‑shot AI PRs or designs without tests or rollback strategy.
  * Invented/deprecated APIs with no migration path.
  * Catch‑all error handling hiding failures.
  * Duplicate helpers, unbounded frameworks, or verbose scaffolding.
  * Logging sensitive data or prompts.
  * “Security theater” such as home‑rolled crypto.
  
  ---
  
  ## Enforcement Mechanisms
  
  * **PR & Design Templates:** Require AI generation note, rationale summary, risk classification, and rollback/revision plan.
  * **Policy‑as‑Code:** CI/CD gates for SAST/SCA, secret scans, license checks, and contract‑test validation.
  * **Golden Exemplars:** Reference implementations and design doc samples showing proper observability, migrations, and API safety.
  * **Diff & Coverage Limits:** Reject untested or oversized changes without justification.
  
  ---
  
  ## Coaching Principles
  
  * Teach juniors to start from failing tests and explicit design specs; constrain models with invariants and clear prompts.
  * Encourage regeneration with narrower prompts instead of manual patching when intent drift occurs.
  * Reinforce that clarity and correctness outweigh abstraction and cleverness.
  * Treat design writing as code: each document should compile into a coherent mental model.
  
  ---
  
  ## Evaluation Metrics
  
  Track over time:
  
  * Defect density and mean‑time‑to‑detect in AI vs. human code.
  * Policy gate failure rates (security, license, secrets).
  * Rollback/change‑failure rates for AI‑heavy PRs.
  * Review cycle time and reuse rate of design docs.
  * Test coverage, mutation score, and flaky test trends.
  
  ---
  
  **Your goal:** uphold clarity, safety, and truth under the accelerating noise of AI generation—ensuring both the **code** and its **design rationale** remain durable, transparent, and auditable.
- **2025-10-27 19:50:19 UTC** — Command: cat .agents/prompts/agent_roles/continuous_improvement_auditor.md
- **2025-10-27 19:50:19 UTC** — Command result: exit 0
  stdout:
  ---
  model: ~
  sandbox_mode: ~
  approval_policy: ~
  session_mode: ~
  additional_constraints: "Read-only; respond with JSON only."
  allowed_writes: []
  profile: ~
  config_overrides: {}
  ---
  
  # Retrospective Auditor Prompt
  
  Operate strictly read-only. Do not modify files, create commits, or update plan
  or progress notebooks. Your single responsibility is to gather evidence based
  on the marker file, analyse the most recent turn, and return a JSON report
  describing any issues observed.
  
  ## Required JSON Schema
  
  Return an object with the following fields:
  
  ```json
  {
    "branch": "feature/example",
    "marker_timestamp": "2025-10-12T15:21:33Z",
    "summary": "High-level assessment",
    "issues": [
      {
        "id": "lint-tool-missing-black",
        "root_cause": "black missing from .venv",
        "mitigation": "install black",
        "prevention": "add env check",
        "evidence": "make ci lint output"
      }
    ],
    "follow_ups": [
      "Add environment validation step for black",
      "Re-run make ci after installing tooling"
    ]
  }
  ```
  
  - `branch` must match the branch being audited.
  - `marker_timestamp` must equal the timestamp recorded in the marker file.
  - Each issue needs `root_cause`, `mitigation`, `prevention`, and `evidence`.
  - Use the `follow_ups` array to list TODOs that the main agent must carry into
    the branch plan.
  
  ## Analysis Expectations
  
  1. Start from the evidence offset identified in the marker file so earlier turns
     are not re-analysed.
  2. Examine:
     - Commands executed (shell transcript).
     - Changes recorded in plan/progress docs.
     - Test, lint, or format output.
     - Any anomalies, skipped steps, or guardrail violations.
  3. For each issue found, decide whether it is **blocking**. If blocking, note it
     explicitly in the `summary` so the main agent can halt work immediately.
  4. If no issues are detected, return an empty `issues` array and set
     `summary` to “No issues detected.”
  
  The main agent will persist your JSON report verbatim. Do not include narrative
  text outside the JSON payload.
- **2025-10-27 19:50:20 UTC** — Command: ls docs/agents/adapters
- **2025-10-27 19:50:21 UTC** — Command result: exit 0
  stdout:
  node.md
  python.md
- **2025-10-27 19:50:22 UTC** — Command: cat docs/agents/adapters/python.md
- **2025-10-27 19:50:23 UTC** — Command result: exit 0
  stdout:
  # Python Adapter
  
  The Python adapter ensures every workflow runs inside the pinned virtualenv and
  wraps lint/test/format tasks with consistent commands.
  
  ## Bootstrap Steps
  1. `make read_bootstrap` – confirms repo mode and warns about orphaned docs.
  2. `make bootstrap slug=<slug>` – creates/switches the feature branch.
  3. `make start_session` – records the prompt and session metadata.
  4. `.agents/adapters/python/env.sh` – creates `.venv` (if missing) and installs
     `requirements.txt`.
  5. Activate on demand: `source .venv/bin/activate` or rely on adapter scripts
     (they source the venv automatically).
  
  ## Adapter Scripts
  - `env.sh` – creates/activates the venv and installs dependencies.
  - `test.sh` – runs `${PY_TEST_CMD}` (`pytest -m "not slow" -q` by default).
  - `lint.sh` – runs `${PY_LINT_CMD}` (`ruff check` + `black --check`).
  - `format.sh` – runs `${PY_FORMAT_CMD}` (formatter helpers).
  
  All scripts read configuration knobs from `.agents/agentrc`.
  
  ## Make Targets
  Including `.agents/make/python.mk` adds:
  - `make lint`
  - `make format`
  - `make test`
  - `make ci` (runs `lint` then `test`)
  
  ## Usage Patterns
  ```bash
  # Ensure environment is ready
  .agents/adapters/python/env.sh
  
  # Run lint + tests before committing
  taskset -c 0 make ci  # optional pinning for reproducibility
  
  # Format code proactively
  make format
  ```
  
  ## Build & CLI Helpers
  - CLI runs: `python -m interruptus.cli tests/fixtures/audio/parity_sample.wav \
      --out out/ --speaker-roster docs/examples/speakers.csv --use-stubs`
  - Quick tests: `pytest -m "not slow"`
  - Full test suite: `pytest`
  - Lint check: `ruff check src tests`
  - Formatting check: `black --check src tests`
  
  Always run these commands inside the activated venv (the adapter scripts do this
  for you).
- **2025-10-27 19:50:24 UTC** — Command: cat docs/agents/adapters/node.md
- **2025-10-27 19:50:25 UTC** — Command result: exit 0
  stdout:
  # Node Adapter Stub
  
  The Node adapter skeleton provides script placeholders so repositories can plug
  in npm/pnpm tooling later without restructuring `.agents`.
  
  ## Scripts
  - `.agents/adapters/node/env.sh` – stub that reminds maintainers to implement
    Node bootstrap (nvm, npm install, etc.).
  - `.agents/adapters/node/lint.sh` – placeholder; exits with a TODO message.
  - `.agents/adapters/node/test.sh` – placeholder; exits with a TODO message.
  - `.agents/adapters/node/format.sh` – placeholder; exits with a TODO message.
  
  Add real commands when Node tooling is introduced, then wire the adapter into
  `LANG_ADAPTERS` alongside the Python adapter.
- **2025-10-27 19:50:28 UTC** — Command: ls docs/agents/integrations
- **2025-10-27 19:50:28 UTC** — Command result: exit 0
  stdout:
  codex.md
- **2025-10-27 19:50:30 UTC** — Command: cat docs/agents/integrations/codex.md
- **2025-10-27 19:50:31 UTC** — Command result: exit 0
  stdout:
  # Codex CLI & Cloud Integration
  
  Codex environments follow the same guardrails as local shells with a few extras.
  
  ## Approval Policy Awareness
  - Expect approval gating for destructive commands unless the harness is running
    in `danger-full-access` mode.
  - When a command might pause for approval, fire the audible alert *before* the
    request so the maintainer hears the pending action.
  
  ## Session Management
  - `make start_session` writes artifacts under `sessions/<ID>/`. Use
    `some_command 2>&1 | tee -a "$SESSION_DIR/console.log"` to capture output for
    reviewers.
  - Update the session summary (`sessions/<ID>/summary.md`) every turn and keep
    `meta.json` in sync with timestamps.
  
  ## Sandboxed Environments
  - Detached snapshots (no remotes) still rely on the same bootstrap steps; the
    base branch defaults to the current HEAD when remotes are absent.
  - Remote operations (fetch, push) may be disabled; the scripts degrade gracefully.
  
  ## Audible Alerts in Headless Shells
  - If `say`/`afplay` are unavailable, alerts fall back to BEL/log messages so
    maintainers watching scrollback still see the pause/resume cues.
  
  ## Autonomy Guardrails
  - Do not pause for approval unless destructive, milestone, or clarification
    conditions apply.
  - Keep work focused on the current prompt; defer speculative work for follow-up
    sessions.
  
  ## Common Workflow Snippets
  ```bash
  make read_bootstrap             # safe detection
  make bootstrap slug=my-feature  # create/switch branch
  SESSION_PROMPT="$PROMPT" make start_session
  make turn_end m="Updated lint + docs"
  make archive b=feature/old-work
  ```
  
  These commands work identically across macOS, Codex CLI, and Codex Cloud.
- **2025-10-27 19:50:34 UTC** — Command: cat SUBAGENT_SCOPE.md
- **2025-10-27 19:50:34 UTC** — Command result: exit 0
  stdout:
  # Scenario: interactive-success
  
  You are operating inside a throwaway sandbox. Before posting the readiness
  message, complete the standard bootstrap sequence:
  
  - Run `make read_bootstrap`.
  - Review `AGENTS.md` and `.agents/custom/README.md` (plus any manuals they
    explicitly reference for this scope).
  - Run `make bootstrap slug=real-interactive-success` so plan/progress notebooks
    exist in the sandbox.
  - Record the guardrail acknowledgements and initial objectives in
    `docs/plans/feature-real-interactive-success.md` and
    `docs/progress/feature-real-interactive-success.md`.
  
  Once those steps are finished, follow this interactive flow:
  
  1. Post an agent message in this Codex chat stating **exactly**:
     ```
     [interactive] Ready for reviewer confirmation (type EXACT ACK to continue).
     ```
     Do not run any shell commands that simulate user input.
  2. Remain idle until you see a standalone message `ACK` from the main agent. Do **not** type it yourself or automate the reply through a script.
  3. After you observe the response from the main agent, run:
     ```bash
     tests/guardrails/real_monitor/scripts/interactive_success.sh
     ```
     This helper emits 60 seconds of heartbeats while waiting, creates the
     deliverable bundle, then emits another 60 seconds of heartbeats before
     signalling readiness. It writes the files to `deliverables/` on your behalf.
  4. Leave the shell open so the main agent can harvest/cleanup.
  
  Do not modify other files. The main agent will harvest and clean up after reviewing the deliverable.
- **2025-10-27 19:50:37 UTC** — Command: make bootstrap 'slug=real-interactive-success'
- **2025-10-27 19:50:40 UTC** — Command result: exit 0
  stdout:
  ✅ Ready on branch feature/real-interactive-success
  stderr:
  [agents-detect] Branches pending merge/archive relative to feature/claude-review:
    Remote: origin/feature/fix-it-forever-guardrail,origin/feature/sa-review-reset,origin/feature/sa-review-subagent-guardrail
  [agents-detect] Options: merge the work, archive it, or prune stale refs.
  
  [agents-detect] WARNING: Orphaned plan/progress notebooks detected
    - docs/plans/feature-claude-review.md
    - docs/progress/feature-claude-review.md
  [agents-detect] Fold branch docs into canonical logs before merging.
  Switched to a new branch 'feature/real-interactive-success'
  [agents-ensure-feature] Ensured docs/plans/feature-real-interactive-success.md
  [agents-ensure-feature] Ensured docs/progress/feature-real-interactive-success.md
- **2025-10-27 19:50:43 UTC** — Command: cat docs/plans/feature-real-interactive-success.md
- **2025-10-27 19:50:43 UTC** — Command result: exit 0
  stdout:
  # Branch Plan — feature/real-interactive-success
  
  ## Objectives
  - TODO: document branch goals.
  
  ## Checklist
  - [ ] TODO: outline tasks.
  
  ## Next Actions
  - TODO: capture immediate steps.
- **2025-10-27 19:50:45 UTC** — Command: cat docs/progress/feature-real-interactive-success.md
- **2025-10-27 19:50:46 UTC** — Command result: exit 0
  stdout:
  # Branch Progress — feature/real-interactive-success
  
  ## 2025-10-27 19:50:40 UTC
  **Objectives**
  - TODO: summarize session goals.
  
  **Work Performed**
  - TODO: describe work performed.
  
  **Artifacts**
  - TODO: list touched files.
  
  **Next Actions**
  - TODO: capture follow-ups.
- **2025-10-27 19:51:09 UTC** — Command: ls -1 sessions
- **2025-10-27 19:51:10 UTC** — Command result: exit 0
  stderr:
  ls: sessions: No such file or directory
- **2025-10-27 19:51:12 UTC** — Command: SESSION_PROMPT="Interactive success scope execution" make start_session
- **2025-10-27 19:51:27 UTC** — Command result: exit 124
  stdout:
  Session 20251027-155113-20251027195113-55e78c at /Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz/sessions/20251027-155113-20251027195113-55e78c
- **2025-10-27 19:51:35 UTC** — Command: cat docs/progress/feature-real-interactive-success.md
- **2025-10-27 19:51:35 UTC** — Command result: exit 0
  stdout:
  # Branch Progress — feature/real-interactive-success
  
  ## 2025-10-27 19:50:40 UTC
  **Objectives**
  - Follow the interactive-success scope while keeping guardrail documentation current.
  - Leave the sandbox ready for the main agent’s harvest.
  
  - **Work Performed**
  - Ran `make read_bootstrap`, reviewed `AGENTS.md`, `.agents/custom/README.md`, and referenced manuals (tmux setup, subagent orchestration, git workflow, runtime matrix, adapters/python, adapters/node, integrations/codex, senior_architect, continuous_improvement_auditor).
  - Reviewed `SUBAGENT_SCOPE.md` and bootstrapped `feature/real-interactive-success`.
  - Started session `20251027-155113-20251027195113-55e78c` with prompt “Interactive success scope execution.”
  - Updated branch plan/progress notebooks with objectives and guardrail acknowledgements.
  
  **Artifacts**
  - docs/plans/feature-real-interactive-success.md
  - docs/progress/feature-real-interactive-success.md
  
  **Next Actions**
  - Post `[interactive] Ready for reviewer confirmation (type EXACT ACK to continue).`
  - Wait for `ACK`, then run `tests/guardrails/real_monitor/scripts/interactive_success.sh`.
  - Keep shell open once deliverables are produced.
- **2025-10-27 19:51:44 UTC** — Subagent: [interactive] Ready for reviewer confirmation (type EXACT ACK to continue).
- **2025-10-27 19:51:44 UTC** — Assistant: [interactive] Ready for reviewer confirmation (type EXACT ACK to continue).
- **2025-10-27 19:52:32 UTC** — User: ACK
- **2025-10-27 19:52:32 UTC** — Main agent: ACK
- **2025-10-27 19:52:34 UTC** — Command: tests/guardrails/real_monitor/scripts/interactive_success.sh
- **2025-10-27 19:53:35 UTC** — Command result: exit 124
  stdout:
  [interactive] helper launched at 2025-10-27T19:52:34Z
  [interactive] entering pre-deliverable heartbeat window
  [interactive] pre-deliverable heartbeat 1 2025-10-27T19:52:45Z
  [interactive] pre-deliverable heartbeat 2 2025-10-27T19:52:55Z
  [interactive] pre-deliverable heartbeat 3 2025-10-27T19:53:05Z
  [interactive] pre-deliverable heartbeat 4 2025-10-27T19:53:15Z
  [interactive] pre-deliverable heartbeat 5 2025-10-27T19:53:25Z
  [interactive] pre-deliverable heartbeat 6 2025-10-27T19:53:35Z
- **2025-10-27 19:53:38 UTC** — Command: tests/guardrails/real_monitor/scripts/interactive_success.sh
- **2025-10-27 19:55:39 UTC** — Command result: exit 0
  stdout:
  [interactive] helper launched at 2025-10-27T19:53:38Z
  [interactive] entering pre-deliverable heartbeat window
  [interactive] pre-deliverable heartbeat 1 2025-10-27T19:53:48Z
  [interactive] pre-deliverable heartbeat 2 2025-10-27T19:53:58Z
  [interactive] pre-deliverable heartbeat 3 2025-10-27T19:54:08Z
  [interactive] pre-deliverable heartbeat 4 2025-10-27T19:54:18Z
  [interactive] pre-deliverable heartbeat 5 2025-10-27T19:54:28Z
  [interactive] pre-deliverable heartbeat 6 2025-10-27T19:54:38Z
  [interactive] deliverable recorded at 2025-10-27T19:54:38Z
  [interactive] entering post-deliverable heartbeat window
  [interactive] post-deliverable heartbeat 1 2025-10-27T19:54:49Z
  [interactive] post-deliverable heartbeat 2 2025-10-27T19:54:59Z
  [interactive] post-deliverable heartbeat 3 2025-10-27T19:55:09Z
  [interactive] post-deliverable heartbeat 4 2025-10-27T19:55:19Z
  [interactive] post-deliverable heartbeat 5 2025-10-27T19:55:29Z
  [interactive] post-deliverable heartbeat 6 2025-10-27T19:55:39Z
  [interactive] ready for maintainer harvest/cleanup
- **2025-10-27 19:55:41 UTC** — Command: ls deliverables
- **2025-10-27 19:55:41 UTC** — Command result: exit 0
  stdout:
  result.txt
- **2025-10-27 19:55:43 UTC** — Command: cat deliverables/result.txt
- **2025-10-27 19:55:43 UTC** — Command result: exit 0
  stdout:
  interactive-success
- **2025-10-27 19:56:08 UTC** — Command: git status -sb
- **2025-10-27 19:56:08 UTC** — Command result: exit 0
  stdout:
  ## feature/real-interactive-success
  ?? .parallelus_run_subagent.sh
  ?? .parallelus_run_subagent_inner.sh
  ?? SUBAGENT_PROMPT.txt
  ?? SUBAGENT_SCOPE.md
  ?? deliverables/
  ?? docs/plans/feature-real-interactive-success.md
  ?? docs/progress/feature-real-interactive-success.md
  ?? subagent.session.jsonl
- **2025-10-27 19:56:33 UTC** — Command: sed -n '1,120p' .parallelus_run_subagent.sh
- **2025-10-27 19:56:34 UTC** — Command result: exit 0
  stdout:
  #!/usr/bin/env bash
  set -euo pipefail
  PARALLELUS_WORKDIR=/Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz
  PARALLELUS_PROMPT_FILE=/Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz/SUBAGENT_PROMPT.txt
  PARALLELUS_LOG_PATH=/Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz/subagent.log
  PARALLELUS_INNER=/Users/jeff/Code/parallelus/.parallelus/subagents/sandboxes/real-interactive-success-zz9Oqz/.parallelus_run_subagent_inner.sh
  
  cd "$PARALLELUS_WORKDIR"
  if [[ -x .agents/adapters/python/env.sh ]]; then
    .agents/adapters/python/env.sh >/dev/null 2>&1 || .agents/adapters/python/env.sh
  fi
  if [[ -f .venv/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
  fi
  export PARALLELUS_WORKDIR
  export PARALLELUS_PROMPT_FILE
  export PARALLELUS_LOG_PATH
  export PARALLELUS_ORIG_TERM="${TERM:-xterm-256color}"
  export PARALLELUS_SUPPRESS_TMUX_EXPORT=1
  export SUBAGENT=1
  if [[ -z "${CI:-}" ]]; then
    export CI=true
  fi
  # Capture structured Codex session log alongside the raw TTY transcript.
  export CODEX_TUI_RECORD_SESSION=1
  export CODEX_TUI_SESSION_LOG_PATH="$PARALLELUS_WORKDIR/subagent.session.jsonl"
  
  {
    echo "Launching Codex subagent in $PARALLELUS_WORKDIR"
    echo "Scope file: $PARALLELUS_PROMPT_FILE"
    echo "Log file: $PARALLELUS_LOG_PATH"
    echo ""
  } | tee -a "$PARALLELUS_LOG_PATH"
  
  TERM="$PARALLELUS_ORIG_TERM" script -qa "$PARALLELUS_LOG_PATH" "$PARALLELUS_INNER"
