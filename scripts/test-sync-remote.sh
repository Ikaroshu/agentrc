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
printf '%s\t%s\n' "$remote" "$command" >>"$SYNC_SSH_LOG"

case "$command" in
  'rm -f ~/.agents/skills/planning/SKILL.md') rm -f "$SYNC_REMOTE_HOME/.agents/skills/planning/SKILL.md" ;;
  'mkdir -p ~/.codex/agents ~/.agents/skills/adversarial-doc-review ~/.agents/skills/brainstorming ~/.agents/skills/code-review ~/.agents/skills/commit ~/.agents/skills/handoff ~/.agents/skills/implement ~/.agents/skills/merge ~/.agents/skills/issue') ;;
  'cat ~/.codex/config.toml 2>/dev/null || true') cat "$SYNC_REMOTE_BASELINE" ;;
  'cat > ~/.codex/config.toml') cat >"$SYNC_REMOTE_RESULT" ;;
  *)
    echo "Unexpected remote command: $command" >&2
    exit 1
    ;;
esac
EOF

cat >"$BIN_DIR/scp" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >>"$SYNC_SCP_LOG"

source_path="$2"
destination="$3"
relative_destination="${destination#test:~/}"
if [ "$relative_destination" = "$destination" ]; then
  echo "Unexpected copy destination: $destination" >&2
  exit 1
fi
mkdir -p "$SYNC_REMOTE_HOME/$(dirname "$relative_destination")"
cp "$source_path" "$SYNC_REMOTE_HOME/$relative_destination"
EOF

chmod +x "$BIN_DIR/ssh" "$BIN_DIR/scp"

write_expected_scp() {
  local output="$1"

  {
    printf '%s\n' "-q $ROOT_DIR/codex/AGENTS.md test:~/.codex/AGENTS.md"
    printf '%s\n' "-q $ROOT_DIR/codex/agents/doc_reviewer.toml test:~/.codex/agents/doc_reviewer.toml"
    printf '%s\n' "-q $ROOT_DIR/codex/agents/code_reviewer.toml test:~/.codex/agents/code_reviewer.toml"
    printf '%s\n' "-q $ROOT_DIR/codex/agents/implementer.toml test:~/.codex/agents/implementer.toml"
    printf '%s\n' "-q $ROOT_DIR/codex/agents/research_worker.toml test:~/.codex/agents/research_worker.toml"
    for skill in adversarial-doc-review brainstorming code-review commit handoff implement merge issue; do
      printf '%s\n' "-q $ROOT_DIR/codex/skills/$skill/SKILL.md test:~/.agents/skills/$skill/SKILL.md"
    done
  } >"$output"
}

write_expected_ssh() {
  local output="$1"

  {
    printf '%s\t%s\n' test 'rm -f ~/.agents/skills/planning/SKILL.md'
    printf '%s\t%s\n' test 'mkdir -p ~/.codex/agents ~/.agents/skills/adversarial-doc-review ~/.agents/skills/brainstorming ~/.agents/skills/code-review ~/.agents/skills/commit ~/.agents/skills/handoff ~/.agents/skills/implement ~/.agents/skills/merge ~/.agents/skills/issue'
    printf '%s\t%s\n' test 'cat ~/.codex/config.toml 2>/dev/null || true'
    printf '%s\t%s\n' test 'cat > ~/.codex/config.toml'
  } >"$output"
}

EXPECTED_SCP="$TEST_DIR/expected-scp.log"
EXPECTED_SSH="$TEST_DIR/expected-ssh.log"
write_expected_scp "$EXPECTED_SCP"
write_expected_ssh "$EXPECTED_SSH"

run_sync_test() {
  local name="$1"
  local script="$2"
  local scp_log="$TEST_DIR/$name-scp.log"
  local ssh_log="$TEST_DIR/$name-ssh.log"
  local remote_result="$TEST_DIR/$name-remote-result.toml"
  local remote_home="$TEST_DIR/$name-remote-home"

  : >"$scp_log"
  : >"$ssh_log"
  mkdir -p "$remote_home/.agents/skills/planning"
  printf 'retired managed skill\n' >"$remote_home/.agents/skills/planning/SKILL.md"
  PATH="$BIN_DIR:$PATH" \
    SYNC_SCP_LOG="$scp_log" \
    SYNC_SSH_LOG="$ssh_log" \
    SYNC_REMOTE_BASELINE="$REMOTE_BASELINE" \
    SYNC_REMOTE_RESULT="$remote_result" \
    SYNC_REMOTE_HOME="$remote_home" \
    "$script" test >/dev/null

  if ! cmp -s "$EXPECTED_SCP" "$scp_log"; then
    diff -u "$EXPECTED_SCP" "$scp_log" >&2
    echo "$name sync used unexpected copy sources or destinations" >&2
    exit 1
  fi
  if ! cmp -s "$EXPECTED_SSH" "$ssh_log"; then
    diff -u "$EXPECTED_SSH" "$ssh_log" >&2
    echo "$name sync used an unexpected remote command" >&2
    exit 1
  fi
  if ! cmp -s "$REMOTE_EXPECTED" "$remote_result"; then
    diff -u "$REMOTE_EXPECTED" "$remote_result" >&2
    echo "$name sync did not merge from the remote machine baseline" >&2
    exit 1
  fi
  if [ -e "$remote_home/.agents/skills/planning/SKILL.md" ]; then
    echo "$name sync preserved the retired planning skill" >&2
    exit 1
  fi
  for role in implementer.toml research_worker.toml; do
    if [ ! -f "$remote_home/.codex/agents/$role" ] ||
       [ -L "$remote_home/.codex/agents/$role" ] ||
       ! cmp -s "$ROOT_DIR/codex/agents/$role" \
         "$remote_home/.codex/agents/$role"; then
      echo "$name sync did not deploy an exact regular role: $role" >&2
      exit 1
    fi
  done
}

run_sync_test root "$ROOT_DIR/sync-remote.sh"
run_sync_test codex "$ROOT_DIR/codex/sync-remote.sh"

echo "Remote sync test passed (13 exact destinations, 4 exact commands)."
