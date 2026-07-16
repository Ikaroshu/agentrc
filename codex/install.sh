#!/usr/bin/env bash
# Install Codex CLI settings and skills from this repo.
# Shared config is merged into the machine-local config; other files are symlinked.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
CODEX_TARGET_DIR="$HOME/.codex"
SKILLS_TARGET_DIR="$HOME/.agents/skills"

CODEX_LINK_FILES=(
  AGENTS.md
)

CODEX_COPY_FILES=(
  rules/claude-review.rules
)

SKILLS=(
  general-auto-research
  adversarial-doc-review
  brainstorming
  claude-code-review
  commit
  implement
  merge
  issue
)

is_shared_skill() {
  case "$1" in
    general-auto-research|brainstorming|commit|implement|merge|issue) return 0 ;;
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

copy_file() {
  local rel="$1"
  local src="$REPO_DIR/$rel"
  local dst="$CODEX_TARGET_DIR/$rel"

  if [ ! -f "$src" ]; then
    echo "SKIP $rel (source missing)"
    return
  fi

  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    echo "  OK $rel"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -f "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "BACK $rel -> $dst.bak"
  fi

  cp "$src" "$dst"
  echo "COPY $rel"
}

install_config() {
  local src="$REPO_DIR/config.toml"
  local dst="$CODEX_TARGET_DIR/config.toml"
  local current
  local merged

  mkdir -p "$CODEX_TARGET_DIR"
  current="$(mktemp)"
  merged="$(mktemp)"

  if [ -e "$dst" ]; then
    cp "$dst" "$current"
  fi

  python3 "$ROOT_DIR/scripts/merge-codex-config.py" "$current" "$src" >"$merged"

  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$merged" "$dst"; then
    rm "$current" "$merged"
    echo "  OK config.toml"
    return
  fi

  if [ -L "$dst" ]; then
    rm "$dst"
  fi

  mv "$merged" "$dst"
  rm "$current"
  echo "MERGE config.toml"
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

for f in "${CODEX_LINK_FILES[@]}"; do
  link_file "$f"
done
for f in "${CODEX_COPY_FILES[@]}"; do
  copy_file "$f"
done
install_config

cleanup_legacy_command "commands/commit.md"
cleanup_legacy_command "commands/merge.md"
rmdir "$CODEX_TARGET_DIR/commands" 2>/dev/null || true

echo
echo "Installing Codex skills from $REPO_DIR/skills -> $SKILLS_TARGET_DIR"
echo

for skill in "${SKILLS[@]}"; do
  link_path "$(skill_source "$skill")" "$SKILLS_TARGET_DIR/$skill" "$skill"
done

# Drop legacy skill symlinks replaced by renamed or shared skills
for legacy in commit-workflow merge-workflow auto-research; do
  dst="$SKILLS_TARGET_DIR/$legacy"
  if [ -L "$dst" ]; then
    rm "$dst"
    echo "DROP legacy skill $legacy"
  fi
done

echo
echo "Done. Settings are installed from this repo."
