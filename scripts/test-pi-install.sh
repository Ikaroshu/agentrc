#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
PI_DIR="$TEST_HOME/.pi/agent"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

mkdir -p "$PI_DIR/extensions" "$PI_DIR/skills/unrelated" "$PI_DIR/memory/daily" "$TEST_HOME/.claude"

cat >"$PI_DIR/settings.json" <<'EOF'
{
  "defaultModel": "machine-model",
  "lastChangelogVersion": "1.5.2",
  "packages": ["npm:pi-memory@0.4.1", "npm:machine-only@1.0.0"]
}
EOF
printf 'legacy instructions\n' >"$PI_DIR/AGENTS.md"
printf 'legacy guard\n' >"$PI_DIR/extensions/guard.ts"
printf 'unrelated extension\n' >"$PI_DIR/extensions/unrelated.ts"
printf 'unrelated skill\n' >"$PI_DIR/skills/unrelated/SKILL.md"
printf '{"anthropic": {}}\n' >"$PI_DIR/auth.json"
printf 'remembered fact\n' >"$PI_DIR/memory/MEMORY.md"
printf 'claude state\n' >"$TEST_HOME/.claude/settings.json"

cp "$PI_DIR/settings.json" "$TEST_HOME/settings-before.json"
cp "$PI_DIR/extensions/unrelated.ts" "$TEST_HOME/extension-before"
cp "$PI_DIR/skills/unrelated/SKILL.md" "$TEST_HOME/skill-before"
cp "$PI_DIR/auth.json" "$TEST_HOME/auth-before"
cp "$PI_DIR/memory/MEMORY.md" "$TEST_HOME/memory-before"
cp "$TEST_HOME/.claude/settings.json" "$TEST_HOME/claude-before"
python3 "$ROOT_DIR/scripts/merge-pi-settings.py" \
  "$TEST_HOME/settings-before.json" "$ROOT_DIR/pi/settings.json" >"$TEST_HOME/settings-expected.json"

HOME="$TEST_HOME" "$ROOT_DIR/pi/install.sh" >/dev/null
HOME="$TEST_HOME" "$ROOT_DIR/pi/install.sh" >/dev/null

if [ -L "$PI_DIR/settings.json" ] ||
   ! cmp -s "$TEST_HOME/settings-expected.json" "$PI_DIR/settings.json"; then
  echo "Installed pi settings do not match the expected baseline merge" >&2
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

expect_link "$PI_DIR/AGENTS.md" "$ROOT_DIR/pi/AGENTS.md"
expect_link "$PI_DIR/web-search.json" "$ROOT_DIR/pi/web-search.json"
for source in "$ROOT_DIR"/pi/extensions/*.ts; do
  expect_link "$PI_DIR/extensions/${source##*/}" "$source"
done
for source in "$ROOT_DIR"/pi/skills/*/SKILL.md; do
  skill_dir="${source%/SKILL.md}"
  expect_link "$PI_DIR/skills/${skill_dir##*/}" "$skill_dir"
done

if ! cmp -s "$PI_DIR/AGENTS.md.bak" <(printf 'legacy instructions\n') ||
   ! cmp -s "$PI_DIR/extensions/guard.ts.bak" <(printf 'legacy guard\n'); then
  echo "Expected replaced legacy pi files to be backed up" >&2
  exit 1
fi

preserved_paths=(
  ".pi/agent/extensions/unrelated.ts:extension-before"
  ".pi/agent/skills/unrelated/SKILL.md:skill-before"
  ".pi/agent/auth.json:auth-before"
  ".pi/agent/memory/MEMORY.md:memory-before"
  ".claude/settings.json:claude-before"
)
for pair in "${preserved_paths[@]}"; do
  if ! cmp -s "$TEST_HOME/${pair%%:*}" "$TEST_HOME/${pair#*:}"; then
    echo "pi install changed unrelated machine state: ${pair%%:*}" >&2
    exit 1
  fi
done

echo "Pi installer test passed (machine settings and unrelated state preserved)."
