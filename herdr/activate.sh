#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
export HERDR_BIN_PATH="$(command -v herdr)"
herdr server reload-config

RENAME_ROOT="$(jq -r '.[] | select(.plugin_id == "herdr-automatic-rename") | .plugin_root' "$HOME/.config/herdr/plugins.json")"
bash "$RENAME_ROOT/automatic-rename.sh"
herdr config check
herdr agent list
