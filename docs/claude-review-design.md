# CLAUDE Guardrail Hardening Design

## Purpose
Document the strategy for strengthening the Parallelus guardrail toolchain with automated tests, configuration consistency, and operational resilience. This design consolidates the improvement items captured in `docs/claude-review.md` and the follow-up discussions in this branch.

## Objectives
- Establish an automated test suite for guardrail scripts that lives alongside the codebase but remains outside the deployable `.agents` payload.
- Provide guidance for downstream repositories to integrate their own guardrail-specific tests.
- Capture additional hardening items: shared path pattern configuration and subagent timeout/recovery enhancements.
- Emphasise subagents as a tool for conserving the main agent's conversation context by offloading long-running or interactive tasks into isolated sandboxes.

## Scope
- `.agents/bin` shell tooling (`agents-merge`, `agents-turn-end`, `subagent_manager.sh`, monitoring utilities).
- Repository-level test harness and CI integration.
- Documentation/artifact updates required to adopt the plan.

## Non-Goals
- Implementing the tests or refactors themselves (covered by future tasks).
- Replacing existing CLI workflows or altering baseline user flows beyond the specified enhancements.

## Current State
- **Existing Coverage:** `tests/test_basic.py` provides a pytest smoke test that launches and forcibly cleans up a throwaway subagent sandbox. It verifies that `.agents/bin/subagent_manager.sh` emits a sandbox ID and does not crash when invoked without an explicit role.
- **Gaps:** No behaviour-driven tests exist for merge guardrails, documentation-only detection, or subagent lifecycle failure modes. Downstream repos lack a standard hook for adding guardrail tests to the Parallelus process.

## Proposed Automated Test Suite
### Location & Packaging
- Add `tests/guardrails/` in the repo root with dedicated shell-focused tests and fixtures.
- Exclude `tests/` from any deployment or rsync logic that packages `.agents` for downstream repos so the suite remains development/CI-only.

### Tooling
- Use `bats-core` (preferred) or `shUnit2` to execute bash scenarios.
- Provide a wrapper `scripts/test-guardrails.sh` that configures `PATH` for local `.agents/bin`, seeds temporary fixture repos, and runs each bats file.
- Ensure the wrapper exports `SUBAGENT_MANAGER_ALLOW_MAIN=1` (mirroring the current Python smoke test) and other required env vars for isolated execution.

### Test Modules
1. `tests/guardrails/test_agents_merge.bats`
   - Cover doc-only commits, missing senior architect review, force overrides, and durable artifact enforcement.
2. `tests/guardrails/test_agents_turn_end.bats`
   - Validate progress/plan notebook requirements, marker creation, and non-doc change handling.
3. `tests/guardrails/test_subagent_manager.bats`
   - Exercise launch/cleanup happy path, timeout detection, crash recovery, and partial deliverable harvesting.

### Fixtures & Helpers
- `tests/guardrails/fixtures/` will contain minimal git repositories and mock review assets. Provide helper scripts to clone or reset fixtures per test to preserve determinism.
- Include mock binaries (e.g., shadow `git`, `agents-alert`) to emulate failure modes without touching real tooling.
- Leverage the new manual monitor harness (`tests/guardrails/manual_monitor_scenario.sh`) as the seed for automated subagent-monitor coverage; port its scenarios into bats once the framework lands.
- Keep the harness aligned with the production tmux layout (main agent pane on the left, subagents stacked on the right) so manual practice matches the live experience while we gather snapshot data.

### Manual Monitor Scenario Automation Roadmap
1. Stabilise the existing shell harness by documenting required environment variables (`KEEP_SESSION`, `AGENTS_ALERT_SINK`) and codifying setup/teardown steps in comments.
2. Capture representative transcripts from at least three manual runs (healthy, slow, and stalled subagents) and store them under `tests/guardrails/fixtures/monitor_snapshots/` for replay.
3. Extract reusable helper functions (session bootstrap, registry polling, manifest validation) into `tests/guardrails/lib/monitor_helpers.bash` so bats specs can call them directly.
4. Author `tests/guardrails/test_agents_monitor.bats` that imports the helpers, replays the snapshot fixtures, and asserts on registry state transitions, tmux layout enforcement, and manifest gating.
5. Wire the new bats file into `scripts/test-guardrails.sh`, ensuring CI can run in headless mode by providing a mock tmux adapter when real sockets are unavailable.
6. Once automated coverage is green, retire redundant manual steps by updating `tests/guardrails/manual_monitor_scenario.sh` to point contributors at the bats suite for validation, leaving the shell harness as an exploratory fallback.

### CI Integration
- Add `make test_guardrails` target that runs the wrapper and hook it into `make ci`.
- Configure the primary CI workflow to execute guardrail tests in parallel with existing language adapters.
- Document local usage: `make test_guardrails` should be part of contributor instructions and enforced pre-merge.

## Downstream Repository Guidance
- Extend `.agents/make/agents.mk` documentation to describe how adopters can register repo-specific guardrail tests (e.g., by defining `make guardrail_ci` or adding to `make ci`).
- Outline how downstream teams can surface *project* unit/integration suites inside guardrail entry points (e.g., teach `agents-merge` to call a repo-defined `make agents_pre_merge` that chains the guardrail suite plus `pytest`/`go test`).
- Provide a templated README snippet illustrating how to place custom guardrail tests under `tests/guardrails/<repo>/` and wire them into CI.
- Document a hook contract (simple shell function or env var) that lets repositories opt-in to running their legacy `make test`/`npm test` jobs as part of `make turn_end` or `make merge` so guardrails remain repo-aware.
- Consider adding an optional prompt inside `.agents/bin/deploy_agents_process.sh` to encourage teams to connect their existing tests after installation.

## Additional Hardening Items
1. **Shared Path Pattern Configuration**
   - Today only the merge guardrail relaxes checks based on path scope: `agents-merge` (and its managed hook) allow a one-commit lag when the tip commit touches only `docs/reviews/…`. Turn-end and session helpers do not yet read any path allowlists. 
   - Create `.agents/config/path_patterns.sh` defining `DOC_ONLY_PATHS` and helper functions (e.g., `is_doc_only_change`) so future doc-only handling draws from one source of truth.
   - Source the configuration from `agents-merge`, `agents-turn-end`, and related scripts to ensure consistent handling, while allowing each checkpoint to extend the list for its unique artifacts (`sessions/`, retrospectives, etc.).

2. **Subagent Timeout & Recovery Enhancements**
   - Current behaviour: `make monitor_subagents` (wrapping `agents-monitor-loop.sh`) polls the registry, tracks runtime and log age, and exits once thresholds are exceeded. It does not attempt automated recovery; operators must inspect tmux panes/logs manually and decide whether to inject `Proceed`/`Continue` or force-cleanup.
   - Extend the monitoring helper so threshold breaches trigger an investigative pass rather than an immediate exit. The loop should re-check the sandbox (tail logs, query tmux pane state) and, if the subagent is still producing output, resume monitoring. Default thresholds have already been tightened to a 30s poll interval with 90s heartbeat / 240s runtime limits so we exercise early-break behaviour; as the recovery path proves stable, tune these values further—even if that means occasionally exiting and re-entering the loop after a successful nudge. Ensure the monitor can juggle multiple active subagents, tracking per-ID state and only standing down once every running entry reports completion/harvest.
   - When the sandbox appears stalled, attempt scripted nudges (e.g., send `Proceed`, `Continue`, or custom keepalive prompts) before escalating. Record outcomes in the registry (`status`, `last_heartbeat`, `nudges_attempted`).
   - Capture tmux pane snapshots whenever alerts fire so we can study real prompts/questions and evolve smarter heuristics (and potential main-agent handoffs) without relying on human observation.
   - Surface health state transitions via registry fields and structured alerts (`timed_out`, `awaiting_input`, `recovered`), enabling higher-level tooling to make informed decisions.
   - Provide a dedicated `recover` path that harvests partial deliverables while preserving logs/metadata whenever automated recovery fails so operators have context for follow-up.
   - Gate completion on deliverable finalisation for **all** subagent types: require each subagent to stage outputs under a sandbox `deliverables/` directory, write a manifest (name, size, checksum, type), and signal readiness via a flag (e.g., `.complete`). The manager verifies the manifest against on-disk files (hash/size match, required filenames present) before moving them into the repo and marking the registry status `completed`/`harvested`. Legacy flows (e.g., CI audit subagents that emit JSON via tmux) should be migrated to the manifest protocol or wrapped with an adapter that consolidates their output into the new format.

## Risks & Mitigations
- **Test Flakiness:** Rely on isolated fixtures and mock binaries to avoid environmental dependencies.
- **Maintenance Overhead:** Document the harness and add contributor onboarding notes to keep the suite in sync with script changes.
- **Adoption Resistance:** Provide ready-to-use templates and optional prompts to lower the barrier for downstream teams.

## Implementation Plan
1. Prototype `tests/guardrails/test_agents_merge.bats` with minimal fixture support and land CI integration.
2. Expand coverage to `agents-turn-end` and `subagent_manager`, adding fixtures as needed.
3. Introduce `.agents/config/path_patterns.sh` and refactor scripts to source it.
4. Implement timeout/recovery changes and the deliverable manifest handshake, updating documentation and tests simultaneously.
5. Publish downstream integration guidance (README updates, deployment hooks).

## Review & Feedback Workflow
- Publish this design with a short executive summary in the guardrail review channel and attach the diff in the feature branch (`feature/claude-review`). Include the context marker from the active session so reviewers can locate supporting artifacts quickly.
- Track feedback in `docs/progress/feature-claude-review.md` under dated entries, noting who raised the item and any related follow-up tasks.
- Reflect accepted feedback in `docs/plans/feature-claude-review.md` by adding checklist items or updating objectives so the work remains visible to automation (pre-commit hooks, merge guardrail).
- When feedback requires code or tooling changes, capture the target commit(s) and expected verification steps in the branch plan before implementation to preserve traceability.
- After incorporating changes, call out the updates in the next `make turn_end` summary so downstream reviewers can confirm that the feedback loop completed.

## Acceptance Criteria
- Automated guardrail tests run via `make test_guardrails` and in CI, separate from deployable artifacts.
- Shared path pattern configuration eliminates duplication and inconsistencies.
- Subagent tooling supports timeout, failure detection, and partial recovery.
- Subagent completion requires manifest-verified deliverables before marking entries finished.
- Documentation (this design, README updates) clearly explains how other repos can adopt or extend the guardrail test suite.

### Real Monitor Harness

- Implement `.agents/bin/agents-monitor-real.sh` to launch deterministic real subagent scenarios, reuse `make monitor_subagents` with 15/30/300 thresholds, and inspect deliverables/transcripts before forcing cleanup.
- Expose the harness to tests via `tests/guardrails/manual_monitor_real_scenario.sh` so integration coverage uses the production path.
- Store scoped instructions and scripts under `.agents/templates/real_monitor/` so subagents run a consistent command set when evaluating the real flow.
