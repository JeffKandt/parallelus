# Agents Documentation Index

This directory hosts the reorganised agent guidance referenced from `AGENTS.md`.

- `core.md` – phases, guardrails, audible alerts, checkpoint cadence (manual; read when you need elaboration beyond `AGENTS.md`).
- `git-workflow.md` – repository detection, branching, archival, merge closure.
- `docs/agents/manuals/runtime-matrix.md` – environment support (macOS, Codex, CI/headless).
- `docs/agents/manuals/integrations/` – platform-specific notes (Codex CLI/Cloud, others later).
- `adapters/` – language/tooling adapters (Python implemented, Node stub).
- `docs/agents/manuals/` – index of operational manuals and their trigger conditions.
- `project/` – repository-specific domain context (this repo: Interruptus).
- `../reviews/` – permanent senior architect review archive consumed by merge
  guardrails.

Each document is portable: copy the `core/` + `git-workflow/` basics to other
repos, then plug in project-specific adapters and context as needed.
