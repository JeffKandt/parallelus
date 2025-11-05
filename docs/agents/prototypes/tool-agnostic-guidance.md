# Tool-Agnostic Guidance Implementation Plan

## 1. Purpose
Codify a single, auditable guidance workflow that every coding agent (Codex CLI, Claude Code, Gemini CLI, others) can consume without duplication. The plan operationalizes the AGENTS.md standard, adds deterministic override semantics, and provides tooling so any agent can bootstrap, verify, and adopt the same ruleset.

## 2. Success Criteria
- **Single source of truth**: `AGENTS.md` at repo root remains canonical; no hand-edited copies elsewhere.
- **Deterministic discovery**: Agents must locate root, ancestor, and local `AGENTS.md` (and optional `AGENTS-override.md`) in a well-defined order.
- **Cross-tool parity**: Codex CLI, Claude Code, Gemini CLI (and future agents) load identical guidance before working.
- **Auditability**: Sessions emit hashes plus summaries of adopted files; CI can verify build artifacts and manifests are current.
- **Fallbacks**: When tool bridges are unavailable (CI, restricted prompts), scripts pre-expand guidance so behavior stays consistent.

## 3. Current Observations
- Codex CLI auto-includes `AGENTS.md` but ignores sibling scope files unless explicitly retrieved.
- Claude Code only auto-loads `CLAUDE.md`; AGENTS.md support is requested (GitHub #6235) but not native yet.
- Gemini CLI can be configured via `.gemini/settings.json` (`contextFileName`).
- Conversation notes highlight the need for:
  - Recursive discovery with depth-aware precedence.
  - Override files (`AGENTS-override.md`) treated as higher priority at matching scopes.
  - Bootstraps that force an initial `read_file` pass, chunking, and confirmation hashes.
  - Optional manifest `.ai/agents.manifest.json` to de-risk indexing delays and provide deterministic discovery in CI.

## 4. Architecture Overview
1. **Canonical Guidance Layer**
   - `AGENTS.md` (root) defines shared goals, guardrails, workflows, precedence rules.
   - Optional scope files: any `*/AGENTS.md` and `*/AGENTS-override.md` extend/override headings for subtrees.
2. **Bootstrap Layer**
   - `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, etc. act as agent-specific loaders: instructions compel discovery, reading, adoption acknowledgement, and hash reporting.
3. **Build & Automation Layer**
   - `scripts/ai-guides.sh` (POSIX) merges canonical + overrides into `/build/*.md` artifacts when static expansion is needed (e.g., GUI uploads).
   - `scripts/ai-sys.sh TOOL` emits merged guidance on demand for wrappers.
   - `scripts/build-agents-manifest.sh` produces `.ai/agents.manifest.json` for deterministic scope discovery.
4. **Config Layer**
   - `.codex/config.toml` sets `system_file = "CODEX.md"` (verify prepend vs. replace).
   - `.gemini/settings.json` sets `contextFileName` and other toggles.
   - Claude Code workaround: short `CLAUDE.md` bootstrap (or symlink if supported) that forces `read_file` adoption of `AGENTS.md` + overrides.
5. **Governance & Audit Layer**
   - Pre-commit / CI checks ensure manifests and build artifacts are current.
   - Session logging records ordered file list + SHA256 digests + adoption statement.

## 5. Implementation Phases & Tasks

### Phase A — Canonical Guidance Foundation
1. **Author canonical rules** in `AGENTS.md`, including:
   - Section hierarchy (Goals, Guardrails, Interaction Rules, Tool Policies, Style, Examples).
   - Explicit override policy for `AGENTS-override.md`.
   - Merge precedence: root → ancestor → local; override files trump same-scope base files; sibling conflict requires human decision.
2. **Document scope conventions** so future subdirectories know when to add local guidance.
3. **Create change log** section (brief) to track major updates.

### Phase B — Tooling & Scripts
1. **Implement `scripts/build-agents-manifest.sh`**
   - Portable `find`/`awk` pipeline, ignoring heavy directories.
   - Outputs ordered JSON with all AGENTS/override files.
2. **Implement `scripts/ai-guides.sh` / `scripts/ai-sys.sh`**
   - Ensure POSIX compliance (no `pipefail`, GNU-only flags).
   - Support profiles (e.g., `AI_GUIDE_PROFILE`) if variants required.
3. **Add Make targets** (`ai-manifest`, `ai-guides`) and CI checks that regenerate artifacts and fail on drift.
4. **Optional helper**: `scripts/expand-agents.sh <path>` merges files per precedence for CI/non-interactive use.

### Phase C — Agent Bootstraps
1. **Draft `CODEX.md`**
   - BOOTSTRAP instructions: determine target path, discover relevant AGENTS files, obey override precedence, emit hashes.
   - Mandate adoption before tasks; require fallback prompt if read fails.
   - Note verification steps (hash echo, “ADOPTED” confirmation).
2. **Draft `CLAUDE.md`** (mirrors CODEX but accounts for CLAUDE.md auto-load)
   - BOOTSTRAP with recursive discovery & manifest fallback.
   - Mandate to `read_file` root, ancestors, locals; chunk large files; stop on sibling conflicts.
   - Include override handling and hash logging.
3. **Draft `GEMINI.md`**
   - Same pattern; reference `.gemini/settings.json` expectations.
   - Provide instructions when `read_file` tool unavailable (ask user or use pre-expanded text).
4. **Extend to other agents** (Cursor, Roo, Kline, etc.) by copying template and adjusting terminology.

### Phase D — Client Configuration & Verification
1. **Codex CLI**
   - Update `.codex/config.toml` with `system_file = "CODEX.md"`.
   - Run sentinel test to confirm whether AGENTS.md is still auto-prepended or only CODEX.md is.
   - Adjust CODEX.md instructions accordingly (always re-read AGENTS.md to confirm parity).
2. **Gemini CLI**
   - Configure `.gemini/settings.json` with `contextFileName` = `AGENTS.md` and any required flags.
   - Validate by starting a session and confirming tool calls occur.
3. **Claude Code**
   - Determine preferred approach:
     - Primary: Keep specialized `CLAUDE.md` bootstrap.
     - Alternative: symlink `CLAUDE.md` → `AGENTS.md` (verify sandbox limitations before relying on symlinks).
   - Track GitHub Issue #6235 for native AGENTS.md support; plan to simplify when available.
4. **Other agents**
   - Audit remaining tooling (Cursor, etc.) and document required configuration keys in the plan appendix.

### Phase E — Validation & Rollout
1. **Local smoke tests**
   - For each agent, start a session, capture logs verifying ordered reads and hash outputs.
2. **CI automation**
   - Add job that regenerates manifest & build outputs, diff-checks them, and ensures adoptable guidance exists.
   - (Optional) run an automated dry-run harness invoking `scripts/expand-agents.sh` for representative paths.
3. **Documentation updates**
   - Update `docs/agents/manuals/README.md` to reference new plan and scripts.
   - Provide quick-start instructions for new contributors.
4. **Adoption governance**
   - Define process for updating `AGENTS.md` (review, approvals, retro logging).
   - Ensure progress notebooks capture any manual overrides during sessions.

## 6. Deliverables
- Updated `AGENTS.md` with canonical rules + override policy language.
- Tool-specific bootstrap files (`CLAUDE.md`, `CODEX.md`, `GEMINI.md`, others as needed).
- POSIX-compliant scripts: `ai-guides.sh`, `ai-sys.sh`, `build-agents-manifest.sh`, optional `expand-agents.sh`.
- Build artifacts directory `/build` (generated guidance) and `.ai/agents.manifest.json`.
- Config updates for Codex (`.codex/config.toml`), Gemini (`.gemini/settings.json`), and any documented workarounds for Claude Code.
- CI augmentation ensuring manifests/build artifacts remain current.

## 7. Risks & Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| Claude Code lacks native AGENTS.md support | Duplicate maintenance or brittle bootstrap | Maintain CLAUDE.md bootstrap + track Issue #6235; prefer deterministic instructions over symlinks |
| Symlinks ignored by GUI/sandbox | Agents fail to see canonical guidance | Default to generated copies; symlink only when verified |
| Tool quota/latency limits prevent full reads | Partial adoption | Enforce chunking rules + require failure escalation in bootstraps |
| Multiple sibling `AGENTS.md` cause ambiguity | Conflicting instructions | Force stop-and-ask behavior; optionally maintain `.ai/agents.scope.json` mapping |
| Non-POSIX shell features in scripts | Breaks on macOS/BusyBox | Shellcheck with `/bin/sh`, test under dash/alpine |

## 8. Open Questions
1. Do we want automated resolution for sibling scopes (via `.ai/agents.scope.json`) or keep manual confirmation?
2. Should overrides use `AGENTS-override.md`, `AGENTS.override.md`, or another naming pattern for better tool compatibility?
3. Should we commit generated `/build/*.md` artifacts, or regenerate on demand (impacts CI + diff noise)?
4. Which additional agents (Cursor, Kline, Roo, etc.) merit first-class bootstrap files in this repo?
5. What cadence should reviewing/updating `AGENTS.md` follow (weekly triage, release gating, etc.)?

## 9. Next Steps (Immediate)
1. Socialize this plan with stakeholders; capture decisions on open questions.
2. Implement Phase A + B tasks to lay groundwork (canonical content + scripts) before tackling tool bootstraps.
3. Schedule verification sessions with Codex, Claude Code, and Gemini once bootstraps/configs land.

_Last updated: 2025-11-05_
