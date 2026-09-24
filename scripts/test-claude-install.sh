#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME/.claude/agents" "$TEST_HOME/.claude/skills/unrelated" "$TEST_HOME/.claude/skills/code-review" "$TEST_HOME/.codex"

cat >"$TEST_HOME/.claude/settings.json" <<'EOF'
{
  "model": "machine-model",
  "env": {"MACHINE_TOKEN": "secret"},
  "permissions": {"allow": ["Bash"], "defaultMode": "bypassPermissions"},
  "enabledPlugins": {"machine-plugin@marketplace": true},
  "statusLine": {"type": "command", "command": "legacy", "padding": 1}
}
EOF
printf 'legacy instructions\n' >"$TEST_HOME/.claude/CLAUDE.md"
printf 'legacy code review\n' >"$TEST_HOME/.claude/skills/code-review/SKILL.md"
printf 'unrelated agent\n' >"$TEST_HOME/.claude/agents/unrelated.md"
printf 'unrelated skill\n' >"$TEST_HOME/.claude/skills/unrelated/SKILL.md"
printf 'codex state\n' >"$TEST_HOME/.codex/config.toml"

cp "$TEST_HOME/.claude/settings.json" "$TEST_HOME/settings-before.json"
cp "$TEST_HOME/.claude/agents/unrelated.md" "$TEST_HOME/agent-before"
cp "$TEST_HOME/.claude/skills/unrelated/SKILL.md" "$TEST_HOME/skill-before"
cp "$TEST_HOME/.codex/config.toml" "$TEST_HOME/codex-before"
python3 "$ROOT_DIR/scripts/merge-claude-settings.py" \
  "$TEST_HOME/settings-before.json" "$ROOT_DIR/claude/settings.json" >"$TEST_HOME/settings-expected.json"

HOME="$TEST_HOME" "$ROOT_DIR/claude/install.sh" >/dev/null
HOME="$TEST_HOME" "$ROOT_DIR/claude/install.sh" >/dev/null

if [ -L "$TEST_HOME/.claude/settings.json" ] ||
   ! cmp -s "$TEST_HOME/settings-expected.json" "$TEST_HOME/.claude/settings.json"; then
  echo "Installed Claude settings do not match the expected baseline merge" >&2
  exit 1
fi

expect_link() {
  local target="$1"
  local source="$2"

  if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$source" ]; then
    echo "Expected ${target#"$TEST_HOME"/} to link to $source" >&2
    exit 1
  fi
}

expect_link "$TEST_HOME/.claude/CLAUDE.md" "$ROOT_DIR/claude/AGENTS.md"
expect_link "$TEST_HOME/.claude/statusline.sh" "$ROOT_DIR/claude/statusline.sh"
for source in "$ROOT_DIR"/claude/agents/*.md; do
  expect_link "$TEST_HOME/.claude/agents/${source##*/}" "$source"
done
for source in "$ROOT_DIR"/claude/skills/*/SKILL.md; do
  skill_dir="${source%/SKILL.md}"
  expect_link "$TEST_HOME/.claude/skills/${skill_dir##*/}" "$skill_dir"
done

if ! cmp -s "$TEST_HOME/.claude/CLAUDE.md.bak" <(printf 'legacy instructions\n') ||
   ! cmp -s "$TEST_HOME/.claude/skills/code-review.bak/SKILL.md" <(printf 'legacy code review\n'); then
  echo "Expected replaced legacy Claude files to be backed up" >&2
  exit 1
fi

preserved_paths=(
  ".claude/agents/unrelated.md:agent-before"
  ".claude/skills/unrelated/SKILL.md:skill-before"
  ".codex/config.toml:codex-before"
)
for pair in "${preserved_paths[@]}"; do
  if ! cmp -s "$TEST_HOME/${pair%%:*}" "$TEST_HOME/${pair#*:}"; then
    echo "Claude install changed unrelated machine state: ${pair%%:*}" >&2
    exit 1
  fi
done

echo "Claude installer test passed (machine settings and unrelated state preserved)."
