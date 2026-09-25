#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
export HERDR_BIN_PATH="$(command -v herdr)"
command -v node
herdr server reload-config

RADAR_ROOT="$(jq -r '.[] | select(.plugin_id == "hhdebb.herdr-radar") | .plugin_root' "$HOME/.config/herdr/plugins.json")"
RENAME_ROOT="$(jq -r '.[] | select(.plugin_id == "herdr-automatic-rename") | .plugin_root' "$HOME/.config/herdr/plugins.json")"
# Use this shell's Node, including NVM, instead of the server's inherited PATH.
node "$RADAR_ROOT/bin/configure.js" --apply --reload
node "$RADAR_ROOT/bin/agent-state.js"
bash "$RENAME_ROOT/automatic-rename.sh"
herdr config check
herdr agent list
