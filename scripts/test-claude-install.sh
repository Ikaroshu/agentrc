#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

HOME="$TEST_HOME" "$ROOT_DIR/claude/install.sh" >/dev/null

for skill in adversarial-doc-review code-review; do
  source="$ROOT_DIR/claude/skills/$skill/SKILL.md"
  target="$TEST_HOME/.claude/skills/$skill/SKILL.md"

  if [ ! -f "$source" ] || [ -L "$source" ]; then
    echo "Expected regular Claude-owned review skill source: $source" >&2
    exit 1
  fi
  if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$source" ]; then
    echo "Unexpected installed Claude review skill target: $target" >&2
    exit 1
  fi
done

for skill in brainstorming planning implement; do
  source="$ROOT_DIR/claude/skills/$skill/SKILL.md"
  target="$TEST_HOME/.claude/skills/$skill/SKILL.md"

  if [ ! -L "$source" ] || [ ! -L "$target" ] ||
     [ "$(readlink "$target")" != "$source" ]; then
    echo "Expected unaffected shared Claude skill routing for $skill" >&2
    exit 1
  fi
done

for runner in agentrc-codex-doc-review agentrc-codex-code-review; do
  source="$ROOT_DIR/shared/review-runners/$runner"
  target="$TEST_HOME/.local/bin/$runner"

  if [ ! -f "$target" ] || [ -L "$target" ] || [ ! -x "$target" ]; then
    echo "Expected executable Claude-installed review runner: $target" >&2
    exit 1
  fi
  if ! cmp -s "$source" "$target"; then
    echo "Claude-installed review runner differs from shared source: $runner" >&2
    exit 1
  fi
done

echo "Claude installer test passed."
