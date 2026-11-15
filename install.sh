#!/usr/bin/env bash
# Install tracked Codex, Claude Code, and pi settings on the local machine.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/codex/install.sh"
echo
"$ROOT_DIR/claude/install.sh"
echo
"$ROOT_DIR/pi/install.sh"
echo
"$ROOT_DIR/scripts/validate-config.sh"
