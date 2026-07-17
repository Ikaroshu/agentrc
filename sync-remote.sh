#!/usr/bin/env bash
# Sync all tracked agent settings to a remote machine.

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/claude/sync-remote.sh" "$REMOTE"
echo
"$ROOT_DIR/codex/sync-remote.sh" "$REMOTE"
echo
"$ROOT_DIR/omp/sync-remote.sh" "$REMOTE"
