#!/usr/bin/env bash
# Install pi settings, extensions, and skills from this repository.
# Machine-local settings are merged; managed instructions, extensions, and skills are symlinked.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
PI_TARGET_DIR="$HOME/.pi/agent"

link_path() {
  local src="$1"
  local dst="$2"
  local rel="$3"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  OK $rel"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "BACK $rel -> $dst.bak"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK $rel"
}

install_settings() {
  local dst="$PI_TARGET_DIR/settings.json"
  local current
  local merged

  mkdir -p "$PI_TARGET_DIR"
  current="$(mktemp)"
  merged="$(mktemp)"

  if [ -e "$dst" ]; then
    cp "$dst" "$current"
  fi

  python3 "$ROOT_DIR/scripts/merge-pi-settings.py" "$current" "$REPO_DIR/settings.json" >"$merged"
  rm "$current"

  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$merged" "$dst"; then
    rm "$merged"
    echo "  OK settings.json"
    return
  fi

  if [ -L "$dst" ]; then
    rm "$dst"
  fi

  mv "$merged" "$dst"
  echo "MERGE settings.json"
}

echo "Installing pi settings from $REPO_DIR -> $PI_TARGET_DIR"
echo

link_path "$REPO_DIR/AGENTS.md" "$PI_TARGET_DIR/AGENTS.md" "AGENTS.md"
link_path "$REPO_DIR/web-search.json" "$PI_TARGET_DIR/web-search.json" "web-search.json"
for extension_file in "$REPO_DIR"/extensions/*.ts; do
  extension="${extension_file##*/}"
  link_path "$extension_file" "$PI_TARGET_DIR/extensions/$extension" "extensions/$extension"
done
install_settings

echo
echo "Installing pi skills from $REPO_DIR/skills -> $PI_TARGET_DIR/skills"
echo

for skill_dir in "$REPO_DIR"/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill="${skill_dir##*/}"
    link_path "$skill_dir" "$PI_TARGET_DIR/skills/$skill" "$skill"
  fi
done

echo
echo "Done. pi settings are installed from this repository."
