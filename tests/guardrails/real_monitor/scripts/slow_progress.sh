#!/usr/bin/env bash
set -euo pipefail
for i in $(seq 1 10); do
  printf '[slow-progress] processing item %d %s\n' "$i" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  sleep 8
done
printf '[slow-progress] completed without deliverables %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
