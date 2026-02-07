# Context Capsule Prompt Template

Use this template when generating a context capsule prior to launching a
subagent. Replace bracketed sections with project-specific details. Keep the
final length under the configured token budget (default 1.2k tokens). Cite plan
entries, progress logs, or commits whenever referencing historical work.

Run `make capsule_prompt` to print a ready-to-send instruction block that
includes this template, current branch metadata, and outstanding reminders. The
helper can also create a stub file with `stub=1` before you fill in the
sections below. Add `plan_slug=<slug>` if your plan/progress notebooks use a
different naming convention than the current branch.

---
branch: <feature-branch>
source_session: <session-marker-id>
created_at: <ISO8601 timestamp>
primary_objective: <one-sentence focus>
token_budget: 1200
version: 0.1
---
# Mission Snapshot
- **User intent:** <summarise the user's latest request in ≤2 sentences>
- **Current status:** <describe branch state, outstanding verifications, etc.>

# Key Decisions & Rationale
1. <Decision> — <Why it was made / evidence>
2. <Decision> — <Why it was made / evidence>

# Active Workstreams
- **<Workstream name>** — scope, owner, deadlines, blockers.
- **<Workstream name>** — scope, owner, deadlines, blockers.

# Pending Actions
- [ ] <Action item> (owner, trigger)
- [ ] <Action item> (owner, trigger)

# Knowledge Base
- <File or doc reference> — <why it matters>
- <API/Service reference> — <constraints, auth requirements, rate limits>

# Risks & Watchpoints
- <Risk> — <mitigation, monitoring plan>
- <Risk> — <mitigation, monitoring plan>

# Transcript Highlights
- <Timestamp or log reference> — <key takeaway>
- <Timestamp or log reference> — <key takeaway>

# Exploratory Threads & User Preferences
- _Review `docs/agents/capsules/remember-later.md` and fold in any outstanding
  reminders before finalising this section._
- **<Topic or idea>** — <current hypothesis or user preference>; next step: <evidence to gather or question to ask>. [Ref: <timestamp/log>]
- **<Topic or idea>** — <why it matters>; next step: <follow-up trigger>.

# Consistency Checklist
- [ ] Capsule aligns with `docs/branches/<slug>/PLAN.md` latest entry.
- [ ] Capsule aligns with `docs/branches/<slug>/PROGRESS.md` latest entry.
- [ ] Referenced commits/PRs are included in current branch history.
- [ ] Sensitive data (tokens, credentials) redacted or omitted.
