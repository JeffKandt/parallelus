#!/usr/bin/env bash
set -euo pipefail
printf '[interactive] helper launched at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

emit_heartbeats() {
  local phase=$1
  python3 - "$phase" <<'PY'
import sys, time, datetime
phase = sys.argv[1]
for idx in range(6):
    time.sleep(10)
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[interactive] {phase} heartbeat {idx + 1} {ts}", flush=True)
PY
}

printf '[interactive] entering pre-deliverable heartbeat window\n'
emit_heartbeats "pre-deliverable"
mkdir -p deliverables
printf 'interactive-success\n' > deliverables/result.txt
printf '{"files":["deliverables/result.txt"]}\n' > deliverables/.manifest
touch deliverables/.complete
printf '[interactive] deliverable recorded at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '[interactive] entering post-deliverable heartbeat window\n'
emit_heartbeats "post-deliverable"
printf '[interactive] ready for maintainer harvest/cleanup\n'
