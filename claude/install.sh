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
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
TARGET_DIR="$HOME/.claude"

# Files to symlink (relative to claude/ in the repo and ~/.claude/)
FILES=(
  settings.json
  CLAUDE.md
  file-suggestion.sh
  statusline-command.sh
  skills/general-auto-research/SKILL.md
  skills/brainstorming/SKILL.md
  skills/planning/SKILL.md
  skills/commit/SKILL.md
  skills/implement/SKILL.md
  skills/merge/SKILL.md
  skills/issue/SKILL.md
  skills/adversarial-doc-review/SKILL.md
  skills/code-review/SKILL.md
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

install_review_runner() {
  local source="$1"
  local target="$2"
  local name
  name="$(basename "$target")"
  mkdir -p "$(dirname "$target")"

  if [ -f "$target" ] &&
     [ ! -L "$target" ] &&
     cmp -s "$source" "$target"; then
    chmod +x "$target"
    echo "  OK $name"
    return
  fi

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -f "$target" ]; then
    mv "$target" "$target.bak"
    echo "BACK $name -> $target.bak"
  fi

  cp "$source" "$target"
  chmod +x "$target"
  echo "COPY $name"
}

echo "Installing Claude settings from $REPO_DIR → $TARGET_DIR"
echo

for f in "${FILES[@]}"; do
  link_file "$f"
done
install_review_runner \
  "$ROOT_DIR/shared/skills/adversarial-doc-review/scripts/agentrc-codex-doc-review" \
  "$HOME/.local/bin/agentrc-codex-doc-review"
install_review_runner \
  "$ROOT_DIR/shared/skills/code-review/scripts/agentrc-codex-code-review" \
  "$HOME/.local/bin/agentrc-codex-code-review"

# Drop legacy command symlinks now migrated to shared skills
for legacy in commit merge issue; do
  dst="$TARGET_DIR/commands/$legacy.md"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$REPO_DIR/commands/$legacy.md" ]; then
    rm "$dst"
    echo "DROP legacy commands/$legacy.md"
  fi
done
rmdir "$TARGET_DIR/commands" 2>/dev/null || true

# Drop the old auto-research skill link, renamed to general-auto-research
old_skill="$TARGET_DIR/skills/auto-research/SKILL.md"
if [ -L "$old_skill" ] && [ "$(readlink "$old_skill")" = "$REPO_DIR/skills/auto-research/SKILL.md" ]; then
  rm "$old_skill"
  rmdir "$TARGET_DIR/skills/auto-research" 2>/dev/null || true
  echo "DROP legacy skills/auto-research"
fi

old_review_skill="$TARGET_DIR/skills/codex-code-review/SKILL.md"
if [ -L "$old_review_skill" ]; then
  rm "$old_review_skill"
  rmdir "$TARGET_DIR/skills/codex-code-review" 2>/dev/null || true
  echo "DROP legacy skills/codex-code-review"
fi

# Ensure scripts are executable
chmod +x "$REPO_DIR/file-suggestion.sh" 2>/dev/null || true

echo
echo "Done. Settings are now symlinked to this repo."
