#!/usr/bin/env bash
set -euo pipefail
printf '[interactive] starting long job at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
for i in 1 2 3; do
  printf '[interactive] heartbeat %d %s\n' "$i" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  sleep 6
done
printf '[interactive] Ready for reviewer confirmation (type EXACT ACK to continue)\n'
read -r response
printf '[interactive] received response: %s\n' "$response"
if [[ "$response" != "ACK" ]]; then
  printf '[interactive] unexpected reply; exiting with error\n' >&2
  exit 42
fi
mkdir -p deliverables
printf 'interactive-success\n' > deliverables/result.txt
printf '{"files":["deliverables/result.txt"]}\n' > deliverables/.manifest
touch deliverables/.complete
printf '[interactive] deliverable recorded at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
