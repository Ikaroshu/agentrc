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

SKILLS=(
  adversarial-doc-review
  brainstorming
  planning
  code-review
  commit
  handoff
  implement
  merge
  issue
)

ssh "$REMOTE" 'mkdir -p ~/.codex/agents ~/.agents/skills/adversarial-doc-review ~/.agents/skills/brainstorming ~/.agents/skills/planning ~/.agents/skills/code-review ~/.agents/skills/commit ~/.agents/skills/handoff ~/.agents/skills/implement ~/.agents/skills/merge ~/.agents/skills/issue'

scp -q "$REPO_DIR/AGENTS.md" "$REMOTE:~/.codex/AGENTS.md"
scp -q "$REPO_DIR/agents/doc_reviewer.toml" "$REMOTE:~/.codex/agents/doc_reviewer.toml"
scp -q "$REPO_DIR/agents/code_reviewer.toml" "$REMOTE:~/.codex/agents/code_reviewer.toml"
scp -q "$REPO_DIR/agents/implementer.toml" "$REMOTE:~/.codex/agents/implementer.toml"
scp -q "$REPO_DIR/agents/research_worker.toml" "$REMOTE:~/.codex/agents/research_worker.toml"

for skill in "${SKILLS[@]}"; do
  scp -q "$REPO_DIR/skills/$skill/SKILL.md" "$REMOTE:~/.agents/skills/$skill/SKILL.md"
done
ssh "$REMOTE" 'cat ~/.codex/config.toml 2>/dev/null || true' >"$REMOTE_CONFIG_FILE"
python3 "$ROOT_DIR/scripts/merge-codex-config.py" "$REMOTE_CONFIG_FILE" "$REPO_DIR/config.toml" \
  | ssh "$REMOTE" 'cat > ~/.codex/config.toml'

echo "Sync complete -> $REMOTE"
