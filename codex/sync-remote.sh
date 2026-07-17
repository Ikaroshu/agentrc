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

SHARED_SKILLS=(general-auto-research brainstorming commit implement merge issue)
# The OMP-backed review pilot is local-only. Do not add review skills here.

ssh "$REMOTE" '
  rm -f ~/.codex/commands/commit.md ~/.codex/commands/merge.md
  rmdir ~/.codex/commands 2>/dev/null || true
  rm -rf ~/.agents/skills/commit-workflow ~/.agents/skills/merge-workflow ~/.agents/skills/auto-research
  mkdir -p ~/.codex/rules
  mkdir -p \
    ~/.agents/skills/general-auto-research \
    ~/.agents/skills/brainstorming \
    ~/.agents/skills/commit \
    ~/.agents/skills/implement \
    ~/.agents/skills/merge \
    ~/.agents/skills/issue
'

# Shared instructions and the OMP permission rule are part of the local-only
# review pilot, so keep their remote copies unchanged until rollout approval.
for skill in "${SHARED_SKILLS[@]}"; do
  scp -q "$ROOT_DIR/shared/skills/$skill/SKILL.md" "$REMOTE:~/.agents/skills/$skill/SKILL.md"
done
# config.toml: merge shared repo settings while preserving remote machine-specific
# sections such as project trust, notices, marketplaces, and skill path entries.
ssh "$REMOTE" 'cat ~/.codex/config.toml 2>/dev/null || true' > "$REMOTE_CONFIG_FILE"
python3 "$ROOT_DIR/scripts/merge-codex-config.py" "$REMOTE_CONFIG_FILE" "$REPO_DIR/config.toml" \
  | ssh "$REMOTE" 'cat > ~/.codex/config.toml'

echo "Sync complete -> $REMOTE"
