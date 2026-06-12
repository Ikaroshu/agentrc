#!/usr/bin/env bash
# Install Claude Code settings by symlinking from ~/.claude/ to this repo.
# Safe: backs up existing files before replacing, skips files already linked.
#
# Usage:
#   ./claude/install.sh          # install on local machine
#   ssh mini 'bash -s' < claude/install.sh   # won't work (needs repo path)
#
# For remote machines, use sync-remote.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude"

# Files to symlink (relative to claude/ in the repo and ~/.claude/)
FILES=(
  settings.json
  CLAUDE.md
  file-suggestion.sh
  statusline-command.sh
  commands/commit.md
  commands/merge.md
  commands/issue.md
  skills/auto-research/SKILL.md
  skills/adversarial-doc-review/SKILL.md
  skills/codex-code-review/SKILL.md
)

link_file() {
  local rel="$1"
  local src="$REPO_DIR/$rel"
  local dst="$TARGET_DIR/$rel"

  if [ ! -f "$src" ]; then
    echo "SKIP $rel (source missing)"
    return
  fi

  # Already correctly linked
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  OK $rel"
    return
  fi

  # Ensure parent dir exists
  mkdir -p "$(dirname "$dst")"

  # Back up existing file (not symlinks)
  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "BACK $rel → $dst.bak"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK $rel"
}

echo "Installing Claude settings from $REPO_DIR → $TARGET_DIR"
echo

for f in "${FILES[@]}"; do
  link_file "$f"
done

# Ensure scripts are executable
chmod +x "$REPO_DIR/file-suggestion.sh" 2>/dev/null || true

echo
echo "Done. Settings are now symlinked to this repo."
