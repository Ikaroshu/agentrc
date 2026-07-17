#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
CLAUDE_LOG="$TEST_DIR/claude-scp.log"
CODEX_LOG="$TEST_DIR/codex-scp.log"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"

cat >"$BIN_DIR/ssh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

command="${2:-}"

case "$command" in
  *"cat ~/.claude/settings.json"*) echo '{}' ;;
  *"cat ~/.codex/config.toml"*) ;;
  *"cat > ~/.claude/settings.json"*|*"cat > ~/.codex/config.toml"*) cat >/dev/null ;;
esac
EOF

cat >"$BIN_DIR/scp" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >>"$SYNC_SCP_LOG"
EOF

chmod +x "$BIN_DIR/ssh" "$BIN_DIR/scp"

PATH="$BIN_DIR:$PATH" SYNC_SCP_LOG="$CLAUDE_LOG" \
  "$ROOT_DIR/claude/sync-remote.sh" test >/dev/null
PATH="$BIN_DIR:$PATH" SYNC_SCP_LOG="$CODEX_LOG" \
  "$ROOT_DIR/codex/sync-remote.sh" test >/dev/null

failed=0

require_synced_skill() {
  local log="$1"
  local agent="$2"
  local skill="$3"

  if ! grep -Fq "/shared/skills/$skill/SKILL.md" "$log"; then
    echo "$agent remote sync omitted shared skill: $skill" >&2
    failed=1
  fi
}

require_not_synced() {
  local log="$1"
  local agent="$2"
  local pattern="$3"

  if grep -Fq "$pattern" "$log"; then
    echo "$agent remote sync unexpectedly included local-only review pilot: $pattern" >&2
    failed=1
  fi
}

for skill in brainstorming implement; do
  require_synced_skill "$CLAUDE_LOG" "Claude" "$skill"
  require_synced_skill "$CODEX_LOG" "Codex" "$skill"
done

for log_and_agent in "$CLAUDE_LOG:Claude" "$CODEX_LOG:Codex"; do
  log="${log_and_agent%%:*}"
  agent="${log_and_agent##*:}"
  require_not_synced "$log" "$agent" "/shared/skills/adversarial-doc-review/"
  require_not_synced "$log" "$agent" "/shared/skills/code-review/"
  require_not_synced "$log" "$agent" "/omp/"
  require_not_synced "$log" "$agent" "omp-review.rules"
done
require_not_synced "$CLAUDE_LOG" "Claude" "/claude/CLAUDE.md"
require_not_synced "$CODEX_LOG" "Codex" "/codex/AGENTS.md"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "Remote sync skill test passed."
