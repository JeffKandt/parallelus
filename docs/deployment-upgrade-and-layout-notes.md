# Deployment, Upgrades, and Layout Notes (Working Draft)

This note captures current findings and open decisions about deploying the Parallelus agent process into an existing repository and upgrading it over time.

## Overlay / Upgrade Safety

### `--overlay-upgrade` risk profile

`--overlay-upgrade` is designed as a “fast refresh” path (overlay mode, requires a clean working tree, disables `.bak` backups, and proceeds without an interactive stop).

That makes it **risky** for files that are expected to accumulate project-specific customizations, especially `AGENTS.md` and (depending on adoption) the Makefile integration.

### Proposed direction: split upstream vs project-specific guardrails

If `AGENTS.md` is treated as upstream-managed, upgrades are safer if project-specific instructions live elsewhere.

One workable pattern:
- `AGENTS.md` (upstream-managed; safe to overwrite)
- `PROJECT_AGENTS.md` or `AGENTS.project.md` (project-specific; preserved across upgrades)
- `AGENTS.md` links to the project file and clearly instructs maintainers to edit only the project file.

### AGENTS.md customization policy (proposed)

- **Do not customize** `AGENTS.md` directly.
- Place project-specific guardrails in `PROJECT_AGENTS.md` (or `AGENTS.project.md`) and reference it from `AGENTS.md`.
- During initial overlay into an existing repo, move any existing `AGENTS.md` content into the project-specific file, then install the upstream `AGENTS.md`.
- During upgrades (especially `--overlay-upgrade`), refresh `AGENTS.md` freely and preserve the project-specific file.

Deployment/overlay behavior:
- On first overlay into an existing repo: if a pre-existing `AGENTS.md` is detected and differs, rename/move it to `PROJECT_AGENTS.md` (if not present) and install the upstream `AGENTS.md`.
- On upgrade: refresh upstream `AGENTS.md` freely, preserve the project file.

### Other potentially risky upgrade surfaces
- `Makefile`: the deploy script rewrites the “agent-process integration” block in-place (no `.bak` handling today).
- `.gitignore`: appended entries are low-risk but still a policy change.
- `.git/hooks`: existing hooks are backed up under `.agents/hooks/*.predeploy.*.bak`, but local workflows may be sensitive to hook changes.
- `docs/*` collisions: overlay refreshes `docs/agents/` and always refreshes `docs/reviews/README.md`; other review files are preserved.

## Deployment Parity Gaps (Status)

The deploy script now scaffolds canonical `docs/PLAN.md`, `docs/PROGRESS.md`, and `docs/self-improvement/` (including `.gitkeep` files for `markers/`, `reports/`, and `failures/`), and optionally copies helper scripts when the target Makefile references them. Remaining parity work is focused on:
- deciding whether to split tracked process docs into a namespaced folder (`docs/parallelus/…`)

## Tracked Process vs Runtime Artifacts

### Tracked process artifacts
Versioned, reviewable artifacts that define or evidence the workflow:
- upstream process guardrails and tooling (`AGENTS.md`, `.agents/`, `docs/agents/`)
- canonical project process logs (`docs/PLAN.md`, `docs/PROGRESS.md`)
- review and retrospective evidence (`docs/reviews/…`, `docs/self-improvement/…`)
- branch notebooks if the workflow keeps them tracked during active work (`docs/plans/…`, `docs/progress/…`)

### Runtime artifacts
Machine-local or high-churn outputs that should not live in PR diffs:
- subagent sandboxes/worktrees, transient logs, monitor snapshots, temp files
- local session console capture

One possible convention:
- `.parallelus/` (dot) = runtime only, gitignored
- `parallelus/` (no dot) or `docs/parallelus/` = tracked process namespace (if we decide `docs/` should remain project-doc-focused)

## Layout Options Under Discussion

1. **Keep current layout** (simplest; already supported):
   - Canonical: `docs/PLAN.md`, `docs/PROGRESS.md`
   - Branch notebooks: `docs/plans/<slug>.md`, `docs/progress/<slug>.md`
   - Reviews: `docs/reviews/<slug>-<date>.md`

2. **Group branch artifacts per-branch directory** (more discoverable; requires tooling changes):
   - Branch notebooks: `docs/branches/<slug>/PLAN.md`, `docs/branches/<slug>/PROGRESS.md`
   - Optionally stage review reports under the same branch directory.

3. **Namespaced Parallelus docs** (reduce collision with project docs; requires clearer conventions):
   - Keep canonical `docs/PLAN.md` and `docs/PROGRESS.md` for visibility
   - Move process manuals under `docs/parallelus/…` (or similar)
   - Keep project docs under `docs/` or `docs/project/…`

## TODO Placement (Current Documented Model)

Current documentation points to:
- Branch-local work: branch plan/progress notebooks (checklists + next actions).
- Long-term backlog: `docs/PLAN.md` “Next Focus Areas”.
- Recon scratch/inbox: `.agents/queue/next-branch.md` populated during Recon and “pulled” into the branch plan/backlog when work starts.
