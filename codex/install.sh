#!/usr/bin/env bash
# Install Codex CLI settings, native roles, and skills from this repository.
# Machine-local config is merged; managed instructions and skills are symlinked.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
CODEX_TARGET_DIR="$HOME/.codex"
SKILLS_TARGET_DIR="$HOME/.agents/skills"

CODEX_LINK_FILES=(
  AGENTS.md
)

CODEX_COPY_FILES=(
  agents/doc_reviewer.toml
  agents/code_reviewer.toml
  agents/implementer.toml
  agents/research_worker.toml
)

SKILLS=(
  adversarial-doc-review
  brainstorming
  planning
  code-review
  commit
  implement
  merge
  issue
)

link_file() {
  local rel="$1"
  local src="$REPO_DIR/$rel"
  local dst="$CODEX_TARGET_DIR/$rel"

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

echo "Installing Codex settings from $REPO_DIR -> $CODEX_TARGET_DIR"
echo

for file in "${CODEX_LINK_FILES[@]}"; do
  link_file "$file"
done
for file in "${CODEX_COPY_FILES[@]}"; do
  copy_file "$file"
done
install_config

echo
echo "Installing Codex skills from $REPO_DIR/skills -> $SKILLS_TARGET_DIR"
echo

for skill in "${SKILLS[@]}"; do
  link_path "$REPO_DIR/skills/$skill" "$SKILLS_TARGET_DIR/$skill" "$skill"
done

echo
echo "Done. Codex settings are installed from this repository."
