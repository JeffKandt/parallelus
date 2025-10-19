# Codex CLI & Cloud Integration

Codex environments follow the same guardrails as local shells with a few extras.

## Approval Policy Awareness
- Expect approval gating for destructive commands unless the harness is running
  in `danger-full-access` mode.
- When a command might pause for approval, fire the audible alert *before* the
  request so the maintainer hears the pending action.

## Session Management
- `make start_session` writes artifacts under `sessions/<ID>/`. Use
  `some_command 2>&1 | tee -a "$SESSION_DIR/console.log"` to capture output for
  reviewers.
- Update the session summary (`sessions/<ID>/summary.md`) every turn and keep
  `meta.json` in sync with timestamps.

## Sandboxed Environments
- Detached snapshots (no remotes) still rely on the same bootstrap steps; the
  base branch defaults to the current HEAD when remotes are absent.
- Remote operations (fetch, push) may be disabled; the scripts degrade gracefully.

## Audible Alerts in Headless Shells
- If `say`/`afplay` are unavailable, alerts fall back to BEL/log messages so
  maintainers watching scrollback still see the pause/resume cues.

## Autonomy Guardrails
- Do not pause for approval unless destructive, milestone, or clarification
  conditions apply.
- Keep work focused on the current prompt; defer speculative work for follow-up
  sessions.

## Common Workflow Snippets
```bash
make read_bootstrap             # safe detection
make bootstrap slug=my-feature  # create/switch branch
SESSION_PROMPT="$PROMPT" make start_session
make turn_end m="Updated lint + docs"
make archive b=feature/old-work
```

These commands work identically across macOS, Codex CLI, and Codex Cloud.
