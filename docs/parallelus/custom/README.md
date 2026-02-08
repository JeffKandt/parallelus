# Parallelus Custom Hooks

Project-owned hook customizations live under this directory so they persist when
`parallelus/` (or `vendor/parallelus/`) is upgraded.

## Layout

```text
docs/parallelus/custom/
  config.yaml
  hooks/
    pre_bootstrap.sh
    post_bootstrap.sh
    pre_start_session.sh
    post_start_session.sh
    pre_turn_end.sh
    post_turn_end.sh
```

All files are optional. Missing files are treated as no-op.

## Config Schema

`config.yaml` supports:

- `version` (required integer; `1` for this contract)
- `enabled` (optional bool; default `true`)
- `hooks` (optional map keyed by hook event)
  - `enabled` (optional bool; default `true`)
  - `timeout_seconds` (optional int; default `30`)
  - `on_error` (`fail` or `warn`)

Default `on_error` behavior:

- `pre_*` hooks default to `fail`
- `post_*` hooks default to `warn`

Safety rule: `post_*` hook failures never abort already-completed parent work.

## Runtime Contract

Hooks execute with:

- CWD set to repository root
- executable `/bin/sh`
- environment variables:
  - `PARALLELUS_REPO_ROOT`
  - `PARALLELUS_BUNDLE_ROOT`
  - `PARALLELUS_EVENT`

Hook output is emitted with a `[custom-hook:<event>]` prefix.

Non-executable hook files are ignored with a warning.
