# Senior Architect Review – feature/subagent-exec-monitoring

Reviewed-Branch: feature/subagent-exec-monitoring
Reviewed-Commit: 54ea40ad8a15640b2e6b7dc2a88b5daea938ea44
Reviewed-On: 2026-01-23
Decision: approved
Reviewer: senior-review-aoRm9y

## Summary
- Improves exec-mode subagent observability by turning raw `codex exec --json` event streams into a readable, TUI-like timeline that includes command, exit code, and a redacted output hint, while keeping hidden reasoning out of the pane.
- Fixes exec-mode launch reliability by correctly emitting env exports in the generated runner (real newlines) and ensuring the inner runner defines `is_enabled`/`is_falsey`.
- Adds a pragmatic tmux cleanup fallback to close leftover panes when registry metadata is missing.

## Findings
- Severity: Medium | Area: Exec output hygiene | Summary: The new “output hint” intentionally samples command output; redaction is best-effort and may miss sensitive patterns.
  - Evidence: `.agents/bin/codex_exec_stream_filter.py` renders `aggregated_output` snippets in `_summarize_event_tui()` using `_format_output_snippet()` + `_redact()`.
  - Recommendation: Consider defaulting to *no* output snippet unless explicitly enabled (env flag), and/or expand redaction coverage (common JSON keys, `AWS_*`, multiline tokens) with tests to prevent regressions.

- Severity: Medium | Area: Configuration precedence | Summary: Exec-mode enablement is “additive” across `SUBAGENT_*` and `PARALLELUS_*`, which can surprise operators when a global env var re-enables exec-mode despite role config intent.
  - Evidence: `.agents/bin/launch_subagent.sh` checks `is_enabled "${SUBAGENT_CODEX_USE_EXEC:-}" || is_enabled "${PARALLELUS_CODEX_USE_EXEC:-}"` (similarly for `*_EXEC_JSON`).
  - Recommendation: Prefer a clear precedence rule (e.g., `SUBAGENT_*` takes priority when set, including explicit falsey) and document it in the relevant manual.

- Severity: Low | Area: Robustness | Summary: `SUBAGENT_EXEC_OUTPUT_LINES` is parsed with `int(...)` and will crash the filter on non-integer values.
  - Evidence: `.agents/bin/codex_exec_stream_filter.py` assigns `output_lines = int(os.getenv("SUBAGENT_EXEC_OUTPUT_LINES") or "4")`.
  - Recommendation: Guard with `try/except ValueError` (fallback to default) to keep monitoring resilient to environment drift.

- Severity: Low | Area: CLI ergonomics | Summary: Bash `is_falsey` does not trim whitespace (e.g., `false ` becomes truthy), unlike the Python helper.
  - Evidence: `.agents/bin/launch_subagent.sh` / `.agents/bin/subagent_manager.sh` `is_falsey()` lowercases but does not strip.
  - Recommendation: `raw=$(printf '%s' "$raw" | xargs)` or equivalent; or explicitly document acceptable values to avoid “almost false” footguns.

- Severity: Info | Area: UX | Summary: The TUI-like output uses Unicode punctuation (e.g., `Thinking…`), which may render poorly in some terminals/log collectors.
  - Evidence: `.agents/bin/codex_exec_stream_filter.py` prints `- Thinking…`.
  - Recommendation: Consider an ASCII-only mode if terminal compatibility becomes a support issue.

## Tests & Evidence Reviewed
- `git diff origin/main...HEAD` across `.agents/bin/codex_exec_stream_filter.py`, `.agents/bin/launch_subagent.sh`, `.agents/bin/subagent_manager.sh`.
- `bash -n` on `.agents/bin/launch_subagent.sh`, `.agents/bin/subagent_manager.sh`, `.agents/bin/subagent_exec_resume.sh`.
- `python3 -m py_compile .agents/bin/codex_exec_stream_filter.py`.
- Local smoke test of `.agents/bin/codex_exec_stream_filter.py` against a synthetic JSONL event stream to confirm redaction and readable summaries.

## Follow-Ups / Tickets
- [ ] Add unit/smoke tests for exec event rendering and redaction invariants (no secret-like strings in summaries by default).
- [ ] Define and document env-var precedence for exec/tui selection; align `launch_subagent.sh`, `subagent_manager.sh`, and manuals.
- [ ] Harden env parsing for `SUBAGENT_EXEC_OUTPUT_LINES` (and any future knobs) to avoid crashes.

## Provenance
- Model: gpt-5.2 (Codex CLI)
- Sandbox Mode: throwaway
- Approval Policy: never
- Session Mode: synchronous subagent
