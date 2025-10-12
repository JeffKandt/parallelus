# Parallelus Agents Directory

This directory packages the automation that keeps the Parallelus agent workflow portable across local machines, Codex sandboxes, and CI. Use this README as a map when you need to understand or extend the support scripts.

## Top-Level Layout
- `agentrc` – central configuration (paths for plans/progress/session logs, adapter list, git defaults, alert text).
- `adapters/` – language-specific helpers (`python`, `node`, `swift`) with `env.sh`, `lint.sh`, `test.sh`, and formatter shims.
- `bin/` – executable guardrails (`agents-detect`, `agents-ensure-feature`, `agents-session-start`, etc.) plus orchestration utilities like `launch_subagent.sh`.
- `hooks/` – managed git hooks (`pre-commit`, `pre-merge-commit`, `post-merge`).
- `config/` – role configuration files (e.g., `senior_architect.yaml`,
  `agent_auditor.yaml`) consumed by prompt headers.
- `make/` – GNU Make fragments wired into the root `Makefile` (general agents targets and language additions).
- `prompts/` – templates for smoke prompts and scope text used by automation.
- `tests/` – smoke test harness (`smoke.sh`) that exercises the critical helpers.
- `../docs/reviews/` (in the repo root) stores approved senior architect
  reports referenced by the merge guardrails.

## Key Executables (`bin/`)
- `agents-detect` – detects repo mode, branch status, orphaned notebooks; wrapped by `make read_bootstrap`.
- `agents-ensure-feature` – enforces feature-branch creation and notebook scaffolding (`make bootstrap slug=<slug>`).
- `agents-session-start` – provisions session directories (`sessions/<ID>/`), meta files, and prompt snapshots; used by `make start_session`.
- `agents-turn-end` – checkpoint helper invoked via `make turn_end m="..."`.
- `retro-marker` – records `docs/self-improvement/markers/<branch>.json` after
  each turn so retrospective auditors know where to resume analysis.
- `agents-archive-branch` / `agents-merge` – guardrailed archival and merge flows; do not call raw git commands instead.
- `deploy_agents_process.sh` – installs or refreshes this agents toolkit in downstream repos via `./deploy_agents_process.sh --repo <path>`.
- `install-hooks` – synchronises `.agents/hooks/` into `.git/hooks/`; called by bootstrap, merge, and deployment flows.
- `process_self_test.sh` – runs internal validation against a target repo to confirm bootstrap steps succeed.

## Adapter Notes (`adapters/`)
Each adapter subfolder exposes consistent `env.sh`, `lint.sh`, `test.sh`, and `format.sh` commands. The Python version is fully implemented; Node and Swift are stubs ready for project-specific wiring.

## Makefile Integration (`make/`)
Include `.agents/make/agents.mk` (already done in this repo) to access `make read_bootstrap`, `make bootstrap`, `make start_session`, `make turn_end`, `make archive`, and `make merge`. Language-specific make fragments (e.g., `python.mk`) add `make lint`, `make test`, and `make ci` wrappers.

## Deploying the Agents Toolkit
1. Clone or update the repository that needs the Parallelus guardrails.
2. Run `.agents/bin/deploy_agents_process.sh --repo <target-path>` from this directory (or use the repo root wrapper if present).
3. Follow the emitted instructions to add the make fragments, configuration, and git hooks.
4. Execute `make read_bootstrap` in the target repo to confirm the installation succeeded.

Keep this README up to date as the toolchain evolves so maintainers can onboard quickly.
