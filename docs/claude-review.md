# Parallelus Agent Infrastructure - Comprehensive Review

## How It Works

Parallelus is a **guardrail-driven collaboration framework** for human-AI pair programming that enforces process discipline through automation. Think of it as "infrastructure-as-code meets AI governance."

### Core Architecture

**1. Structured Development Lifecycle**

The system enforces a rigid four-phase workflow:

- **Recon & Planning** (read-only): Agent runs `make read_bootstrap`, reviews branch notebooks, checks session history
- **Transition to Editing**: Creates feature branch via `make bootstrap slug=<name>`, initializes plan/progress logs
- **Active Execution**: Code changes with continuous documentation updates, checkpoint commits, automated alerts
- **Turn-End & Wrap**: Progress logging via `make turn_end`, retrospective audits, senior architect reviews before merge

**2. Multi-Agent Orchestration**

The `subagent_manager.sh` (1,223 lines) is the heart of the system:

- **Sandbox isolation**: Spawns throwaway git clones or worktrees for parallel work
- **Role-based delegation**: Specialized agents (senior architect, CI auditor) run in isolated environments
- **Deliverable tracking**: JSON registry tracks sandbox state, tmux handles, log heartbeats, and file artifacts
- **Template-driven prompts**: Combines role definitions (YAML front matter) with scope files and runtime context

Example flow:
```bash
subagent_manager.sh launch \
  --type throwaway \
  --slug senior-review \
  --role senior_architect.md \
  --deliverable docs/reviews/feature-foo-2025-10-19.md
```

**3. Enforcement Mechanisms**

- **Git hooks**: Pre-commit checks for plan/progress updates, blocks direct commits to main
- **Merge gates**: `agents-merge` requires signed senior review, validates commit hashes, checks for blocker findings
- **Durable artifacts guardrail**: `agents-turn-end` now refuses to log progress without code/doc/test changes (the "fix it once, fix it forever" philosophy from PR #2)
- **Audible alerts**: CLI beeps before approval pauses so humans know when intervention is needed

**4. Documentation-as-State**

Everything is tracked in markdown:
- `docs/PLAN.md` / `docs/PROGRESS.md` - global backlogs
- `docs/plans/<branch>.md` - per-branch objectives
- `docs/progress/<branch>.md` - detailed turn-by-turn logs
- `docs/reviews/<branch>-<date>.md` - senior architect sign-offs
- `docs/self-improvement/` - retrospective markers and CI auditor findings

**5. Environment Abstraction**

- **Language adapters**: Python/Swift/Node overlays provide language-specific CI/test runners
- **Runtime matrix**: Supports macOS, Codex CLI/Cloud, CI headless shells
- **tmux integration**: Subagents launch in separate panes with automatic socket detection via `PARALLELUS_TMUX_SOCKET`

### Key Innovations

1. **Fix-it-forever discipline**: When guardrails slip, solutions must become versioned artifacts (not tribal knowledge)
2. **Read-on-trigger manuals**: Operational docs (`docs/agents/manuals/`) only consulted when specific gates fire
3. **Subagent provenance**: Reviews must prove they ran via isolated launcher (checks for "Session Mode: synchronous subagent")
4. **Overlay deployments**: `deploy_agents_process.sh` can upgrade existing repos while preserving project-specific docs

---

## Top 3 Improvement Suggestions

### 1. **Add Automated Testing for the Guardrail Tooling** (Severity: High)

**Problem:**
The bash scripts (`agents-merge`, `agents-turn-end`, `subagent_manager.sh`) are mission-critical infrastructure managing git operations, sandbox isolation, and merge safety. Yet there are **no automated tests**. PR #2 added complex path-matching logic without test coverage.

**Risk:**
- Silent failures in doc-only commit detection could block legitimate merges
- Sandbox escape vulnerabilities in `subagent_manager.sh` harvest logic (lines 1028-1093)
- Regression risk when refactoring the 1,200+ line subagent manager

**Recommendation:**
Create `tests/guardrails/` with:
```bash
tests/guardrails/
  test_agents_merge.sh       # Test doc-only commits, review validation, force overrides
  test_agents_turn_end.sh    # Test durable artifact checking, escape hatches
  test_subagent_manager.sh   # Test sandbox isolation, deliverable harvesting
  fixtures/                  # Mock repos, fake reviews, test scopes
```

Use [bats-core](https://github.com/bats-core/bats-core) or similar bash testing framework. Gate merges on passing these tests.

**Impact:** Prevents production incidents from guardrail failures, enables safe refactoring, documents expected behavior.

---

### 2. **Consolidate Path Pattern Definitions** (Severity: Medium)

**Problem:**
Currently there are **inconsistent path patterns** across tools for "documentation-only changes":

- `agents-merge:179-186` checks: `docs/reviews/*|docs/plans/*|docs/progress/*|docs/PLAN.md|docs/PROGRESS.md|docs/self-improvement/markers/*|docs/self-improvement/reports/*`
- `agents-turn-end:60` checks: `^(docs/(plans|progress)/|docs/self-improvement/(markers|reports)/|sessions/)`

The `agents-turn-end` pattern **won't match** `docs/PLAN.md` or `docs/PROGRESS.md` at the root level (only files under subdirectories). This could cause the durable artifact check to incorrectly fire.

**Recommendation:**
Create a canonical source file:
```bash
.agents/config/path_patterns.sh
```

```bash
# Documentation paths that don't require durable artifacts
DOC_ONLY_PATHS=(
  "docs/reviews/"
  "docs/plans/"
  "docs/progress/"
  "docs/PLAN.md"
  "docs/PROGRESS.md"
  "docs/self-improvement/markers/"
  "docs/self-improvement/reports/"
  "sessions/"
)

# Function: is_doc_only_change(file_path)
is_doc_only_change() {
  local file=$1
  for pattern in "${DOC_ONLY_PATHS[@]}"; do
    [[ "$file" == $pattern* ]] && return 0
  done
  return 1
}
```

Source this from `agents-merge`, `agents-turn-end`, and any other scripts that need consistent path logic.

**Impact:** Eliminates subtle bugs, makes behavior predictable, simplifies maintenance.

---

### 3. **Implement Graceful Subagent Timeout and Failure Recovery** (Severity: Medium)

**Problem:**
The `subagent_manager.sh` launch flow assumes subagents will complete successfully. There's no:
- Automatic timeout for hung subagents (e.g., senior review stuck waiting for unavailable API)
- Partial deliverable recovery when a subagent crashes mid-execution
- Notification mechanism when log heartbeats stop updating

The cleanup command (`subagent_manager.sh cleanup`) refuses to run on "running" subagents unless `--force` is passed, but there's no automatic detection that a subagent has **actually died** vs. legitimately running.

**Current workflow:**
```bash
# Operator must manually check if subagent is alive
tail -f .parallelus/subagents/sandboxes/senior-review-xyz/subagent.log
# If stuck, force cleanup loses any partial work
subagent_manager.sh cleanup --id <id> --force
```

**Recommendation:**
Add timeout and health monitoring:

```bash
# In subagent_manager.sh launch
--timeout 3600  # Kill subagent after 1 hour

# In agents-monitor-loop.sh
MAX_LOG_AGE_SECONDS=300  # Warn if no log updates in 5 minutes
STALE_THRESHOLD=600      # Mark as failed if no updates in 10 minutes
```

Enhance registry status:
```json
{
  "status": "running|completed|failed|timed_out",
  "last_heartbeat": "2025-10-19T14:32:15Z",
  "deliverables_partial": true
}
```

Add recovery command:
```bash
subagent_manager.sh recover --id <id>
# Harvests any deliverables found even if status != completed
# Updates registry to 'partial_recovery'
```

**Impact:**
- Prevents infinite waiting on hung subagents
- Salvages partial work from crashed reviews
- Improves operator experience during failures

---

## Bonus Observations

**Strengths:**
- Philosophy is sound: forcing durable artifacts prevents technical debt
- Senior review integration is sophisticated (YAML front matter, allowed writes, config overrides)
- Documentation is thorough and human-readable
- Git hook integration is well-architected

**Potential Future Enhancements:**
- **Metrics dashboard**: Track review turnaround time, guardrail violation rates, subagent success rates
- **Web UI**: Visual status board for active subagents, pending reviews, branch health
- **Parallel subagent coordination**: Currently subagents are independent; consider adding dependency orchestration (e.g., "run tests only after code generation completes")
- **Pre-commit hook performance**: Currently blocks on plan/progress checks; could be async with pre-push enforcement

---

This is a well-designed system that takes AI collaboration seriously. The three suggestions above would harden the infrastructure against edge cases and make it production-grade for larger teams.
