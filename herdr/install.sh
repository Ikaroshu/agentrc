#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
command -v herdr
command -v jq

python3 "$REPO_DIR/configure.py" "$@"

while read -r plugin source revision; do
  herdr plugin install "$source" --ref "$revision" --yes
done < "$REPO_DIR/plugins.tsv"

SIDEBAR_ROOT="$(jq -r '.[] | select(.plugin_id == "herdr-sidebar") | .plugin_root' "$HOME/.config/herdr/plugins.json")"
mkdir -p "$HOME/.local/bin"
ln -sfn "$SIDEBAR_ROOT/target/release/herdr-sidebar" "$HOME/.local/bin/herdr-sidebar"
herdr config check
echo 'Installed. Open a new shell, launch Herdr, then run herdr/activate.sh. See herdr/README.md for fonts and remote dependency paths.'
