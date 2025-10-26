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
printf '[interactive] delaying deliverable creation for 60s\n'
sleep 60
mkdir -p deliverables
printf 'interactive-success\n' > deliverables/result.txt
printf '{"files":["deliverables/result.txt"]}\n' > deliverables/.manifest
touch deliverables/.complete
printf '[interactive] deliverable recorded at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '[interactive] holding session open for 60s before completion\n'
sleep 60
printf '[interactive] ready for maintainer harvest/cleanup\n'
