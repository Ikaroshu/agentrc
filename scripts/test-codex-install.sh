#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
MIGRATION_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME" "$MIGRATION_HOME"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME/.codex"
mkdir -p "$TEST_HOME/.codex/rules"
cat >"$TEST_HOME/.codex/config.toml" <<'EOF'
model = "machine-model"
machine_marker = true

[projects."/machine/project"]
trust_level = "trusted"
EOF
cat >"$TEST_HOME/.codex/rules/default.rules" <<'EOF'
prefix_rule(pattern=["existing"], decision="allow")
EOF
ln -s "$ROOT_DIR/codex/rules/claude-review.rules" "$TEST_HOME/.codex/rules/claude-review.rules"

HOME="$TEST_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

if [ -L "$TEST_HOME/.codex/config.toml" ]; then
  echo "Expected a real local Codex config file" >&2
  exit 1
fi

grep -F 'model = "gpt-5.5"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F 'machine_marker = true' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '[projects."/machine/project"]' "$TEST_HOME/.codex/config.toml" >/dev/null

RULE_TARGET="$TEST_HOME/.codex/rules/claude-review.rules"
if [ ! -f "$RULE_TARGET" ] || [ -L "$RULE_TARGET" ]; then
  echo "Expected managed Codex rule to be a regular file: $RULE_TARGET" >&2
  exit 1
fi
if ! cmp -s "$RULE_TARGET" "$ROOT_DIR/codex/rules/claude-review.rules"; then
  echo "Managed Codex rule does not match its source" >&2
  exit 1
fi
grep -F 'pattern=["existing"]' "$TEST_HOME/.codex/rules/default.rules" >/dev/null

mkdir -p "$MIGRATION_HOME/.codex"
ln -s "$ROOT_DIR/codex/config.toml" "$MIGRATION_HOME/.codex/config.toml"
HOME="$MIGRATION_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

if [ -L "$MIGRATION_HOME/.codex/config.toml" ]; then
  echo "Expected the tracked config symlink to be migrated to a real file" >&2
  exit 1
fi

grep -F 'model = "gpt-5.5"' "$MIGRATION_HOME/.codex/config.toml" >/dev/null

for skill in general-auto-research commit merge issue; do
  target="$TEST_HOME/.agents/skills/$skill"
  expected="$ROOT_DIR/shared/skills/$skill"

  if [ ! -L "$target" ]; then
    echo "Expected shared skill directory symlink: $target" >&2
    exit 1
  fi

  if [ "$(readlink "$target")" != "$expected" ]; then
    echo "Unexpected shared skill target for $skill: $(readlink "$target")" >&2
    echo "Expected: $expected" >&2
    exit 1
  fi
done

for skill in adversarial-doc-review claude-code-review; do
  target="$TEST_HOME/.agents/skills/$skill"
  expected="$ROOT_DIR/codex/skills/$skill"

  if [ ! -L "$target" ]; then
    echo "Expected Codex skill directory symlink: $target" >&2
    exit 1
  fi

  if [ "$(readlink "$target")" != "$expected" ]; then
    echo "Unexpected Codex skill target for $skill: $(readlink "$target")" >&2
    echo "Expected: $expected" >&2
    exit 1
  fi
done

echo "Codex installer test passed."
