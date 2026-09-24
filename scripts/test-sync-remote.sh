#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
REMOTE_BASELINE="$TEST_DIR/remote-baseline.toml"
REMOTE_EXPECTED="$TEST_DIR/remote-expected.toml"
CLAUDE_BASELINE="$TEST_DIR/claude-baseline.json"
CLAUDE_EXPECTED="$TEST_DIR/claude-expected.json"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"

cat >"$REMOTE_BASELINE" <<'EOF'
model = "remote-model"
remote_marker = true

[desktop]
mac-menu-bar-enabled = true
ambient-suggestions-enabled = false

[projects."/remote/project"]
trust_level = "trusted"
EOF
python3 "$ROOT_DIR/scripts/merge-codex-config.py" \
  "$REMOTE_BASELINE" "$ROOT_DIR/codex/config.toml" >"$REMOTE_EXPECTED"

cat >"$CLAUDE_BASELINE" <<'EOF'
{
  "model": "remote-model",
  "env": {"REMOTE_TOKEN": "secret"},
  "permissions": {"defaultMode": "bypassPermissions"},
  "statusLine": {"type": "command", "command": "legacy", "padding": 1}
}
EOF
python3 "$ROOT_DIR/scripts/merge-claude-settings.py" \
  "$CLAUDE_BASELINE" "$ROOT_DIR/claude/settings.json" >"$CLAUDE_EXPECTED"

cat >"$BIN_DIR/ssh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

remote="${1:?missing remote}"
command="${2:?missing command}"
if [ "$remote" != "test" ]; then
  echo "Unexpected remote: $remote" >&2
  exit 1
fi

case "$command" in
  'mkdir -p '*)
    directories="${command#mkdir -p }"
    for directory in $directories; do
      relative_directory="${directory#\~/}"
      if [ "$relative_directory" = "$directory" ]; then
        echo "Unexpected remote directory: $directory" >&2
        exit 1
      fi
      mkdir -p "$SYNC_REMOTE_HOME/$relative_directory"
    done
    ;;
  'cat ~/.codex/config.toml 2>/dev/null || true')
    if [ -f "$SYNC_REMOTE_HOME/.codex/config.toml" ]; then
      cat "$SYNC_REMOTE_HOME/.codex/config.toml"
    fi
    ;;
  'cat > ~/.codex/config.toml')
    mkdir -p "$SYNC_REMOTE_HOME/.codex"
    cat >"$SYNC_REMOTE_HOME/.codex/config.toml"
    ;;
  'cat ~/.claude/settings.json 2>/dev/null || true')
    if [ -f "$SYNC_REMOTE_HOME/.claude/settings.json" ]; then
      cat "$SYNC_REMOTE_HOME/.claude/settings.json"
    fi
    ;;
  'cat > ~/.claude/settings.json')
    mkdir -p "$SYNC_REMOTE_HOME/.claude"
    cat >"$SYNC_REMOTE_HOME/.claude/settings.json"
    ;;
  *)
    echo "Unexpected remote command: $command" >&2
    exit 1
    ;;
esac
EOF

cat >"$BIN_DIR/scp" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

source_path="$2"
destination="$3"
relative_destination="${destination#test:~/}"
if [ "$relative_destination" = "$destination" ]; then
  echo "Unexpected copy destination: $destination" >&2
  exit 1
fi
destination_directory="$SYNC_REMOTE_HOME/$(dirname "$relative_destination")"
if [ ! -d "$destination_directory" ]; then
  echo "Missing remote destination directory: $destination_directory" >&2
  exit 1
fi
cp "$source_path" "$SYNC_REMOTE_HOME/$relative_destination"
EOF

chmod +x "$BIN_DIR/ssh" "$BIN_DIR/scp"

prepare_remote_home() {
  local remote_home="$1"

  mkdir -p "$remote_home/.codex/agents" "$remote_home/.codex/rules" \
    "$remote_home/.agents/skills/unrelated" "$remote_home/.claude/skills/unrelated"
  cp "$REMOTE_BASELINE" "$remote_home/.codex/config.toml"
  cp "$CLAUDE_BASELINE" "$remote_home/.claude/settings.json"
  printf 'legacy instructions\n' >"$remote_home/.claude/CLAUDE.md"
  printf 'unrelated role\n' >"$remote_home/.codex/agents/unrelated.toml"
  printf 'unrelated rule\n' >"$remote_home/.codex/rules/unrelated.rules"
  printf 'unrelated skill\n' >"$remote_home/.agents/skills/unrelated/SKILL.md"
  printf 'unrelated claude skill\n' >"$remote_home/.claude/skills/unrelated/SKILL.md"
  cp "$remote_home/.codex/agents/unrelated.toml" "$remote_home/role-before"
  cp "$remote_home/.codex/rules/unrelated.rules" "$remote_home/rule-before"
  cp "$remote_home/.agents/skills/unrelated/SKILL.md" "$remote_home/skill-before"
  cp "$remote_home/.claude/skills/unrelated/SKILL.md" "$remote_home/claude-skill-before"
}

check_regular_copy() {
  local name="$1"
  local source="$2"
  local target="$3"

  if [ ! -f "$target" ] || [ -L "$target" ] || ! cmp -s "$source" "$target"; then
    echo "$name sync did not deploy an exact regular copy: ${target#"$TEST_DIR"/}" >&2
    exit 1
  fi
}

check_codex_sync() {
  local name="$1"
  local remote_home="$2"

  if ! cmp -s "$REMOTE_EXPECTED" "$remote_home/.codex/config.toml"; then
    diff -u "$REMOTE_EXPECTED" "$remote_home/.codex/config.toml" >&2
    echo "$name sync did not preserve and merge remote config" >&2
    exit 1
  fi
  check_regular_copy "$name" "$ROOT_DIR/codex/AGENTS.md" "$remote_home/.codex/AGENTS.md"
  for source in "$ROOT_DIR"/codex/agents/*.toml; do
    check_regular_copy "$name" "$source" "$remote_home/.codex/agents/${source##*/}"
  done
  for source in "$ROOT_DIR"/codex/skills/*/SKILL.md; do
    skill="$(basename "$(dirname "$source")")"
    check_regular_copy "$name" "$source" "$remote_home/.agents/skills/$skill/SKILL.md"
  done
}

check_claude_sync() {
  local name="$1"
  local remote_home="$2"

  if ! cmp -s "$CLAUDE_EXPECTED" "$remote_home/.claude/settings.json"; then
    diff -u "$CLAUDE_EXPECTED" "$remote_home/.claude/settings.json" >&2
    echo "$name sync did not preserve and merge remote Claude settings" >&2
    exit 1
  fi
  check_regular_copy "$name" "$ROOT_DIR/claude/AGENTS.md" "$remote_home/.claude/CLAUDE.md"
  check_regular_copy "$name" "$ROOT_DIR/claude/statusline.sh" "$remote_home/.claude/statusline.sh"
  for source in "$ROOT_DIR"/claude/agents/*.md; do
    check_regular_copy "$name" "$source" "$remote_home/.claude/agents/${source##*/}"
  done
  for source in "$ROOT_DIR"/claude/skills/*/SKILL.md; do
    skill="$(basename "$(dirname "$source")")"
    check_regular_copy "$name" "$source" "$remote_home/.claude/skills/$skill/SKILL.md"
  done
}

check_preserved() {
  local name="$1"
  local remote_home="$2"
  local pair

  for pair in \
    ".codex/agents/unrelated.toml:role-before" \
    ".codex/rules/unrelated.rules:rule-before" \
    ".agents/skills/unrelated/SKILL.md:skill-before" \
    ".claude/skills/unrelated/SKILL.md:claude-skill-before"; do
    if ! cmp -s "$remote_home/${pair%%:*}" "$remote_home/${pair#*:}"; then
      echo "$name sync changed unrelated remote state: ${pair%%:*}" >&2
      exit 1
    fi
  done
}

run_sync_test() {
  local name="$1"
  local script="$2"
  local remote_home="$TEST_DIR/$name-remote-home"

  prepare_remote_home "$remote_home"
  PATH="$BIN_DIR:$PATH" SYNC_REMOTE_HOME="$remote_home" "$script" test >/dev/null
  PATH="$BIN_DIR:$PATH" SYNC_REMOTE_HOME="$remote_home" "$script" test >/dev/null

  case "$name" in
    root)
      check_codex_sync "$name" "$remote_home"
      check_claude_sync "$name" "$remote_home"
      ;;
    codex)
      check_codex_sync "$name" "$remote_home"
      if ! cmp -s "$CLAUDE_BASELINE" "$remote_home/.claude/settings.json"; then
        echo "codex sync changed Claude settings" >&2
        exit 1
      fi
      ;;
    claude)
      check_claude_sync "$name" "$remote_home"
      if ! cmp -s "$REMOTE_BASELINE" "$remote_home/.codex/config.toml"; then
        echo "claude sync changed Codex config" >&2
        exit 1
      fi
      ;;
  esac
  check_preserved "$name" "$remote_home"
}

run_sync_test root "$ROOT_DIR/sync-remote.sh"
run_sync_test codex "$ROOT_DIR/codex/sync-remote.sh"
run_sync_test claude "$ROOT_DIR/claude/sync-remote.sh"

echo "Remote sync test passed (active sources deployed and unrelated state preserved across repeated sync)."
