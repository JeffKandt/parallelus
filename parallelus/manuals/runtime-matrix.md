# Runtime Support Matrix

The `parallelus/engine` scripts are designed to run on macOS laptops, Codex Cloud (Linux),
and CI. Degraded paths fall back to log-only behaviour instead of failing.

| Capability | macOS (local) | Codex Cloud (Linux) | CI / Headless |
| --- | --- | --- | --- |
| Audible alerts | `say` → `afplay` → BEL | BEL / `paplay` if available | BEL/log only |
| Virtualenv | `python3 -m venv` in repo | Same | Same |
| Default shell | `bash` via `/usr/bin/env` | `bash` | `bash` |
| GUI prompts | Not required | Not available | Not available |
| Remote detection | Full git remote access | Full | Full |
| Audio deps (`ffmpeg`) | Expected via Homebrew | Expected via apt/pkg cache | Provide via CI image |
| SSH heartbeat | `m4-mac-mini` check | Works if credentials configured | Usually disabled |

**Notes**
- When `CI=true` or no TTY is detected, audible alerts degrade to BEL/log.
- The Python adapter auto-creates `.venv`; ensure system Python is available.
- For Codex Cloud sandboxes, use `eval "$(make start_session)"` first to confirm repo
  mode before editing snapshots.
