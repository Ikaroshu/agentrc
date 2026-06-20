#!/usr/bin/env bash
# Install Codex CLI settings and skills by symlinking from home paths to this repo.
# Safe: backs up existing files before replacing, skips files already linked.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
CODEX_TARGET_DIR="$HOME/.codex"
SKILLS_TARGET_DIR="$HOME/.agents/skills"

CODEX_FILES=(
  AGENTS.md
  config.toml
)

SKILLS=(
  auto-research
  adversarial-doc-review
  claude-code-review
  commit
  merge
  issue
)

is_shared_skill() {
  case "$1" in
    auto-research|commit|merge|issue) return 0 ;;
    *) return 1 ;;
  esac
}

skill_source() {
  local name="$1"

  if is_shared_skill "$name"; then
    echo "$ROOT_DIR/shared/skills/$name"
  else
    echo "$REPO_DIR/skills/$name"
  fi
}

link_file() {
  local rel="$1"
  local src="$REPO_DIR/$rel"
  local dst="$CODEX_TARGET_DIR/$rel"

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
    echo "BACK $rel -> $dst.bak"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK $rel"
}

link_path() {
  local src="$1"
  local dst="$2"
  local rel="$3"

  if [ ! -e "$src" ]; then
    echo "SKIP $rel (source missing)"
    return
  fi

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

cleanup_legacy_command() {
  local rel="$1"
  local dst="$CODEX_TARGET_DIR/$rel"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$REPO_DIR/$rel" ]; then
    rm "$dst"
    echo "DROP legacy $rel"
  fi
}

echo "Installing Codex settings from $REPO_DIR -> $CODEX_TARGET_DIR"
echo

for f in "${CODEX_FILES[@]}"; do
  link_file "$f"
done

cleanup_legacy_command "commands/commit.md"
cleanup_legacy_command "commands/merge.md"
rmdir "$CODEX_TARGET_DIR/commands" 2>/dev/null || true

echo
echo "Installing Codex skills from $REPO_DIR/skills -> $SKILLS_TARGET_DIR"
echo

for skill in "${SKILLS[@]}"; do
  link_path "$(skill_source "$skill")" "$SKILLS_TARGET_DIR/$skill" "$skill"
done

# Drop legacy skill symlinks now replaced by the shared commit/merge skills
for legacy in commit-workflow merge-workflow; do
  dst="$SKILLS_TARGET_DIR/$legacy"
  if [ -L "$dst" ]; then
    rm "$dst"
    echo "DROP legacy skill $legacy"
  fi
done

echo
echo "Done. Settings are now symlinked to this repo."
