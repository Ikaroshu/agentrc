#!/usr/bin/env bash
# Sync the OMP review profile and normal OMP settings to a remote machine.

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"

ssh "$REMOTE" '
  if command -v omp >/dev/null 2>&1; then
    OMP_BIN="$(command -v omp)"
  elif [ -x "$HOME/.local/bin/omp" ]; then
    OMP_BIN="$HOME/.local/bin/omp"
  else
    echo "OMP executable not found on remote" >&2
    exit 1
  fi

  if ! grep -q "^OPENROUTER_API_KEY=" "$HOME/.omp/agent/.env" 2>/dev/null; then
    echo "OPENROUTER_API_KEY not found in remote ~/.omp/agent/.env" >&2
    exit 1
  fi

  mkdir -p "$HOME/.omp/profiles/review/agent"
  chmod 700 "$HOME/.omp" "$HOME/.omp/agent" "$HOME/.omp/profiles/review/agent"

  env -u OMP_PROFILE "$OMP_BIN" config set tools.approvalMode write >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enabled true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enableSkillCommands true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enableCodexUser true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enableClaudeUser true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enableClaudeProject true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enablePiUser true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enablePiProject true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enableAgentsUser true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set skills.enableAgentsProject true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set mcp.enableProjectConfig true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set commands.enableClaudeUser true >/dev/null
  env -u OMP_PROFILE "$OMP_BIN" config set commands.enableClaudeProject true >/dev/null
'

scp -q \
  "$ROOT_DIR/shared/AGENTS.md" \
  "$REPO_DIR/config.yml" \
  "$REPO_DIR/models.yml" \
  "$REMOTE:~/.omp/profiles/review/agent/"

ssh "$REMOTE" '
  ln -sfn "$HOME/.omp/agent/.env" "$HOME/.omp/profiles/review/agent/.env"
  chmod 600 "$HOME/.omp/agent/.env"
'

echo "Sync complete -> $REMOTE"
