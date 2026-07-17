#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
BIN_DIR="$TEST_HOME/bin"
OMP_CONFIG_LOG="$TEST_HOME/omp-config.log"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$TEST_HOME/.omp/agent" "$TEST_HOME/.omp/profiles/review/agent"
printf '%s\n' 'OPENROUTER_API_KEY=test-only' >"$TEST_HOME/.omp/agent/.env"
printf '%s\n' 'machine: true' >"$TEST_HOME/.omp/profiles/review/agent/config.yml"

cat >"$BIN_DIR/omp" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >>"$OMP_CONFIG_LOG"
EOF
chmod +x "$BIN_DIR/omp"

HOME="$TEST_HOME" OMP_BIN="$BIN_DIR/omp" OMP_CONFIG_LOG="$OMP_CONFIG_LOG" \
  "$ROOT_DIR/omp/install.sh" >/dev/null

for name in AGENTS.md config.yml models.yml; do
  target="$TEST_HOME/.omp/profiles/review/agent/$name"
  expected="$ROOT_DIR/omp/$name"

  if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$expected" ]; then
    echo "Unexpected OMP profile link for $name" >&2
    exit 1
  fi
done

if [ ! -f "$TEST_HOME/.omp/profiles/review/agent/config.yml.bak" ]; then
  echo "Expected existing OMP profile config backup" >&2
  exit 1
fi

env_link="$TEST_HOME/.omp/profiles/review/agent/.env"
if [ ! -L "$env_link" ] || [ "$(readlink "$env_link")" != "$TEST_HOME/.omp/agent/.env" ]; then
  echo "Unexpected OMP review profile env link" >&2
  exit 1
fi

grep -Fx 'OPENROUTER_API_KEY=test-only' "$TEST_HOME/.omp/agent/.env" >/dev/null

for setting in \
  'tools.approvalMode write' \
  'skills.enabled true' \
  'skills.enableSkillCommands true' \
  'skills.enableCodexUser true' \
  'skills.enableClaudeUser true' \
  'skills.enableClaudeProject true' \
  'skills.enablePiUser true' \
  'skills.enablePiProject true' \
  'skills.enableAgentsUser true' \
  'skills.enableAgentsProject true' \
  'mcp.enableProjectConfig true' \
  'commands.enableClaudeUser true' \
  'commands.enableClaudeProject true'; do
  grep -Fx "config set $setting" "$OMP_CONFIG_LOG" >/dev/null
done

if grep -F 'disabledProviders' "$OMP_CONFIG_LOG" >/dev/null; then
  echo "OMP installer should preserve machine-local provider exclusions" >&2
  exit 1
fi

echo "OMP installer test passed."
