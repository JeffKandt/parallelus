# tmux Setup for Parallelus

Parallelus expects to manage its own tmux workspace so the main agent and any subagents can share a deterministic environment. Use these guidelines when preparing an operator's machine or custom codex helper:

## Required tmux build
- Parallelus expects tmux **3.x** with proper sandbox permissions. macOS ships an older build, so compile tmux (3.3a or newer) from source and install it in a trusted location (`/usr/local/bin/tmux` works well).
- Avoid Homebrew builds; their hardened runtime entitlements often prevent Codex from spawning panes. Using your own compiled binary avoids those restrictions while keeping the executable under your control.
- Ensure the compiled tmux appears first in the `PATH` your Codex helper exports so Parallelus consistently targets the supported build.

## Per-repository sockets
- Parallelus relies on the `PARALLELUS_TMUX_SOCKET` environment variable to isolate sessions. Your launcher should create a dedicated socket per repo (for example, `~/.tmux-sockets/codex-<slug>.sock`) and export that path before invoking `make read_bootstrap` or other helpers.
- Use `parallelus/engine/bin/tmux-safe` whenever you call tmux from automation. It automatically applies `PARALLELUS_TMUX_SOCKET`, ensuring all subagent commands target the correct server.

## Clean shell environment
- Launch Codex inside a minimal environment: set `PATH` explicitly, clear `ZDOTDIR`, `ZSHENV`, `BASH_ENV`, and `ENV`, and disable other shell initialisation to avoid sourcing personal config.
- Export locale variables (`LANG`, `LC_ALL`) and terminal settings so tmux panes render correctly and tools expect UTF-8.

## Recommended helper pattern
```
# Pseudocode
TMUX_SOCK="$HOME/.tmux-sockets/codex-${slug}.sock"
mkdir -p "$HOME/.tmux-sockets" "$HOME/.z-noenv"
tmux -S "$TMUX_SOCK" has-session -t "$session" 2>/dev/null   || tmux -S "$TMUX_SOCK" new-session -d -s "$session" -n main

tmux -S "$TMUX_SOCK" set-environment -g PARALLELUS_TMUX_SOCKET "$TMUX_SOCK"
# ... set PATH, LANG, etc. ...
```
- After configuring the session, `tmux attach` so Codex runs inside the managed workspace and Parallelus can place subagent panes alongside the main agent. Verify `which tmux` inside the session to confirm the compiled binary is in use.

## Troubleshooting
- If subagents refuse to start, confirm the active tmux binary with `tmux -V` inside the session. On macOS you should see your compiled build (for example, `tmux 3.3a` at `/usr/local/bin/tmux`).
- Check `PARALLELUS_TMUX_SOCKET` is set inside the tmux environment (`tmux show-environment PARALLELUS_TMUX_SOCKET`). If unset, guardrails may spawn new servers unexpectedly.
- Ensure `parallelus/engine/bin/tmux-safe` is reachable in `PATH`; the subagent manager expects it when issuing tmux commands.

Keep this manual alongside any custom launcher scripts so future operators can reproduce the setup quickly.
