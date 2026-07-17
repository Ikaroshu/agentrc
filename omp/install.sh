#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.omp/profiles/review/agent"
DEFAULT_ENV="$HOME/.omp/agent/.env"
OMP_BIN="${OMP_BIN:-omp}"

link_file() {
  local name="$1"
  local src="$REPO_DIR/$name"
  local dst="$TARGET_DIR/$name"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  OK $name"
    return
  fi

  mkdir -p "$TARGET_DIR"

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "BACK $name -> $dst.bak"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK $name"
}

link_env() {
  local dst="$TARGET_DIR/.env"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$DEFAULT_ENV" ]; then
    echo "  OK .env"
    return
  fi

  mkdir -p "$TARGET_DIR" "$(dirname "$DEFAULT_ENV")"

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "BACK .env -> $dst.bak"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$DEFAULT_ENV" "$dst"
  echo "LINK .env -> $DEFAULT_ENV"
}

configure_default_setting() {
  local key="$1"
  local value="$2"

  env -u OMP_PROFILE "$OMP_BIN" config set "$key" "$value" >/dev/null
  echo " SET $key=$value"
}

configure_default_omp() {
  if ! command -v "$OMP_BIN" >/dev/null 2>&1; then
    echo "OMP executable not found: $OMP_BIN" >&2
    return 1
  fi

  echo "Configuring normal OMP native harness discovery"
  configure_default_setting tools.approvalMode write
  configure_default_setting skills.enabled true
  configure_default_setting skills.enableSkillCommands true
  configure_default_setting skills.enableCodexUser true
  configure_default_setting skills.enableClaudeUser true
  configure_default_setting skills.enableClaudeProject true
  configure_default_setting skills.enablePiUser true
  configure_default_setting skills.enablePiProject true
  configure_default_setting skills.enableAgentsUser true
  configure_default_setting skills.enableAgentsProject true
  configure_default_setting mcp.enableProjectConfig true
  configure_default_setting commands.enableClaudeUser true
  configure_default_setting commands.enableClaudeProject true
}

echo "Installing local OMP review profile from $REPO_DIR -> $TARGET_DIR"
echo

configure_default_omp
echo
link_file AGENTS.md
link_file config.yml
link_file models.yml
link_env

echo
echo "Done. Put OPENROUTER_API_KEY only in $DEFAULT_ENV."
