# Parallelus Agent Process

Parallelus is a guardrailed automation framework that keeps human operators and
AI agents aligned while they collaborate on a shared codebase. It wraps your
repository with lightweight checklists, notebooks, and tooling so every turn is
auditable, reproducible, and easy to continue—whether you are working solo,
pairing with an assistant, or delegating to fully automated subagents.

---

## Why Teams Use Parallelus
- **Repeatable delivery** – Enforces a Recon → Planning → Execution cadence so
  every task starts with context gathering and ends with documented outcomes.
- **Built-in governance** – Senior review gates, retrospective prompts, and
  audible alerts keep compliance needs visible without slowing contributors
  down.
- **Onboarding in minutes** – `make bootstrap` scaffolds feature branches with
  ready-to-edit plan/progress notebooks and managed git hooks.
- **AI-native collaboration** – Session logs, guardrails, and adapter configs
  make it safe to hand off work to Codex-based agents or other automated
  contributors.
- **Portable playbook** – Copy the `.agents/` directory and docs into any
  repository to standardise process expectations across projects.

---

## Core Capabilities
- **Guardrail Checklists** – `AGENTS.md` plus detailed manuals capture the
  minimum viable process; helpers such as `make read_bootstrap`, `make bootstrap`
  and `make turn_end` enforce them automatically.
- **Branch Notebooks** – Each feature branch receives `docs/plans/<branch>.md`
  and `docs/progress/<branch>.md`, keeping objectives, checkpoints, and session
  notes co-located with the code.
- **Session Logging** – `make start_session` records turn metadata inside
  `sessions/` so you can audit past work or resume after interruptions.
- **Managed Git Hooks** – Bootstrap installs hooks that block risky actions
  (committing on `main`, merging without a senior review, skipping retrospectives).
- **Adapter-aware Tooling** – Python and Swift adapters ship by default; extend
  `docs/agents/adapters/` to codify language-specific lint, test, or packaging
  flows for your stack.
- **Retrospective Automation** – The Retrospective Auditor prompt produces JSON
  reports stored under `docs/self-improvement/`, closing the loop on process
  improvements.
- **Profile-aware Subagents** – Launch subagents with alternative Codex
  profiles (for example, `gpt-oss`) without editing scripts; non-default
  profiles display in the generated prompt and skip the `--dangerously-bypass`
  sandbox flags when required. Role prompts declare overrides via YAML
  front matter, so model/sandbox/approval tweaks stay alongside human
  instructions.

---

## Workflow at a Glance
1. **Recon & Planning (read-only)**  
   Run `make read_bootstrap`, open branch notebooks, list recent sessions, and
   confirm you are ready to continue.
2. **Transition to Editing**  
   Execute `make bootstrap slug=<slug>` to enter a feature branch, set a
   `SESSION_PROMPT`, and update plan/progress notebooks with current goals.
3. **Active Execution**  
   Implement changes, fire `.agents/bin/agents-alert` before/after work blocks,
   run verification (`make ci`, language-specific adapters), and log checkpoints.
4. **Turn-End & Session Wrap**  
   Launch the Retrospective Auditor, record the output under
   `docs/self-improvement/reports/`, then run `make turn_end m="summary"` to
   sync plan/progress docs and session metadata.

Every stage references the manuals in `docs/agents/` for deeper context when a
gate (merge, diagnostics, subagents, etc.) triggers.

---

## Getting Started

### Prerequisites
- macOS or Linux shell with `make`, Python 3.11+, and Swift toolchain (if you
  plan to use the Swift adapter).
- Access to the LLM or automation platform that will run the Codex agent (e.g.,
  OpenAI’s Codex CLI).
- tmux 3.x or newer. Parallelus relies on tmux to multiplex the main agent and
  subagents; if tmux is missing you can still launch subagents manually, but the
  automated panes/windows and status overlays will not be available.
  - `make read_bootstrap` automatically sources `.agents/tmux/parallelus-status.tmux`
    whenever tmux is available. Set `PARALLELUS_SUPPRESS_TMUX_EXPORT=1` before running
    the command to skip this if you prefer a neutral tmux config.
  - To keep Parallelus panes isolated from personal tmux sessions, launch Codex on
    a dedicated socket (e.g. `tmux -L parallelus …`) or add a conditional
    `if-shell` to your own `~/.tmux.conf` that only loads the overlay when
    `.agents/tmux/parallelus-status.tmux` exists in the current repository.
  - When tmux truly isn’t an option, launch subagents with
    `subagent_manager.sh launch --launcher manual …` and follow the printed
    command in a regular terminal.
- Optional: GitHub or another Git remote for publishing.

### New Project Setup
1. **Create the repository** – Initialise an empty git repo and copy this
   project (or add it as a template) to inherit the Parallelus scaffolding.
2. **Install dependencies** – Run `python -m venv .venv && source .venv/bin/activate`
   followed by `pip install -r requirements.txt`. Add Swift package dependencies
   if the Swift adapter is enabled.
3. **Bootstrap your first branch** – From a clean tree, run
   `make bootstrap slug=intro` to create `feature/intro`, seed notebooks,
   and install managed hooks.
4. **Start a session** – `SESSION_PROMPT="Initial setup" make start_session`
   records the work context under `sessions/`.
5. **Log your objectives** – Update
   `docs/plans/feature-intro.md` and `docs/progress/feature-intro.md` with the
   goals outlined in AGENTS.md.
6. **Wire your tmux session (optional)** – The status bar overlay is applied
   automatically by `make read_bootstrap`, but you can scope it to Parallelus
   sessions by launching Codex on a dedicated socket and/or sourcing the file
   conditionally in `~/.tmux.conf`. Example:
   ```tmux
   if-shell '[ -f .agents/tmux/parallelus-status.tmux ]' \
     "source-file .agents/tmux/parallelus-status.tmux"
   ```

### Adopting Parallelus in an Existing Repository
1. **Bring in the framework** – Copy the `.agents/` directory, `Makefile`
   targets (`read_bootstrap`, `bootstrap`, `turn_end`, `ci`), and top-level docs
   (`AGENTS.md`, `docs/agents/`, `docs/self-improvement/`) into your repo.
   Committing these scaffolds creates the baseline process. The helper
   `.agents/bin/deploy_agents_process.sh` automates this copy/sync step across
   multiple repositories if you prefer a scripted workflow.
2. **Wire command aliases** – Ensure project-specific scripts referenced in
   the manuals exist (e.g., environment diagnostics, CI entry points). Update
   adapter configs whenever your tooling differs.
3. **Run `make read_bootstrap`** – Verify detection paths and adjust
   `.agents/agentrc` if the base branch or remote naming conventions differ.
4. **Train contributors** – Walk the team through Recon → Planning → Execution,
   highlight the guardrails (audible alerts, plan/progress updates, senior
   reviews), and capture buy-in in your progress logs.
5. **Backfill retrospectives (optional)** – If you want historical coverage,
   run the Retrospective Auditor on recent features and store the JSON reports
   alongside new work.

### Daily Cadence
- Start each session in Recon, review the plan, and seed a session directory.
- Update notebooks whenever you complete a meaningful work unit; the managed
  `pre-commit` hook will remind you if you forget.
- Use `make ci` (or adapter-specific equivalents) before requesting review.
- When work is ready, follow the merge gate: senior architect review,
  retrospective report, plan/progress cleanup, then `make merge slug=<slug>`.

### Codex Launch Helpers
- Many teams wrap the Codex CLI in shell helpers so every session starts inside
  tmux with a clean environment. To isolate Parallelus panes, run those helpers
  on a dedicated socket (here `parallelus`) and let the notebook bootstrap load
  the status overlay automatically:
  ```sh
  cx() {
    local CLEAN_PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
    TMUX= tmux -L parallelus -f /dev/null \
      new-session -As codex-$(basename "$PWD") \
      -e PATH="$CLEAN_PATH" \
      -- codex --dangerously-bypass-approvals-and-sandbox --search "$@"
  }
  ```
  A companion `cxr()` can call `codex resume` inside the same tmux session.
  With Parallelus installed, these helpers keep the main agent and subagents
  in predictable panes, ensure the tmux status overlay is active, and avoid
  environment drift between runs. Feel free to adapt the example above to your
  local shell configuration.

### Role Prompts & Front Matter
- Each subagent role prompt starts with YAML front matter describing runtime
  overrides (model, sandbox mode, approval policy, profile, etc.). Leave
  values as `~` (null) or the string `default` to inherit the main-agent
  configuration; set explicit values to override.
- Use the `config_overrides` map to pass Codex `-c key=value` options (values
  are JSON encoded automatically) for extra knobs such as
  `reasoning_effort`.
- Launch subagents with `--role <prompt-name>` to apply the front-matter
  overrides automatically. Example: `subagent_manager.sh launch --role
  senior_architect --profile gpt-oss ...`.
- Front-matter overrides appear at the top of `SUBAGENT_PROMPT.txt` so humans
  can confirm the effective model/sandbox, and the registry records the chosen
  profile for later verification.

### Guardrail Configuration (`.agents/agentrc`)
- `REQUIRE_CODE_REVIEWS` (default `1`) enforces senior architect review; the
  specific prompt is defined by `CODE_REVIEW_AGENT_ROLE` (default
  `senior_architect`).
- `REQUIRE_AGENT_CI_AUDITS` (default `1`) enforces the continuous improvement
  audit; the prompt is selected via `AGENT_CI_AGENT_ROLE` (default
  `continuous_improvement_auditor`). Temporarily export
  `AGENTS_RETRO_SKIP_VALIDATE=1` if you must bypass the check (document the
  rationale in the progress log).
- `AUDIBLE_ALERT_VOICE` and `AUDIBLE_ALERT_REQUIRE_TTY` control how
  `.agents/bin/agents-alert` emits notifications when running in a tmux/non-TTY
  session.

---

## Directory Overview
- `AGENTS.md` – Core guardrails that govern every session.
- `.agents/` – Automation helpers, managed git hooks, adapter configs, and
  process prompts.
- `docs/agents/` – Manuals covering core workflow, git guardrails, runtime
  expectations, integrations, and project-specific context.
- `docs/plans/` & `docs/progress/` – Branch notebooks created by `make bootstrap`
  and updated at every checkpoint.
- `docs/self-improvement/` – Retrospective markers and JSON reports produced by
  the auditor prompt.
- `sessions/` – Turn-by-turn session metadata generated by `make start_session`.
- `src/`, `tests/` – Example application code (Interruptus) showcasing how the
  process applies to a real project.

---

## Documentation & Support
- **Start here:** [AGENTS.md](./AGENTS.md)  
  Summary of mandatory guardrails; read at the beginning of every session.
- **Manuals:** [docs/agents/](./docs/agents/)  
  Detailed guides for core workflow, git operations, adapters, integrations,
  and domain-specific context.
- **Project roadmap:** [docs/PLAN.md](./docs/PLAN.md)  
  Maintainer-owned, updated after each merge to capture long-term direction.
- **Progress log:** [docs/PROGRESS.md](./docs/PROGRESS.md)  
  Aggregated history stitched from branch notebooks at feature completion.

Have questions or want to contribute improvements to the process? Open an issue
or start a discussion once the repository is published, and document any
changes to the guardrails inside the plan/progress notebooks so future
contributors inherit the updates.
