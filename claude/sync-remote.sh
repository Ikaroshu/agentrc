#!/usr/bin/env bash
# Sync active Claude Code settings, subagents, and skills to a remote machine.
# Machine-specific remote settings are preserved by merging them with the portable source.

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
REMOTE_SETTINGS_FILE="$(mktemp)"

cleanup() {
  rm -f "$REMOTE_SETTINGS_FILE"
}
trap cleanup EXIT

SKILLS=()
REMOTE_DIRS="~/.claude/agents"
for skill_dir in "$REPO_DIR"/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill="${skill_dir##*/}"
    SKILLS+=("$skill")
    REMOTE_DIRS+=" ~/.claude/skills/$skill"
  fi
done

ssh "$REMOTE" "mkdir -p $REMOTE_DIRS"

scp -q "$REPO_DIR/AGENTS.md" "$REMOTE:~/.claude/CLAUDE.md"
scp -q "$REPO_DIR/statusline.sh" "$REMOTE:~/.claude/statusline.sh"
for agent_file in "$REPO_DIR"/agents/*.md; do
  scp -q "$agent_file" "$REMOTE:~/.claude/agents/${agent_file##*/}"
done

for skill in "${SKILLS[@]}"; do
  scp -q "$REPO_DIR/skills/$skill/SKILL.md" "$REMOTE:~/.claude/skills/$skill/SKILL.md"
done
ssh "$REMOTE" 'cat ~/.claude/settings.json 2>/dev/null || true' >"$REMOTE_SETTINGS_FILE"
python3 "$ROOT_DIR/scripts/merge-claude-settings.py" "$REMOTE_SETTINGS_FILE" "$REPO_DIR/settings.json" \
  | ssh "$REMOTE" 'cat > ~/.claude/settings.json'

echo "Sync complete -> $REMOTE"
