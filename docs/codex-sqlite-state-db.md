# Codex SQLite State DB (sessions metadata + logs)

Codex can persist session/thread metadata (mirrored from rollout JSONL files) and internal tracing logs into a local SQLite database under `~/.codex/`.

This is useful when you want to query “what sessions happened / when / where?” and to tail/debug Codex behavior without scraping console output.

## Enable it

Add this to `~/.codex/config.toml`:

```toml
[features]
sqlite = true
```

Alternatively, enable it via the Codex CLI (writes to `config.toml`):

```sh
codex features enable sqlite
```

### Unstable feature warning

Recent Codex builds (for example `codex-cli 0.98.0`) emit this warning on startup when `sqlite` is enabled:

```
⚠ Under-development features enabled: sqlite. Under-development features are incomplete and may behave unpredictably. To suppress this warning, set `suppress_unstable_features_warning = true` in /Users/jeff/.codex/config.toml.
```

If you want to suppress it, add:

```toml
suppress_unstable_features_warning = true
```

## Where the DB lives

The state DB is created at:

- `~/.codex/state_2.sqlite` (plus SQLite WAL sidecars: `state_2.sqlite-wal`, `state_2.sqlite-shm`)

Notes:

- The file is created after you run Codex with the `sqlite` feature enabled (non-ephemeral sessions).
- Internal log capture is typically active only once the DB exists. If you just enabled the flag, run Codex once to create the DB, then restart Codex so the log-export layer attaches.
- You may also have other SQLite files under `~/.codex/sqlite/` (for example `codex-dev.db`) that are unrelated to this state DB.

## What’s stored (and what isn’t)

Stored in `state_2.sqlite`:

- `threads`: per-session/thread metadata (id, timestamps, cwd, title, provider, sandbox/approval mode, git info, etc.)
- `thread_dynamic_tools`: dynamic tools recorded in session metadata
- `thread_memory`: persisted summaries (trace + memory) when available
- `logs`: Codex internal tracing logs (level/target/message, file/line, optional `thread_id`)

Not stored here:

- The full conversational transcript / “readout” content. That still lives in rollout JSONL under `~/.codex/sessions/` (and `~/.codex/archived_sessions/`).

## Log capture availability

SQLite log capture depends on the Codex build:

- Codex TUI builds **after late Jan 2026** (for example `codex-cli 0.98.0`) write to `logs`.
- The Codex Desktop app’s app-server process does **not** currently write to `logs`, so the table may be empty even though `threads` updates.

If `logs` is empty, verify you’re using a recent TUI build and that `features.sqlite = true` is enabled.

## End-of-turn hook (notify)

Codex supports a turn-complete hook that executes a command after each completed turn. Add to `~/.codex/config.toml`:

```toml
notify = ["path/to/your-script"]
```

Codex appends a JSON payload as the last argument (legacy wire format). The payload includes:

- `type` = `agent-turn-complete`
- `thread-id`
- `turn-id`
- `cwd`
- `input-messages` (array of user messages that initiated the turn)
- `last-assistant-message` (nullable)

Example payload:

```json
{
  "type": "agent-turn-complete",
  "thread-id": "b5f6c1c2-1111-2222-3333-444455556666",
  "turn-id": "12345",
  "cwd": "/Users/example/project",
  "input-messages": ["Rename `foo` to `bar` and update the callsites."],
  "last-assistant-message": "Rename complete and verified `cargo build` succeeds."
}
```

This hook is ideal for auditing or exporting per-turn metadata. For incremental log reads, store the last seen `logs.id` in a local file and query `id > last_log_id` on each hook run.

### Example: incremental logs on each turn

This script reads the last seen `logs.id` from a sidecar file, queries new rows, and updates the marker. It’s safe to run on every turn:

```sh
#!/bin/sh
set -eu

STATE_DB="${HOME}/.codex/state_2.sqlite"
STATE_DIR="${HOME}/.codex"
LAST_ID_FILE="${STATE_DIR}/last_log_id.txt"

last_id=0
if [ -f "${LAST_ID_FILE}" ]; then
  last_id="$(cat "${LAST_ID_FILE}")"
fi

# Query rows since last_id. Customize SELECT columns as needed.
sqlite3 "${STATE_DB}" "
  SELECT
    id,
    datetime(ts, 'unixepoch') AS ts_utc,
    level,
    target,
    thread_id,
    message
  FROM logs
  WHERE id > ${last_id}
  ORDER BY id ASC;
" > "${STATE_DIR}/log_delta.txt"

# Update last_id to the max id in the table (or keep last_id if empty).
new_last_id="$(sqlite3 "${STATE_DB}" "SELECT COALESCE(MAX(id), ${last_id}) FROM logs;")"
printf '%s\n' "${new_last_id}" > "${LAST_ID_FILE}"
```

Then point `notify` at the script:

```toml
notify = ["/path/to/your/notify_log_delta.sh"]
```

## Quick access with `sqlite3`

Inspect tables:

```sh
sqlite3 ~/.codex/state_2.sqlite '.tables'
```

List recent threads:

```sh
sqlite3 ~/.codex/state_2.sqlite "
  SELECT
    id,
    datetime(updated_at, 'unixepoch') AS updated_utc,
    source,
    model_provider,
    cwd,
    substr(title, 1, 80) AS title
  FROM threads
  ORDER BY updated_at DESC
  LIMIT 20;
"
```

Show latest internal logs:

```sh
sqlite3 ~/.codex/state_2.sqlite "
  SELECT
    id,
    datetime(ts, 'unixepoch') AS ts_utc,
    level,
    target,
    thread_id,
    message
  FROM logs
  ORDER BY id DESC
  LIMIT 200;
"
```

Filter logs for one session/thread:

```sh
THREAD_ID="00000000-0000-0000-0000-000000000000"
sqlite3 ~/.codex/state_2.sqlite "
  SELECT
    id,
    datetime(ts, 'unixepoch') AS ts_utc,
    level,
    target,
    message
  FROM logs
  WHERE thread_id = '${THREAD_ID}'
  ORDER BY id ASC;
"
```

## Tail logs with the built-in client (source build)

If you’re working from the Codex source repo, there’s a small log tailer that reads `state_2.sqlite`:

```sh
# from the codex repo root
just log -- --help
just log -- --level info --backfill 200
just log -- --thread-id <THREAD_ID>
```

Under the hood this runs:

```sh
cargo run -p codex-state --bin logs_client -- --help
```

## How this maps to “sessions”

Think of it as two layers:

1. **Rollouts (JSONL)** are the source of truth for the actual conversation artifacts (`~/.codex/sessions/*.jsonl`).
2. **SQLite state DB** is a query-friendly mirror of *metadata*, plus a structured stream of *internal tracing logs*.

In practice:

- Use `threads` to quickly find session ids, timestamps, cwd, git context, etc.
- Use `logs` (optionally filtered by `thread_id`) to debug execution/tooling issues around that session.
