#!/usr/bin/env bash
# Sync active pi settings, extensions, and skills to a remote machine.
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
REMOTE_DIRS="~/.pi/agent/extensions"
for skill_dir in "$REPO_DIR"/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill="${skill_dir##*/}"
    SKILLS+=("$skill")
    REMOTE_DIRS+=" ~/.pi/agent/skills/$skill"
  fi
done

ssh "$REMOTE" "mkdir -p $REMOTE_DIRS"

scp -q "$REPO_DIR/AGENTS.md" "$REMOTE:~/.pi/agent/AGENTS.md"
scp -q "$REPO_DIR/web-search.json" "$REMOTE:~/.pi/agent/web-search.json"
for extension_file in "$REPO_DIR"/extensions/*.ts; do
  scp -q "$extension_file" "$REMOTE:~/.pi/agent/extensions/${extension_file##*/}"
done

for skill in "${SKILLS[@]}"; do
  scp -q "$REPO_DIR/skills/$skill/SKILL.md" "$REMOTE:~/.pi/agent/skills/$skill/SKILL.md"
done
ssh "$REMOTE" 'cat ~/.pi/agent/settings.json 2>/dev/null || true' >"$REMOTE_SETTINGS_FILE"
python3 "$ROOT_DIR/scripts/merge-pi-settings.py" "$REMOTE_SETTINGS_FILE" "$REPO_DIR/settings.json" \
  | ssh "$REMOTE" 'cat > ~/.pi/agent/settings.json'

echo "Sync complete -> $REMOTE"
