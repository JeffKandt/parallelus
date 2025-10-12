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

### Adopting Parallelus in an Existing Repository
1. **Bring in the framework** – Copy the `.agents/` directory, `Makefile`
   targets (`read_bootstrap`, `bootstrap`, `turn_end`, `ci`), and top-level docs
   (`AGENTS.md`, `docs/agents/`, `docs/self-improvement/`) into your repo.
   Committing these scaffolds creates the baseline process.
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
