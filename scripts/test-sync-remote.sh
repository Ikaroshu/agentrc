#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
SCP_LOG="$TEST_DIR/scp.log"

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

PATH="$BIN_DIR:$PATH" SYNC_SCP_LOG="$SCP_LOG" \
  "$ROOT_DIR/sync-remote.sh" test >/dev/null

failed=0

require_synced() {
  local description="$1"
  local pattern="$2"

  if ! grep -Fq "$pattern" "$SCP_LOG"; then
    echo "Remote sync omitted $description: $pattern" >&2
    failed=1
  fi
}

for skill in brainstorming implement adversarial-doc-review code-review; do
  require_synced "Claude skill $skill" "/shared/skills/$skill/SKILL.md test:~/.claude/skills/$skill/"
  require_synced "Codex skill $skill" "/shared/skills/$skill/SKILL.md test:~/.agents/skills/$skill/SKILL.md"
done

require_synced "Claude instructions" "/claude/CLAUDE.md"
require_synced "Codex instructions" "/codex/AGENTS.md test:~/.codex/AGENTS.md"
require_synced "Codex OMP review rule" "/codex/rules/omp-review.rules test:~/.codex/rules/omp-review.rules"
require_synced "OMP review instructions" "/shared/AGENTS.md"
require_synced "OMP review config" "/omp/config.yml"
require_synced "OMP review models" "/omp/models.yml"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "Remote sync skill test passed."
