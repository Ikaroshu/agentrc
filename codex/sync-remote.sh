#!/usr/bin/env bash
# Sync active Codex settings, native roles, and skills to a remote machine.
# Machine-specific remote config is preserved by merging it with the portable source.

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
REMOTE_CONFIG_FILE="$(mktemp)"

cleanup() {
  rm -f "$REMOTE_CONFIG_FILE"
}
trap cleanup EXIT

ROLE_FILES=()
for role_file in "$REPO_DIR"/agents/*.toml; do
  ROLE_FILES+=("${role_file##*/}")
done

SKILLS=()
REMOTE_DIRS="~/.codex/agents"
for skill_dir in "$REPO_DIR"/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill="${skill_dir##*/}"
    SKILLS+=("$skill")
    REMOTE_DIRS+=" ~/.agents/skills/$skill"
  fi
done

ssh "$REMOTE" "mkdir -p $REMOTE_DIRS"

scp -q "$REPO_DIR/AGENTS.md" "$REMOTE:~/.codex/AGENTS.md"
for role in "${ROLE_FILES[@]}"; do
  scp -q "$REPO_DIR/agents/$role" "$REMOTE:~/.codex/agents/$role"
done

for skill in "${SKILLS[@]}"; do
  scp -q "$REPO_DIR/skills/$skill/SKILL.md" "$REMOTE:~/.agents/skills/$skill/SKILL.md"
done
ssh "$REMOTE" 'cat ~/.codex/config.toml 2>/dev/null || true' >"$REMOTE_CONFIG_FILE"
python3 "$ROOT_DIR/scripts/merge-codex-config.py" "$REMOTE_CONFIG_FILE" "$REPO_DIR/config.toml" \
  | ssh "$REMOTE" 'cat > ~/.codex/config.toml'

echo "Sync complete -> $REMOTE"
