#!/usr/bin/env bash
set -euo pipefail
printf '[hung-failure] began at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '[hung-failure] encountered blocking external dependency; awaiting manual intervention\n'
sleep 600
