# Parallelus Agent Process

Parallelus is a guardrailed collaboration system where a human owner sets the direction and an AI agent operates the repository on their behalf. The agent handles branches, tooling, documentation, and compliance steps; the human stays focused on intent, priorities, and decisions. Every interaction happens in plain language, with the agent translating requests into the underlying automation.

---

## Philosophy
Parallelus is designed around a clear division of labour:

- **You steer; the agent drives.** The human partner articulates goals, success criteria, and trade-offs. The agent executes the mechanical work--editing code, running tests, updating logs, and enforcing guardrails.
- **Dialogue over commands.** Instead of memorising scripts, you describe what should happen: "Create a feature branch for the dashboard uplift" or "Merge the notifications work once the review is green." The agent interprets and carries out the request.
- **Process without burden.** Guardrails, retrospectives, and review gates are agent responsibilities. You only need to know they exist, why they matter, and how to invoke them. The agent keeps notebooks current, runs audits, and confirms every step in the progress log.
- **Shared situational awareness.** Documentation is written so humans can understand the state of the project at a glance, even if they never touch the shell. Notebook updates, backlog queues, and review reports keep the narrative flowing between turns.
- **Portable playbook.** When Parallelus is embedded into another repository, its human-facing guidance moves with it (typically under `.agents/`). The project's own README remains focused on the product; this guide explains how to work with the agent.

With these principles, you can treat the agent as a dedicated developer who never forgets the process and always documents what happened.

---

## Why Teams Use Parallelus
- **Predictable sessions.** Each turn follows Recon → Planning → Execution → Wrap-Up, so context is gathered before work begins and outcomes are recorded before moving on.
- **Built-in governance.** Senior reviews, retrospectives, and compliance checks are mandatory steps the agent manages automatically.
- **Lower cognitive load.** You ask for outcomes; the agent translates them into implementation details, updates notebooks, and keeps the repo clean.
- **AI-native delegation.** Parallelus assumes the agent (and any subagents) are the hands on the keyboard, so all instructions, logs, and safeguards are ready for automated execution.

---

## Core Capabilities
- **Process guardrails.** Parallelus ships with documented gates--for branching, reviews, retrospectives, and CI--that the agent enforces.
- **Structured notebooks.** Every feature branch collects its plan, progress, and outcomes in the repository so human reviewers can skim "what changed" in a few minutes.
- **Session history.** Work blocks are timestamped and linked to session logs, making it easy to pause, resume, or audit long-running efforts.
- **Backlog management.** A shared queue lets you jot ideas during Recon and decide whether they belong in the next feature branch or the long-term plan.
- **Subagent orchestration.** The agent can launch specialised helpers (for audits, reviews, parallel feature work in dedicated worktrees, etc.) while keeping you informed about their status and deliverables.

---

## Workflow at a Glance
Use conversational prompts to steer the agent through each phase:

1. **Recon & Planning**  
   - Ask the agent to "Review the current plan and tell me what's pending."  
   - Capture new ideas in the scratch queue ("Add these items to the backlog queue for our next branch.")  
   - Decide on the next objective and name for the work.

2. **Transition to Editing**  
   - Say "Create a feature branch called …"  
   - Provide a short mission brief the agent will log in the plan/progress files.

3. **Active Execution**  
   - Direct the agent with outcomes: "Implement X," "Refactor Y," "Investigate this failing test."  
   - Request validation: "Run the full check suite," "Confirm linting is clean," "What's the status of the CI audit?"  
   - Delegate parallel work: "Spin up a worktree for the API tweaks and have a subagent handle it while we continue here."

4. **Turn-End & Session Wrap**  
   - Tell the agent "Prepare the turn-end summary" or "Run the retrospective and capture the report."  
   - Review the agent's recap and agree on next steps before ending the session.

5. **Merge & Release**  
   - When work is ready, instruct "Initiate the senior architect review," then "Merge back to main once the review is approved and everything is documented."

Throughout, speak in high-level directives. The agent will translate those into the necessary scripts, hooks, and documentation updates.

---

## Getting Started

### Prerequisites
- A development environment (macOS or Linux) where the agent can run shells, manage Git, and install dependencies.
- Access to your AI orchestration platform (e.g., the Codex CLI) so the agent can reason about tasks and run subagents.
- tmux is recommended so the agent can manage multiple panes/sessions when launching subagents.
- Optional: a remote Git service if you plan to publish the work.

As the human collaborator, ensure the agent has these capabilities. You do not need to install or configure them personally--the agent can do it once given access.

### Introducing Parallelus to a Project
1. **Assess fit.** Ask the agent to audit the repo and confirm Parallelus can be layered on top (existing guardrails, expectations, etc.).
2. **Install the playbook.** Instruct the agent to "Adopt the Parallelus process in this repository," which prompts it to copy the `.agents/` directory, documentation, and hooks.
3. **Align on cadence.** Discuss how you'd like to work (session length, review cadence, release cadence). The agent will note this in the plan.
4. **Confirm guardrails.** Request a walkthrough: "Explain the key guardrails and how they impact our workflow."
5. **Start small.** Begin with a single feature branch to experience the Recon → Planning → Execution flow before scaling up.

### Daily Rhythm for Humans
- Begin each session by asking "What's the current status and what do you recommend tackling next?"  
- Add ideas on the spot: "Queue these two ideas for the next branch," or "Park this improvement in the long-term backlog."  
- Use clear requests for actions ("Archive branch X," "Coordinate a review for branch Y," "Spin up an audit focused on the CI configuration").  
- Expect the agent to describe what it did, what changed, and any follow-up recommendations at the end of the turn.

---

## Working Vocabulary
Here are phrases Parallelus recognises and the behaviours the agent performs:

| Phrase you say | What the agent does |
| --- | --- |
| "Create a feature branch for …" | Names the branch, bootstraps notebooks, records the mission brief. |
| "Merge back to main when ready." | Runs required audits, confirms senior review, completes the merge, and documents the outcome. |
| "Initiate a code review." | Launches the senior architect subagent, tracks deliverables, and reports back when the review artifact is saved. |
| "Assign two subagents to work on these features in parallel." | Creates temporary worktrees, launches dedicated subagents per task, maintains the monitor loop, and gathers their outputs. |
| "Archive branch X, merge branch Y." | Uses the appropriate guardrails to retire one branch while closing out another. |
| "What do you recommend we do with branch Z?" | Summarises outstanding work, risks, and options, then proposes next steps. |
| "Add this to the backlog for later." | Places the item in the queue under "Project Backlog" and, on the next branch, files it into `docs/PLAN.md`. |

Feel free to paraphrase; the agent is trained to map intent to the underlying process.

---

## Understanding the Guardrails
- **Recon discipline.** Every work session starts with context gathering. The agent reviews plans and progress logs, reports status, and only proceeds once you confirm the focus.
- **Documented execution.** Plans, progress notes, and retrospectives live in the repo. When you ask "What changed today?" the agent points to those docs.
- **Mandatory reviews.** No merge happens without an approved senior architect report. You can trust that code entering `main` has both human-readable justification and logged outcomes.
- **Continuous improvement.** The agent runs retrospective audits and pushes follow-up items into the backlog, so process gaps are addressed rather than forgotten.
- **Clean hand-offs.** At the end of each turn the agent confirms the working tree state, outstanding tasks, and next steps so another session (human or automated) can pick up seamlessly.

---

## Directory Overview (Human-Oriented)
- `README.md` -- This guide for humans using Parallelus.
- `AGENTS.md` -- The definitive guardrail checklist the agent follows. Skim it if you want deeper governance detail.
- `.agents/` -- Implementation details the agent relies on (scripts, hooks, prompts). Humans rarely need to touch these directly.
- `docs/PLAN.md` -- The global backlog and priorities, updated by the agent.
- `docs/PROGRESS.md` -- The consolidated work log across branches.
- `docs/agents/` -- Manuals referenced when special gates (merges, diagnostics, subagent orchestration) are triggered.
- `docs/agents/project/` -- Maintainer notes about the Parallelus toolkit. When adopting Parallelus in another repo, replace this directory with the host project's guidance (see docs/agents/project/README.md).
- `docs/plans/` & `docs/progress/` -- Per-branch notebooks created when new work begins; useful if you want to review the history of a specific feature.
- `docs/self-improvement/` -- Retrospective markers and reports maintained by the agent.

---

## Next Steps
If you're evaluating Parallelus:
1. Discuss your priorities with the agent and ask for a recommended adoption plan.
2. Pilot the workflow on a single feature branch.
3. Review the resulting notebooks and progress logs to confirm they meet your expectations.

Parallelus thrives when humans stay focused on intent and the agent handles the mechanics. Speak in outcomes, review the narrative the agent produces, and enjoy working with a partner who never forgets the process.
