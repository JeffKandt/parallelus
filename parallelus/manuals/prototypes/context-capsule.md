# Context Capsule Hand-off Design

## Overview
Main and subagents currently coordinate through explicit artifacts (branch plans,
progress notebooks, committed diffs). Subagents start from a clean conversational
state so they only see these persisted records plus a minimal role prompt. That
preserves auditability but forces the main agent to rebuild situational context
via scope files or ad-hoc summaries. This design introduces a structured
"context capsule" that the main agent emits on demand and the subagent ingests
at launch, aiming to recreate continuity without breaking the isolation
contract.

## Goals & Non-Goals
- **Goals**
  - Provide subagents with enough situational awareness that they feel like a
    continuation of the same agent session from the user's perspective.
  - Keep capsule content auditable, reproducible, and small enough to reliably
    fit within Codex prompt budgets.
  - Define explicit prompts/templates for main agents to produce capsules and
    for subagents to consume them without manual tweaking.
- **Non-Goals**
  - Streaming an entire transcript or internal agent memory verbatim.
  - Replacing existing plan/progress notebooks or guardrails; capsules layer on
    top of those records.
  - Live synchronization between agents—capsules are snapshots generated at
    hand-off time.

## Problem Statement
Subagents begin with zero conversational history, so even if the main agent has
built rich context (user preferences, edge-case investigations, tacit
assumptions), that nuance is lost. Simply dumping the full session transcript
is not viable: transcripts can exceed prompt limits, duplicate sensitive data,
and may contain divergent reasoning the user chose to discard. We need a
repeatable compression pipeline—akin to the `/compact` process—that encodes the
state the main agent deems relevant for continuation while respecting size and
compliance constraints.

## Design Overview
1. **Capsule generation prompt:** A managed template guides the main agent to
   write a structured summary covering objectives, artifacts, decisions, open
   loops, and risk factors. The output is stored as
   `parallelus/manuals/capsules/<branch>/<timestamp>.md` and referenced from the
   subagent scope.
2. **Capsule envelope:** Capsules use a Markdown front matter block with machine
   readable metadata (branch, source session marker, token estimate). The body
   follows a fixed outline so downstream tooling can extract sections.
3. **Subagent prompt extension:** Subagent role prompts gain an optional
   `Context Capsule` section. When a capsule path is provided, the launcher
   injects the body (possibly trimmed) into the prompt after the scope summary
   but before execution guardrails.
4. **Validation hooks:** The monitor loop (or a lightweight helper) records the
   capsule ID in `parallelus/manuals/subagent-registry.json` so auditors can confirm
   what state was shared. Capsule creation/update is treated like any other
   artifact and must be committed alongside the scope.

## Capsule Structure
```
---
branch: feature/context-capsule-design
source_session: 20251023-171812-20251023171813-bc1df3
created_at: 2025-10-23T18:05:00Z
primary_objective: "Design context capsule workflow for subagents"
token_budget: 1200
version: 0.1
---
# Mission Snapshot
- **User intent:** ...
- **Current status:** ...

# Key Decisions & Rationale
1. ...

# Active Workstreams
- Workstream name → scope, owners, blockers.

# Pending Actions
- [ ] Pending item (owner, due trigger)

# Knowledge Base
- Code references, relevant files, API contracts.

# Risks & Watchpoints
- Risk, mitigation, monitoring plan.

# Transcript Highlights
- Timestamped bullet capturing pivotal dialogue or conclusions.
```

Sections intentionally mirror compacted transcript artifacts: they prioritise
salient takeaways instead of raw dialogue. The `Transcript Highlights` section
contains curated snippets—not verbatim dumps—and should reference timestamps or
plan entries for traceability.

## Capturing Exploratory Discussions
- Introduce an `Exploratory Threads` subsection (either within `Transcript
  Highlights` or immediately after) dedicated to ongoing conversations that have
  not yet produced plan entries or tasks. Each bullet should name the topic,
  summarise the current hypothesis, list what evidence is still missing, and
  cite the timestamp or log snippet where the idea originated.
- Record user preferences or "remember this later" requests in the same space so
  successors can acknowledge them proactively even if no concrete action exists
  yet.
- Keep entries concise: prefer one bullet per thread with nested sub-bullets for
  outstanding questions or follow-ups. Remove the bullet once the item is
  captured in the plan/progress notebook to prevent drift.

## Quick Capture Helper (`make remember_later`)
- Introduce `make remember_later` for frictionless capture of speculative or
  preference-oriented notes that should reappear in the next capsule. The helper
  appends structured entries to `parallelus/manuals/capsules/remember-later.md` with a
  UTC timestamp, optional topic, reminder text, suggested next step, and tags.
- Main agents can run
  `make remember_later m="Outline onboarding UX spike" topic=ux next_step="Review mockups"`
  during exploratory conversations to persist reminders without immediately
  editing the capsule draft.
- When generating a capsule, review the reminder inbox and either incorporate
  the entry into `Exploratory Threads & User Preferences` or mark the follow-up
  complete in the plan/progress notebook. Delete or annotate consumed reminders
  so the inbox reflects only outstanding context.

## Capsule Capture Prompt (`make capsule_prompt`)
- Provide `make capsule_prompt` to emit a ready-to-send instruction block that
  tells the active agent to flush its current working memory into a capsule.
- The helper auto-detects the current git branch, suggests a target capsule path
  under `parallelus/manuals/capsules/<branch>/`, embeds references to the branch plan,
  progress log, and reminder inbox, and reiterates the token budget plus
  template expectations.
- Pass `session=<marker>` to pre-fill the session identifier and `file=<path>`
  to override the capsule location. Include `stub=1` if you want the script to
  create a Markdown skeleton that mirrors the capsule template before the agent
  fills it in.
- Use `plan_slug=<plan-doc-slug>` when the branch name differs from the
  notebook filenames (e.g., branch `work` with plan `feature-context-capsule-refine`).
- The printed prompt instructs the agent to respond with the completed capsule
  Markdown so the maintainer can write it directly to the suggested file and
  commit it alongside the subagent launch artifacts.

## Capsule Accuracy vs Size
- **Token budget:** Default budget is 1.2k tokens (≈4.5k chars). Launchers warn
  if the body exceeds 80% of the configured subagent prompt ceiling (e.g., 5k
  tokens). Maintainers can override via `capsule_max_tokens` in a future
  configuration file.
- **Content hierarchy:** Writers prioritise newest, blocking, or high-severity
  items. Stable background (architecture, coding standards) belongs in project
  docs, not capsules.
- **Exploratory threads:** Capture speculative ideas or unresolved questions
  that matter to the user. Pair each with an explicit "next discovery step"
  (e.g., data to gather, stakeholder to ask) so successors can pick up the
  thread without rereading the whole transcript.
- **Compression techniques:**
  - Use referencing: link to plan entries (`docs/branches/...`) or code paths
    instead of re-explaining them.
  - Summarise repetitive exchanges as a single bullet.
  - Group related TODOs under one workstream.
- **Quality gate:** Capsule prompt instructs the agent to verify fidelity by
  cross-checking plan/progress notebooks and latest commits. Mismatches or
  outdated data should be flagged in `Risks & Watchpoints`.

### Capsules vs Progress Notebooks
- Treat capsules as continuity artifacts: they preserve nuance for the next
  agent so a session restart feels like a seamless continuation.
- Treat progress notebooks as the long-lived source of truth: once an
  exploratory idea becomes a commitment (task, decision, or risk), log it in the
  notebook and reference that entry in subsequent capsules.
- When context is ambiguous, record a brief note in both places. Redundancy is
  preferable to losing the detail when the capsule ages out.

Including the entire transcript remains non-viable because:
- Typical sessions exceed Codex prompt limits and would crowd out scope
  instructions.
- Transcripts contain speculative paths and model-internal deliberations that
  may conflict with the final plan, causing confusion.
- Replaying large transcripts slows every subagent launch and bloats registry
  artifacts.

Instead, the capsule inherits `/compact` principles: distil, cite provenance,
and expose uncertainties so a new agent can recover missing detail if needed.

## Capsule Generation Prompt
Create `parallelus/manuals/templates/context_capsule_prompt.md` guiding the main agent:
- Provide metadata: branch, session marker, recap timestamp.
- Summarise objectives, user commitments, decision log, open loops.
- Capture knowledge references (file paths, API endpoints, third-party docs).
- Highlight active experiments or half-complete migrations.
- Limit transcript highlights to pivotal exchanges (≤5 bullets), each linking to
  a plan/progress timestamp or commit hash.
- End with a self-checklist ensuring the capsule is consistent with git status
  and plan notebooks.

Launcher flow:
1. `subagent_manager launch` accepts `--capsule PATH`. If omitted, it offers to
   create one by invoking the capsule prompt.
2. Capsule prompt runs in the main agent session; on completion, the file is
   staged/committed before launch.
3. Registry entry captures `{ "capsule": "parallelus/manuals/capsules/<...>.md" }`.
4. Subagent prompt loader injects the capsule body after rendering scope
   metadata.

## Subagent Consumption Prompt
Extend scope templates to include:
```
## Context Capsule
{{CAPSULE_BODY}}

Treat this capsule as authoritative for current context. Verify plan/progress
notebooks align; note discrepancies in your progress log.
```

Subagent instructions emphasise:
- Capsule is a curated snapshot; cross-validate with repo artifacts.
- When finishing work, update plan/progress docs with deltas so future capsules
  remain accurate.
- If critical information seems missing, record a `Capsule Gap` note and notify
  the main agent.

## Implementation Status
- **Capsule prompt template** — ✅ Implemented in `parallelus/manuals/templates/context_capsule_prompt.md`, supplying the outline and self-checklist consumed by the helper.
- **Capsule capture helper** — ✅ Implemented via `scripts/capsule_prompt.py` and `make capsule_prompt`, which print the ready-to-send instructions and can seed an empty capsule stub.
- **Reminder inbox workflow** — ✅ Implemented through `scripts/remember_later.py` and the inbox at `parallelus/manuals/capsules/remember-later.md` that feeds exploratory threads into capsules.
- **Capsule storage layout** — ⚠️ Partial: `parallelus/manuals/capsules/` exists, but branch-specific directories or `.gitkeep` scaffolding are still created manually when the helper first writes a capsule.
- **Launcher enhancements** — ⏳ Not started: `subagent_manager` lacks a `--capsule` flag, size enforcement, or registry metadata capture.
- **Subagent prompt wiring** — ⏳ Not started: scope templates and prompt loaders do not yet splice capsule bodies into subagent prompts.
- **Monitor loop integration** — ⏳ Not started: monitoring still reports only scope/branch markers without capsule IDs or staleness checks.
- **Operational documentation** — ⏳ Not started: `parallelus/manuals/subagent-session-orchestration.md` still needs capsule launch/refresh procedures and a quickstart checklist.

## Open Questions
- Do we allow multiple capsules per branch (e.g., per workstream) and how should
  launchers pick the latest? Simple approach: most recent by timestamp unless an
  explicit path is provided.
- Should capsules store hashed digests of referenced artifacts to detect drift?
- How do we handle sensitive context (e.g., tokens, credentials) that should not
  be replicated? Capsule prompt should remind agents to redact secrets, but we
  may also add automated linting.
- What retention policy applies? Possibly prune capsules older than N days or
  superseded by merged branches.
- Can we auto-generate miniature capsules for lightweight tasks instead of the
  full template?
