# Superpowers + Beads — Discussion Notes (Working Draft)

This note records a high-level comparison between Parallelus, Beads, and Superpowers, and captures possible future integration ideas. It is informational only; no integration is planned yet.

For a concrete Beads recommendation (augmenting notebooks, preferred operating
mode, and adoption plan), see `docs/agents/integrations/beads.md`.

## Beads (Task Graph / Issue Ledger)

Beads stores a structured task ledger in a dedicated namespace (e.g., `.beads/`) and supports dependency graphs, status tracking, and multiple operating modes.

**Potential value for Parallelus**
- A structured task graph could complement branch plans by providing a queryable backlog with dependencies.
- A “stealth/local” mode aligns with the desire to keep some tracking outside the repo or outside PR diffs.
- A “shared branch” data model could allow cross-branch visibility into task state without forcing every work branch to carry task files.

**Risks/concerns**
- Adding a second task system risks confusion unless roles are clearly separated (e.g., Beads for backlog, notebooks for branch execution logs).
- A sync-branch approach adds operational complexity and is easy to get wrong without tooling support.

## Superpowers (Process / Phase Enforcement)

Superpowers emphasizes explicit planning, TDD, subagents, and phase gates (e.g., design → implement → test → review). Worktrees are used for isolation and workflow structure.

**Potential value for Parallelus**
- Intra-branch phase gates could make execution more consistent (plan → execute → test → review).
- A worktree-first approach could reduce cross-talk between tasks.
- “Methodology as guardrail” fits Parallelus’ enforcement mindset.

**Risks/concerns**
- Parallelus already uses worktrees and subagents; adding another layer of enforcement can slow iteration if not optional.
- Hard TDD gates may not be appropriate for all projects.

## Hybrid Possibilities (Future Exploration)

- Keep narrative plan/progress notebooks as the primary execution log, but optionally **link to Beads IDs** for structured backlog tasks.
- Introduce **optional phase gates** (plan → implement → test → review) that can be toggled per repo or per branch.
- Add a “worktree mode” flag that makes worktree the default for subagent work (for those who want that style).

## Open Questions

- Should Beads be used only for long-term backlog, or also for branch-local tasks?
- If Beads is used, is a shared “beads branch” worth the operational overhead?
- Which phase gates would add value without harming throughput?

## Upstream Watchlist & Update Policy (Proposed)

Maintain a lightweight “watchlist” so upstream changes can be reviewed on a predictable cadence without forcing adoption.

**Watchlist entries**
- **Beads**
  - Source: https://github.com/steveyegge/beads
  - Current stance: observe; no integration
  - Review cadence: quarterly or when a major release introduces new workflow modes
  - Notes to track: data layout changes, sync-branch changes, new automation hooks
- **Superpowers**
  - Source: https://github.com/obra/superpowers
  - Current stance: observe; no integration
  - Review cadence: quarterly or when the workflow model changes materially
  - Notes to track: phase-gate additions, worktree/subagent orchestration changes

**Update policy**
1. Log upstream changes (version/commit + short summary) in this file.
2. Decide whether changes are informational only or require a Parallelus experiment.
3. If experimenting, do it on a feature branch and document outcomes in the branch progress log.
4. Only adopt changes when they map to a clear pain point and do not add operational fragility.
