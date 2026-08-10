#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
SCP_LOG="$TEST_DIR/scp.log"
SSH_LOG="$TEST_DIR/ssh.log"
CODEX_SCP_LOG="$TEST_DIR/codex-scp.log"
CODEX_SSH_LOG="$TEST_DIR/codex-ssh.log"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"

cat >"$BIN_DIR/ssh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

command="${2:-}"
printf '%s\n' "$*" >>"$SYNC_SSH_LOG"

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

PATH="$BIN_DIR:$PATH" SYNC_SCP_LOG="$SCP_LOG" SYNC_SSH_LOG="$SSH_LOG" \
  "$ROOT_DIR/sync-remote.sh" test >/dev/null
PATH="$BIN_DIR:$PATH" SYNC_SCP_LOG="$CODEX_SCP_LOG" SYNC_SSH_LOG="$CODEX_SSH_LOG" \
  "$ROOT_DIR/codex/sync-remote.sh" test >/dev/null

failed=0

require_synced() {
  local description="$1"
  local pattern="$2"

  if ! grep -Fq "$pattern" "$SCP_LOG"; then
    echo "Remote sync omitted $description: $pattern" >&2
    failed=1
  fi
}

require_remote_command() {
  local description="$1"
  local pattern="$2"

  if ! grep -Fq "$pattern" "$SSH_LOG"; then
    echo "Remote sync omitted $description: $pattern" >&2
    failed=1
  fi
}

for skill in brainstorming planning implement; do
  require_synced "Claude skill $skill" "/shared/skills/$skill/SKILL.md test:~/.claude/skills/$skill/"
  require_synced "Codex skill $skill" "/shared/skills/$skill/SKILL.md test:~/.agents/skills/$skill/SKILL.md"
done

for skill in adversarial-doc-review code-review; do
  require_synced "Claude skill $skill" "/shared/skills/$skill/SKILL.md test:~/.claude/skills/$skill/"
  require_synced "Codex skill $skill" "/codex/skills/$skill/SKILL.md test:~/.agents/skills/$skill/SKILL.md"
done

for skill in claude-doc-review claude-code-review; do
  require_synced "Codex skill $skill" "/codex/skills/$skill/SKILL.md test:~/.agents/skills/$skill/SKILL.md"
done

require_synced "Claude instructions" "/claude/CLAUDE.md"
require_synced "Codex instructions" "/codex/AGENTS.md test:~/.codex/AGENTS.md"
require_synced "Codex document-review role" "/codex/agents/doc_reviewer.toml test:~/.codex/agents/doc_reviewer.toml"
require_synced "Codex code-review role" "/codex/agents/code_reviewer.toml test:~/.codex/agents/code_reviewer.toml"
require_remote_command "Codex agents directory creation" "mkdir -p ~/.codex/agents"
require_remote_command "obsolete Codex review rule removal" "rm -f ~/.codex/rules/codex-review.rules"
require_synced "managed document-review runner" \
  "/shared/skills/adversarial-doc-review/scripts/agentrc-codex-doc-review test:~/.local/bin/agentrc-codex-doc-review"
require_synced "managed code-review runner" \
  "/shared/skills/code-review/scripts/agentrc-codex-code-review test:~/.local/bin/agentrc-codex-code-review"
require_synced "Codex OMP review rule" "/codex/rules/omp-review.rules test:~/.codex/rules/omp-review.rules"
require_synced "Codex Claude review rule" "/codex/rules/claude-review.rules test:~/.codex/rules/claude-review.rules"
require_synced "OMP review instructions" "/shared/AGENTS.md"
require_synced "OMP review config" "/omp/config.yml"
require_synced "OMP review models" "/omp/models.yml"

for skill in adversarial-doc-review code-review; do
  if ! grep -Fq "/codex/skills/$skill/SKILL.md test:~/.agents/skills/$skill/SKILL.md" "$CODEX_SCP_LOG"; then
    echo "Codex-only sync omitted native skill $skill" >&2
    failed=1
  fi
done
if ! grep -Fq 'rm -f ~/.codex/rules/codex-review.rules' "$CODEX_SSH_LOG"; then
  echo "Codex-only sync omitted obsolete rule cleanup" >&2
  failed=1
fi
for unexpected in \
  agentrc-codex-doc-review \
  agentrc-codex-code-review \
  /codex/rules/codex-review.rules; do
  if grep -Fq "$unexpected" "$CODEX_SCP_LOG"; then
    echo "Codex-only sync unexpectedly deployed $unexpected" >&2
    failed=1
  fi
done
if grep -Fq '~/.local/bin' "$CODEX_SSH_LOG"; then
  echo "Codex-only sync unexpectedly managed shared runner binaries" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "Remote sync skill test passed."
