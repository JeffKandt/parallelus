#!/usr/bin/env bash
set -euo pipefail

# Resolve the current working directory (physical path). If this fails, the
# sandbox has already been removed or the session lost its cwd.
cwd=$(pwd -P 2>/dev/null || true)

if [[ -z "$cwd" ]]; then
  echo "sandbox status: working directory no longer accessible"
  exit 1
fi

if [[ -d "$cwd" ]]; then
  echo "sandbox status: present at $cwd"
else
  echo "sandbox status: removed"
fi
