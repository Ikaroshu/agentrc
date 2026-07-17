#!/usr/bin/env bash
# Install all tracked agent settings on the local machine.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/omp/install.sh"
echo
"$ROOT_DIR/claude/install.sh"
echo
"$ROOT_DIR/codex/install.sh"
echo
"$ROOT_DIR/scripts/validate-config.sh"
