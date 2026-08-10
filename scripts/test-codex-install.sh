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
mkdir -p "$TEST_HOME/.local/bin"
cat >"$TEST_HOME/.codex/config.toml" <<'EOF'
model = "machine-model"
machine_marker = true
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true

[projects."/machine/project"]
trust_level = "trusted"
EOF
cat >"$TEST_HOME/.codex/rules/default.rules" <<'EOF'
prefix_rule(pattern=["existing"], decision="allow")
EOF
cat >"$TEST_HOME/.codex/rules/custom.rules" <<'EOF'
prefix_rule(pattern=["custom"], decision="allow")
EOF
cat >"$TEST_HOME/.codex/rules/codex-review.rules" <<'EOF'
obsolete managed rule
EOF
for runner in agentrc-codex-doc-review agentrc-codex-code-review; do
  printf 'owned outside Codex install: %s\n' "$runner" >"$TEST_HOME/.local/bin/$runner"
  chmod 700 "$TEST_HOME/.local/bin/$runner"
done
ln -s "$ROOT_DIR/codex/rules/claude-review.rules" "$TEST_HOME/.codex/rules/claude-review.rules"
HOME="$TEST_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

if [ -L "$TEST_HOME/.codex/config.toml" ]; then
  echo "Expected a real local Codex config file" >&2
  exit 1
fi

grep -F 'model = "gpt-5.6-sol"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F 'model_reasoning_effort = "xhigh"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F 'machine_marker = true' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F 'default_permissions = "workspace-customized"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '"~/.cache/uv" = "write"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '"~/Projects/agentrc/.git" = "write"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '"~/Projects/Portseer/.git" = "write"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '[permissions.workspace-customized.filesystem.":workspace_roots"]' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '".git" = "write"' "$TEST_HOME/.codex/config.toml" >/dev/null
grep -F '[projects."/machine/project"]' "$TEST_HOME/.codex/config.toml" >/dev/null

if grep -F 'sandbox_mode = "workspace-write"' "$TEST_HOME/.codex/config.toml" >/dev/null; then
  echo "Expected legacy sandbox_mode to be removed" >&2
  exit 1
fi

if grep -F '[sandbox_workspace_write]' "$TEST_HOME/.codex/config.toml" >/dev/null; then
  echo "Expected legacy sandbox_workspace_write table to be removed" >&2
  exit 1
fi

for rule in claude-review.rules omp-review.rules; do
  target="$TEST_HOME/.codex/rules/$rule"
  if [ ! -f "$target" ] || [ -L "$target" ]; then
    echo "Expected managed Codex rule to be a regular file: $target" >&2
    exit 1
  fi
  if ! cmp -s "$target" "$ROOT_DIR/codex/rules/$rule"; then
    echo "Managed Codex rule does not match its source: $rule" >&2
    exit 1
  fi
done
if [ -e "$TEST_HOME/.codex/rules/codex-review.rules" ] ||
   [ -L "$TEST_HOME/.codex/rules/codex-review.rules" ]; then
  echo "Expected obsolete managed Codex review rule to be removed" >&2
  exit 1
fi
for role in doc_reviewer.toml code_reviewer.toml; do
  target="$TEST_HOME/.codex/agents/$role"
  if [ ! -f "$target" ] || [ -L "$target" ]; then
    echo "Expected managed Codex role to be a regular file: $target" >&2
    exit 1
  fi
  if ! cmp -s "$target" "$ROOT_DIR/codex/agents/$role"; then
    echo "Managed Codex role does not match its source: $role" >&2
    exit 1
  fi
done
grep -F 'pattern=["existing"]' "$TEST_HOME/.codex/rules/default.rules" >/dev/null
grep -F 'pattern=["custom"]' "$TEST_HOME/.codex/rules/custom.rules" >/dev/null
for runner in agentrc-codex-doc-review agentrc-codex-code-review; do
  runner_target="$TEST_HOME/.local/bin/$runner"
  if [ ! -f "$runner_target" ] || [ -L "$runner_target" ] || [ ! -x "$runner_target" ]; then
    echo "Expected externally owned review runner to remain untouched: $runner_target" >&2
    exit 1
  fi
  grep -Fx "owned outside Codex install: $runner" "$runner_target" >/dev/null
done

mkdir -p "$MIGRATION_HOME/.codex"
ln -s "$ROOT_DIR/codex/config.toml" "$MIGRATION_HOME/.codex/config.toml"
HOME="$MIGRATION_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

if [ -L "$MIGRATION_HOME/.codex/config.toml" ]; then
  echo "Expected the tracked config symlink to be migrated to a real file" >&2
  exit 1
fi

grep -F 'model = "gpt-5.6-sol"' "$MIGRATION_HOME/.codex/config.toml" >/dev/null
grep -F 'model_reasoning_effort = "xhigh"' "$MIGRATION_HOME/.codex/config.toml" >/dev/null
for runner in agentrc-codex-doc-review agentrc-codex-code-review; do
  if [ -e "$MIGRATION_HOME/.local/bin/$runner" ] || [ -L "$MIGRATION_HOME/.local/bin/$runner" ]; then
    echo "Codex installer unexpectedly deployed review runner: $runner" >&2
    exit 1
  fi
done

for skill in general-auto-research brainstorming planning commit implement merge issue; do
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

for skill in adversarial-doc-review code-review claude-doc-review claude-code-review; do
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

  if [ ! -f "$expected/SKILL.md" ] || [ -L "$expected/SKILL.md" ]; then
    echo "Expected a regular Codex-owned skill source: $expected/SKILL.md" >&2
    exit 1
  fi
done

for skill in adversarial-doc-review code-review; do
  claude_source="$ROOT_DIR/claude/skills/$skill/SKILL.md"
  codex_source="$ROOT_DIR/codex/skills/$skill/SKILL.md"

  if [ ! -f "$claude_source" ] || [ -L "$claude_source" ]; then
    echo "Expected regular Claude-owned review skill source: $claude_source" >&2
    exit 1
  fi
  if cmp -s "$claude_source" "$codex_source"; then
    echo "Expected distinct Claude and Codex review transports: $skill" >&2
    exit 1
  fi
  if [ -e "$ROOT_DIR/shared/skills/$skill" ] || [ -L "$ROOT_DIR/shared/skills/$skill" ]; then
    echo "Expected obsolete shared review skill to be absent: $skill" >&2
    exit 1
  fi
done

echo "Codex installer test passed."
