#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
MIGRATION_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME" "$MIGRATION_HOME"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME/.codex/rules" "$TEST_HOME/.agents/skills/unrelated" "$TEST_HOME/.claude" "$TEST_HOME/.omp/agent"

cat >"$TEST_HOME/.codex/config.toml" <<'EOF'
model = "machine-model"
machine_marker = true
approval_policy = "never"
default_permissions = "machine-policy"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true

[permissions.machine-policy]
extends = ":workspace"

[projects."/machine/project"]
trust_level = "trusted"

[plugins."machine-plugin"]
enabled = true

[[skills.config]]
path = "/machine/skill/SKILL.md"
enabled = false

[features]
memories = false
EOF
printf 'prefix_rule(pattern=["custom"], decision="allow")\n' >"$TEST_HOME/.codex/rules/custom.rules"
printf 'unrelated skill\n' >"$TEST_HOME/.agents/skills/unrelated/SKILL.md"
printf 'legacy claude state\n' >"$TEST_HOME/.claude/settings.json"
printf 'legacy omp state\n' >"$TEST_HOME/.omp/agent/.env"

cp "$TEST_HOME/.codex/config.toml" "$TEST_HOME/config-before.toml"
cp "$TEST_HOME/.codex/rules/custom.rules" "$TEST_HOME/rules-before"
cp "$TEST_HOME/.agents/skills/unrelated/SKILL.md" "$TEST_HOME/skill-before"
cp "$TEST_HOME/.claude/settings.json" "$TEST_HOME/claude-before"
cp "$TEST_HOME/.omp/agent/.env" "$TEST_HOME/omp-before"
python3 "$ROOT_DIR/scripts/merge-codex-config.py" "$TEST_HOME/config-before.toml" "$ROOT_DIR/codex/config.toml" >"$TEST_HOME/config-expected.toml"

HOME="$TEST_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

if [ -L "$TEST_HOME/.codex/config.toml" ] ||
   ! cmp -s "$TEST_HOME/config-expected.toml" "$TEST_HOME/.codex/config.toml"; then
  echo "Installed Codex config does not match the expected baseline merge" >&2
  exit 1
fi

if [ ! -L "$TEST_HOME/.codex/AGENTS.md" ] ||
   [ "$(readlink "$TEST_HOME/.codex/AGENTS.md")" != "$ROOT_DIR/codex/AGENTS.md" ]; then
  echo "Expected Codex instructions to link to the active regular source" >&2
  exit 1
fi

for role in doc_reviewer.toml code_reviewer.toml implementer.toml research_worker.toml; do
  target="$TEST_HOME/.codex/agents/$role"
  if [ ! -f "$target" ] || [ -L "$target" ] ||
     ! cmp -s "$target" "$ROOT_DIR/codex/agents/$role"; then
    echo "Expected exact regular Codex role copy: $role" >&2
    exit 1
  fi
done

for skill in adversarial-doc-review brainstorming planning code-review commit implement merge issue; do
  target="$TEST_HOME/.agents/skills/$skill"
  expected="$ROOT_DIR/codex/skills/$skill"
  if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$expected" ]; then
    echo "Unexpected active Codex skill link: $skill" >&2
    exit 1
  fi
done
if [ -e "$TEST_HOME/.agents/skills/general-auto-research" ]; then
  echo "Installer recreated retired general-auto-research skill" >&2
  exit 1
fi

preserved_paths=(
  ".codex/rules/custom.rules:rules-before"
  ".agents/skills/unrelated/SKILL.md:skill-before"
  ".claude/settings.json:claude-before"
  ".omp/agent/.env:omp-before"
)
for pair in "${preserved_paths[@]}"; do
  installed="${pair%%:*}"
  before="${pair#*:}"
  if ! cmp -s "$TEST_HOME/$installed" "$TEST_HOME/$before"; then
    echo "Codex install changed unrelated machine state: $installed" >&2
    exit 1
  fi
done

mkdir -p "$MIGRATION_HOME/.codex"
ln -s "$ROOT_DIR/codex/config.toml" "$MIGRATION_HOME/.codex/config.toml"
HOME="$MIGRATION_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null
if [ -L "$MIGRATION_HOME/.codex/config.toml" ]; then
  echo "Expected a tracked config symlink to migrate to a regular merged file" >&2
  exit 1
fi

echo "Codex installer test passed (machine capabilities and unrelated state preserved)."
