#!/usr/bin/env bash
# Install Codex CLI settings by symlinking from ~/.codex/ to this repo.
# Safe: backs up existing files before replacing, skips files already linked.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.codex"

FILES=(
  AGENTS.md
  config.toml
)

link_file() {
  local rel="$1"
  local src="$REPO_DIR/$rel"
  local dst="$TARGET_DIR/$rel"

  if [ ! -f "$src" ]; then
    echo "SKIP $rel (source missing)"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  OK $rel"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "BACK $rel → $dst.bak"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK $rel"
}

echo "Installing Codex settings from $REPO_DIR → $TARGET_DIR"
echo

for f in "${FILES[@]}"; do
  link_file "$f"
done

echo
echo "Done. Settings are now symlinked to this repo."
