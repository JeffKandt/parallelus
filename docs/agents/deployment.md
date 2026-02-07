# Agents Process Deployment Guide

This guide describes how to transplant the Parallelus agent workflow into a new repository.

## 1. Use the Deployment Script

Run `.agents/bin/deploy_agents_process.sh` to transplant the workflow into another repository. The script can scaffold a brand-new repo or overlay the process onto an existing one.

```
# Create a fresh repository with Python defaults
.agents/bin/deploy_agents_process.sh ~/Code/my-app

# Scaffold a Swift workspace
.agents/bin/deploy_agents_process.sh --name my-swift-app --lang swift ~/Code/my-swift-app

# Overlay onto an existing repository (must be clean unless --force)
.agents/bin/deploy_agents_process.sh --mode overlay --lang python .
```

Key flags:

- `--mode scaffold|overlay` – choose between creating a new repo (default) or layering onto an existing git worktree.
- `--lang LANG` – add one or more language overlays (`python`, `swift`). Repeat the flag to include several overlays; the script updates `.agents/agentrc` and the Makefile snippet accordingly.
- `--verify` – (scaffold only) run a bootstrap + smoke drill and clean up the generated artifacts; skips by default to leave the tree pristine.
- `--force` – allow scaffolding into a non-empty directory or overlaying onto a dirty worktree. Use with care.
- `--overlay-no-backup` – overlay only; skip creating `.bak` files and rely on git history when you already have clean recovery points.
- `--overlay-upgrade` – convenience flag for clean upgrades: implies overlay mode, asserts the target working tree is clean, sets `--overlay-no-backup`, and auto-consents to the overwrite warning.
- `--remote URL` – configure the `origin` remote after initialization.

The script copies the canonical assets (`AGENTS.md`, `.agents/`, `docs/agents/`), scaffolds `docs/PLAN.md`, `docs/PROGRESS.md`, and the `docs/parallelus/self-improvement/` folders, wires the Makefile snippet, updates `.agents/agentrc`, and (for scaffold mode) creates an initial commit. If the target Makefile references optional helper scripts (for example `remember_later` / `capsule_prompt`), the corresponding `scripts/` files are copied when missing. During overlay deployments, any existing `docs/agents/project/` content is preserved so project-specific narratives stay intact; copy new template material in manually if you want to adopt the updates. Overlay mode emits a notice in `AGENTS.md` only when backups are generated; when you opt out of backups (`--overlay-no-backup` or `--overlay-upgrade`), no notice is added. Likewise, overlays refresh only `docs/parallelus/reviews/README.md` so historical project reviews remain untouched.

### AGENTS.md Customization Policy (Recommended)

- Treat `AGENTS.md` as upstream-managed and safe to overwrite during upgrades.
- Store project-specific guardrails in `PROJECT_AGENTS.md` (or `AGENTS.project.md`) and reference that file from `AGENTS.md`.
- For first-time overlays into existing repos, move any customized `AGENTS.md` content into the project-specific file before installing the upstream `AGENTS.md`.
- Avoid editing `AGENTS.md` directly so `--overlay-upgrade` can be used safely.

### Exporting a reusable template repository

To publish a standalone agent process template, run:

```
scripts/export_agent_template.sh dist/agent-process-template
```

Options (set via environment variables):

- `LANG_ADAPTERS` – adapters to include (e.g., `"python swift"`).
- `PROJECT_NAME` – template project name (default `agent-process-template`).
- `VERIFY=1` – run `make read_bootstrap` + `make agents-smoke` inside the export before exiting.
- `FORCE=1` – overwrite an existing target directory.

The command scaffolds a ready-to-publish repo under `dist/agent-process-template/`. Initialise a new remote (`git init`, `git remote add`, `git push`) to make it available to other projects or mark it as a GitHub Template Repository.

## 2. Manual Copy (Advanced/Offline)

When automation is unavailable, perform the steps manually:

1. Copy the following into the destination root:
   - `AGENTS.md`
   - `.agents/` (entire directory)
   - `docs/agents/` tree
   - `docs/PLAN.md` and `docs/PROGRESS.md` (scaffold if missing)
   - `docs/parallelus/self-improvement/` (`README.md`, `markers/`, `reports/`, `failures/`)
   - Create `docs/branches/` for per-branch notebooks (`<slug>/PLAN.md`, `<slug>/PROGRESS.md`)
   - Create an empty `sessions/` directory
2. Update `.agents/agentrc` for the new project (`PROJECT_NAME`, `DEFAULT_BASE`, `LANG_ADAPTERS`, etc.).
3. Add the Makefile integration (see snippet below) and install the `pre-merge-commit` hook.
4. If your Makefile references helper scripts (for example `remember_later` / `capsule_prompt`), copy the relevant `scripts/` helpers into the repo.
5. Run the verification drill described in §4 to confirm everything works.

## 3. Makefile Integration Snippet

If you integrate manually, include the following block in the target repo’s `Makefile` (the deployment script drops the same block between `agent-process` markers):

```make
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
AGENTS_DIR ?= $(ROOT)/.agents
LANG_ADAPTERS ?= python

include $(AGENTS_DIR)/make/agents.mk
ifneq (,$(findstring python,$(LANG_ADAPTERS)))
include $(AGENTS_DIR)/make/python.mk
endif
ifneq (,$(findstring swift,$(LANG_ADAPTERS)))
include $(AGENTS_DIR)/make/swift.mk
endif
```

Add additional `ifneq` blocks as you create new adapters.

## 4. Verify in the Destination Repo

1. **Bootstrap drill:**
   ```bash
   eval "$(make start_session)"
   make bootstrap slug=smoke-test
   SESSION_PROMPT="Smoke test" eval "$(make start_session)"
   make turn_end m="initial checkpoint"
   ```
   Confirm branch notebooks appear under `docs/branches/<slug>/PLAN.md` and `docs/branches/<slug>/PROGRESS.md`.

2. **Smoke test:** `make agents-smoke` exercises detect → branch → session → checkpoint → archive.

3. **Merge guardrail:**
   - Create a dummy change and run `make merge slug=smoke-test`. It should run `make ci`, verify notebooks are gone, and merge into the base branch.
   - Run `git merge` manually with branch notebooks present; the `pre-merge-commit` hook should block the merge.

Remove `feature/smoke-test` and any generated notebooks once the drill succeeds.

### Interactive validation via subagent harness

Run `make process-e2e-test` to spin up a throwaway sandbox and launch an
interactive subagent in a separate terminal. The harness uses
`.agents/bin/subagent_manager.sh` to prepare the sandbox, prints the relevant paths,
and then waits for you to return once the subagent completes the checklist.
After you confirm completion, the harness verifies the sandbox via
`subagent_manager.sh verify/cleanup`.

```
make process-e2e-test
```

Environment variables:

- `SCOPE_TEMPLATE` – scope file copied into the sandbox (default
  `.agents/prompts/process_smoke.txt`).
- `SUBAGENT_LAUNCHER` – override launcher selection (auto, iterm-window,
  terminal-window, tmux, manual).
- `KEEP_SANDBOX` – set to `1` to retain the sandbox after verification.

This interactive flow replaces the older Codex `exec` harness for now. Once
non-interactive execution is stable again, the legacy mode can be re-enabled by
adapting `.agents/bin/process_self_test.sh` and `.agents/bin/subagent_manager.sh` to use
`codex exec` instead of an interactive launch.

## 5. Team Onboarding Checklist

- Share `AGENTS.md` and emphasise that it *and all referenced docs* are mandatory reading at session start.
- Provide a “first session” script (e.g., `make read_bootstrap` → `make bootstrap slug=<slug>` → `make start_session`).
- Document how to install the local hooks (copy `.agents/hooks/pre-merge-commit` or run `make merge` once).
- Encourage running `make ci` before every merge to catch regressions and exercise the smoke suite.

## 6. Optional Enhancements

- Add repository-specific adapters under `.agents/adapters/` (Go, Rust, etc.).
- Wire the smoke harness into CI to catch regressions automatically.
- Extend the merge helper to push to remote branches or open PRs if required by your workflow.

Whether you use the deployment script or copy the assets manually, following these steps gives the destination project the same guardrails, documentation, and enforcement used in Parallelus.
