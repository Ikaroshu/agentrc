#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
REMOTE_BASELINE="$TEST_DIR/remote-baseline.toml"
REMOTE_EXPECTED="$TEST_DIR/remote-expected.toml"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"

cat >"$REMOTE_BASELINE" <<'EOF'
model = "remote-model"
remote_marker = true

[projects."/remote/project"]
trust_level = "trusted"
EOF
python3 "$ROOT_DIR/scripts/merge-codex-config.py" \
  "$REMOTE_BASELINE" "$ROOT_DIR/codex/config.toml" >"$REMOTE_EXPECTED"

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

run_sync_test() {
  local name="$1"
  local script="$2"
  local remote_home="$TEST_DIR/$name-remote-home"

  mkdir -p "$remote_home/.codex/agents" "$remote_home/.codex/rules" \
    "$remote_home/.agents/skills/unrelated"
  cp "$REMOTE_BASELINE" "$remote_home/.codex/config.toml"
  printf 'unrelated role\n' >"$remote_home/.codex/agents/unrelated.toml"
  printf 'unrelated rule\n' >"$remote_home/.codex/rules/unrelated.rules"
  printf 'unrelated skill\n' >"$remote_home/.agents/skills/unrelated/SKILL.md"
  cp "$remote_home/.codex/agents/unrelated.toml" "$remote_home/role-before"
  cp "$remote_home/.codex/rules/unrelated.rules" "$remote_home/rule-before"
  cp "$remote_home/.agents/skills/unrelated/SKILL.md" "$remote_home/skill-before"

  PATH="$BIN_DIR:$PATH" SYNC_REMOTE_HOME="$remote_home" "$script" test >/dev/null
  PATH="$BIN_DIR:$PATH" SYNC_REMOTE_HOME="$remote_home" "$script" test >/dev/null

  if ! cmp -s "$REMOTE_EXPECTED" "$remote_home/.codex/config.toml"; then
    diff -u "$REMOTE_EXPECTED" "$remote_home/.codex/config.toml" >&2
    echo "$name sync did not preserve and merge remote config" >&2
    exit 1
  fi
  if ! cmp -s "$ROOT_DIR/codex/AGENTS.md" "$remote_home/.codex/AGENTS.md"; then
    echo "$name sync did not deploy Codex instructions" >&2
    exit 1
  fi

  for source in "$ROOT_DIR"/codex/agents/*.toml; do
    role="${source##*/}"
    target="$remote_home/.codex/agents/$role"
    if [ ! -f "$target" ] || [ -L "$target" ] || ! cmp -s "$source" "$target"; then
      echo "$name sync did not deploy an exact regular role: $role" >&2
      exit 1
    fi
  done
  for source in "$ROOT_DIR"/codex/skills/*/SKILL.md; do
    skill="$(basename "$(dirname "$source")")"
    target="$remote_home/.agents/skills/$skill/SKILL.md"
    if [ ! -f "$target" ] || [ -L "$target" ] || ! cmp -s "$source" "$target"; then
      echo "$name sync did not deploy an exact regular skill: $skill" >&2
      exit 1
    fi
  done

  preserved_paths=(
    ".codex/agents/unrelated.toml:role-before"
    ".codex/rules/unrelated.rules:rule-before"
    ".agents/skills/unrelated/SKILL.md:skill-before"
  )
  for pair in "${preserved_paths[@]}"; do
    synced="${pair%%:*}"
    before="${pair#*:}"
    if ! cmp -s "$remote_home/$synced" "$remote_home/$before"; then
      echo "$name sync changed unrelated remote state: $synced" >&2
      exit 1
    fi
  done
}

run_sync_test root "$ROOT_DIR/sync-remote.sh"
run_sync_test codex "$ROOT_DIR/codex/sync-remote.sh"

echo "Remote sync test passed (active sources deployed and unrelated state preserved across repeated sync)."
