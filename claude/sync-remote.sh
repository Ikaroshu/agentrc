#!/usr/bin/env bash
# Sync Claude Code settings to a remote machine via ssh+rsync.
# Copies scripts/hooks/commands directly. Merges settings.json so
# machine-specific sections (env, permissions) are preserved.
#
# Usage:
#   ./claude/sync-remote.sh mini          # sync to 'mini'
#   ./claude/sync-remote.sh user@host     # sync to arbitrary host

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"

SHARED_SKILLS=(auto-research brainstorming commit implement merge issue)

# Directories to ensure exist on remote; drop legacy command files now migrated to skills
ssh "$REMOTE" '
  rm -f ~/.claude/commands/commit.md ~/.claude/commands/merge.md ~/.claude/commands/issue.md \
        ~/.claude/commands/commit.md.bak ~/.claude/commands/merge.md.bak ~/.claude/commands/issue.md.bak
  rmdir ~/.claude/commands 2>/dev/null || true
  mkdir -p \
    ~/.claude/skills/auto-research \
    ~/.claude/skills/brainstorming \
    ~/.claude/skills/commit \
    ~/.claude/skills/implement \
    ~/.claude/skills/merge \
    ~/.claude/skills/issue
'

# Sync non-settings files
scp -q \
  "$REPO_DIR/CLAUDE.md" \
  "$REPO_DIR/file-suggestion.sh" \
  "$REPO_DIR/statusline-command.sh" \
  "$REMOTE:~/.claude/"

for skill in "${SHARED_SKILLS[@]}"; do
  scp -q "$ROOT_DIR/shared/skills/$skill/SKILL.md" "$REMOTE:~/.claude/skills/$skill/"
done

# Merge settings.json: update shared keys, preserve machine-specific ones
REMOTE_SETTINGS=$(ssh "$REMOTE" 'cat ~/.claude/settings.json 2>/dev/null || echo "{}"')
REPO_SETTINGS=$(cat "$REPO_DIR/settings.json")

MERGED=$(python3 -c '
import json, sys

remote = json.loads(sys.argv[1])
repo = json.loads(sys.argv[2])

# Shared keys: take from repo (hooks, statusLine, fileSuggestion, enabledPlugins, effortLevel)
for key in ("hooks", "statusLine", "fileSuggestion", "effortLevel"):
    if key in repo:
        remote[key] = repo[key]

# Plugins: merge (keep remote-only plugins, add repo plugins)
remote_plugins = remote.get("enabledPlugins", {})
repo_plugins = repo.get("enabledPlugins", {})
remote["enabledPlugins"] = {**remote_plugins, **repo_plugins}

print(json.dumps(remote, indent=2))
' "$REMOTE_SETTINGS" "$REPO_SETTINGS")

echo "$MERGED" | ssh "$REMOTE" 'cat > ~/.claude/settings.json'

# Fix permissions on remote
ssh "$REMOTE" 'chmod +x ~/.claude/file-suggestion.sh ~/.claude/statusline-command.sh 2>/dev/null'

echo "Sync complete → $REMOTE"
