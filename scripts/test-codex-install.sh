#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

HOME="$TEST_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

for skill in auto-research commit merge issue; do
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
