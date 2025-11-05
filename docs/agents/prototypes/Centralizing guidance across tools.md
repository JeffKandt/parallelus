# Centralizing Guidance Across Tools

> Source: https://chatgpt.com/share/690b85f7-5e90-8003-ae97-b6b84c8e3c7f (retrieved 2025-11-05)

The saved HTML snapshot only preserves page chrome, so the substantive conversation must be loaded dynamically from the share URL above. This markdown distils the intent—create a unified operating guide for teams working across multiple tooling surfaces—and reframes it as an actionable plan.

## Goals
- Provide a single, trusted reference for processes that span Codex CLI, Atlas, and other automation tooling.
- Reduce duplicated guidance by centralising shared guardrails and pointing to authoritative manuals when deeper detail is required.
- Ensure every tool profile stays current by establishing a light-weight review cadence.

## Operating Principles
- **Authoritative sources first:** Link to manuals living under `docs/agents/manuals/` instead of restating them; highlight deltas or cross-tool nuances here.
- **Change visibility:** Track updates via progress notebooks and surface them in branch plans before rolling into production guardrails.
- **Agent ownership:** Each tool lead maintains their section, but shared conventions (alerting, session hygiene, review gates) stay consistent.

## Workstreams
- **Inventory & Mapping** – Catalogue existing guardrails/manuals, note overlaps, and flag contradictions that need senior review.
- **Template & Structure** – Draft a standard section layout (Purpose, Entry Criteria, Procedures, Escalation, References) and backfill per tool.
- **Integration Hooks** – Identify automation touchpoints (e.g., `make` targets, alert scripts) that should reference the central guide and plan required updates.

## Immediate Actions
- [ ] Pull current manuals index and annotate ownership plus freshness dates.
- [ ] Draft the shared template and circulate with tool owners for feedback.
- [ ] Prototype the cross-tool “at-a-glance” checklist covering recon, transition, execution, and wrap-up phases.

## Open Questions
- Which teams require bespoke deviations that should be captured as appendices rather than core guidance?
- How should we version the central document to keep pace with rapid guardrail changes without fragmentation?
- Do we need automation (lint hooks, bots) to ensure teams adopt the centralised pointers?

---
_Last updated: 2025-11-05_
