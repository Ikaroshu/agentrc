#!/usr/bin/env bash
# Install Claude Code settings, subagents, and skills from this repository.
# Machine-local settings are merged; managed instructions, subagents, and skills are symlinked.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
CLAUDE_TARGET_DIR="$HOME/.claude"

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
  local dst="$CLAUDE_TARGET_DIR/settings.json"
  local current
  local merged

  mkdir -p "$CLAUDE_TARGET_DIR"
  current="$(mktemp)"
  merged="$(mktemp)"

  if [ -e "$dst" ]; then
    cp "$dst" "$current"
  fi

  python3 "$ROOT_DIR/scripts/merge-claude-settings.py" "$current" "$REPO_DIR/settings.json" >"$merged"
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

echo "Installing Claude settings from $REPO_DIR -> $CLAUDE_TARGET_DIR"
echo

link_path "$REPO_DIR/AGENTS.md" "$CLAUDE_TARGET_DIR/CLAUDE.md" "CLAUDE.md"
link_path "$REPO_DIR/statusline.sh" "$CLAUDE_TARGET_DIR/statusline.sh" "statusline.sh"
for agent_file in "$REPO_DIR"/agents/*.md; do
  agent="${agent_file##*/}"
  link_path "$agent_file" "$CLAUDE_TARGET_DIR/agents/$agent" "agents/$agent"
done
install_settings

echo
echo "Installing Claude skills from $REPO_DIR/skills -> $CLAUDE_TARGET_DIR/skills"
echo

for skill_dir in "$REPO_DIR"/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill="${skill_dir##*/}"
    link_path "$skill_dir" "$CLAUDE_TARGET_DIR/skills/$skill" "$skill"
  fi
done

echo
echo "Done. Claude settings are installed from this repository."
