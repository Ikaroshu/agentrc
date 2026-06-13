#!/usr/bin/env bash
# Sync Codex CLI settings and skills to a remote machine via scp.
# Copies AGENTS.md and skills directly. Merges config.toml so
# machine-specific project trust settings are preserved.
#
# Usage:
#   ./codex/sync-remote.sh mini

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$REPO_DIR/.." && pwd)"
REMOTE_CONFIG_FILE="$(mktemp)"

cleanup() {
  rm -f "$REMOTE_CONFIG_FILE"
}
trap cleanup EXIT

SHARED_SKILLS=(auto-research commit merge issue)

ssh "$REMOTE" '
  rm -f ~/.codex/commands/commit.md ~/.codex/commands/merge.md
  rmdir ~/.codex/commands 2>/dev/null || true
  rm -rf ~/.agents/skills/commit-workflow ~/.agents/skills/merge-workflow
  mkdir -p ~/.agents/skills/auto-research ~/.agents/skills/commit ~/.agents/skills/merge ~/.agents/skills/issue
'

# AGENTS.md: always overwrite (no machine-specific content)
scp -q "$REPO_DIR/AGENTS.md" "$REMOTE:~/.codex/AGENTS.md"
for skill in "${SHARED_SKILLS[@]}"; do
  scp -q "$ROOT_DIR/shared/skills/$skill/SKILL.md" "$REMOTE:~/.agents/skills/$skill/SKILL.md"
done

# config.toml: merge shared repo settings while preserving remote machine-specific
# sections such as project trust, notices, marketplaces, and skill path entries.
ssh "$REMOTE" 'cat ~/.codex/config.toml 2>/dev/null || true' > "$REMOTE_CONFIG_FILE"
python3 "$ROOT_DIR/scripts/merge-codex-config.py" "$REMOTE_CONFIG_FILE" "$REPO_DIR/config.toml" \
  | ssh "$REMOTE" 'cat > ~/.codex/config.toml'

echo "Sync complete -> $REMOTE"
