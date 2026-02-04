# Beads (bd) Integration Recommendation

This document captures whether and how **Beads** (`bd`) should be integrated
into Parallelus, based on a `bd --help` deep dive and upstream documentation.

## Recommendation Summary

- **Do not replace** `docs/PLAN.md` and `docs/PROGRESS.md`. **Augment** them.
- Prefer a **single shared Beads store** (one `.beads/issues.jsonl` history) for
  the whole repo, not branch-specific Beads state.
- If Beads is adopted, run it in **sync-branch mode** (a dedicated metadata
  branch, e.g. `beads-sync`) so the backlog can evolve without touching `main`
  and without contaminating feature-branch diffs.

## What Beads Adds (That Parallelus Doesn’t Already Have)

Parallelus plan/progress notebooks are optimized for narrative and governance:
human-readable intent, checkpointing, retrospectives, and merge gates.

Beads adds a *structured* work ledger:
- queryable backlog (`bd ready`, `bd blocked`, `bd list`)
- explicit dependency graph (`bd dep`, `bd graph`, epics/children)
- a git-friendly event history (`.beads/issues.jsonl`) with merge tooling

These capabilities are complementary: Beads is a task graph; notebooks are the
execution narrative.

## Roles: Beads vs Parallelus Docs

If adopted, keep responsibilities crisp:

- **Beads is for**: backlog items, dependencies, readiness queries, epics, and
  cross-branch coordination (“what’s next, what’s blocked, what depends on
  what”).
- **Parallelus docs are for**: mission brief, decisions, evidence, audit trails,
  review/merge compliance, and the durable “what happened” record.

### Practical linking convention (recommended)

When a branch is spun up, include a short list of Beads IDs in the branch plan,
and reference them in progress entries / commit messages:
- Plan: “This branch addresses: `par-…`, `par-…`”
- Progress: “Closed `par-…` after CI pass”

This keeps Beads as the structured index and leaves the narrative where humans
already look.

## Replace vs Augment: Why “Augment” Wins

Replacing notebooks with Beads would lose key Parallelus properties:
- merge-time narrative (why/what changed) and reviewer-oriented summaries
- consolidated human logs (`docs/PROGRESS.md`) that don’t require tool context
- process enforcement artifacts (checkpoints, retrospectives, review gates)

Beads is strongest as a **backlog + dependency** layer, not as the primary
governance record.

## Shared Beads vs Branch-Specific Beads

### Shared (recommended)

Use one issue ledger for the repo so dependencies and epics remain coherent.

Branch-specific Beads state creates a second set of branch notebooks with the
additional cost of reconciling multiple graphs.

### Branch-specific (not recommended)

Only consider this if you intentionally want “per-branch private task graphs”
that are thrown away, which conflicts with Parallelus’ “durable artifacts in
repo” philosophy.

## “Central backlog outside main” (yes, with guardrails)

Beads supports a protected-branch workflow: keep issue updates on a separate
branch and merge them to `main` only when you choose.

This is a plausible “central backlog” mechanism that can be updated without
blocking on Parallelus’ controlled merges to `main`, while still staying inside
git as a durable artifact.

### Operational risk to address up front

Parallelus’ branch hygiene reports may treat the Beads sync branch as an
“unmerged branch” forever. If Beads is adopted, update the branch-reporting
logic to ignore the sync branch name (or categorize it as metadata).

## Adoption Plan (Pilot)

1. Pick a Beads prefix (recommend `par`) and a sync branch name (recommend
   `beads-sync`).
2. Initialize beads in sync-branch mode and commit the repo-level glue files
   (`.gitattributes`, `.beads/.gitignore`) to `main`.
3. Decide whether `.beads/issues.jsonl` should be merged back to `main`
   periodically (PR cadence) or treated as a long-lived sidecar branch.
4. Add a short “Beads is optional” pointer in `AGENTS.md` (do not duplicate full
   docs; link to this file and/or `bd prime`).
5. Run a one-branch pilot:
   - create a handful of backlog issues in Beads
   - link them in `docs/plans/<branch>.md`
   - update/close them through the branch lifecycle
   - confirm the merge flow remains low-friction

## Non-Goals

- Mandating Beads for all users of Parallelus.
- Replacing `docs/PLAN.md` / `docs/PROGRESS.md`.
- Encoding merge gating inside Beads (Parallelus already owns merge governance).

