#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
MIGRATION_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME" "$MIGRATION_HOME"
}
trap cleanup EXIT

snapshot_protected() {
  local output="$1"

  python3 - "$TEST_HOME" "$output" <<'PY'
import hashlib
from pathlib import Path
import stat
import sys

root = Path(sys.argv[1])
output = Path(sys.argv[2])
paths = [
    ".claude/CLAUDE.md",
    ".claude/settings.json",
    ".claude/file-suggestion.sh",
    ".claude/statusline-command.sh",
    *(
        f".claude/skills/{skill}/SKILL.md"
        for skill in (
            "general-auto-research",
            "brainstorming",
            "planning",
            "commit",
            "implement",
            "merge",
            "issue",
            "adversarial-doc-review",
            "code-review",
        )
    ),
    ".omp/profiles/review/agent/AGENTS.md",
    ".omp/profiles/review/agent/config.yml",
    ".omp/profiles/review/agent/models.yml",
    ".omp/profiles/review/agent/.env",
    ".omp/agent/.env",
    ".local/bin/agentrc-codex-doc-review",
    ".local/bin/agentrc-codex-code-review",
    ".codex/rules/claude-review.rules",
    ".codex/rules/omp-review.rules",
    ".agents/skills/claude-doc-review",
    ".agents/skills/claude-code-review",
]


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_hash(path: Path) -> str:
    digest = hashlib.sha256()
    for entry in sorted(path.rglob("*")):
        relative = entry.relative_to(path).as_posix()
        mode = stat.S_IMODE(entry.lstat().st_mode)
        if entry.is_symlink():
            kind = "symlink"
            payload = entry.readlink().as_posix()
        elif entry.is_dir():
            kind = "directory"
            payload = ""
        else:
            kind = "file"
            payload = file_hash(entry)
        digest.update(f"{relative}\0{kind}\0{mode:o}\0{payload}\n".encode())
    return digest.hexdigest()


records = []
for relative in paths:
    path = root / relative
    metadata = path.lstat()
    mode = stat.S_IMODE(metadata.st_mode)
    if path.is_symlink():
        kind = "symlink"
        link_target = path.readlink().as_posix()
        content_path = path.resolve(strict=True)
    elif path.is_dir():
        kind = "directory"
        link_target = "-"
        content_path = path
    elif path.is_file():
        kind = "file"
        link_target = "-"
        content_path = path
    else:
        raise SystemExit(f"unsupported protected path type: {relative}")
    content_hash = (
        tree_hash(content_path) if content_path.is_dir() else file_hash(content_path)
    )
    records.append(f"{relative}\t{kind}\t{mode:o}\t{link_target}\t{content_hash}")

output.write_text("\n".join(records) + "\n")
PY
}

PROTECTED_SOURCE="$TEST_HOME/protected-sources"
protected_symlink_files=(
  .claude/CLAUDE.md
  .claude/settings.json
  .claude/file-suggestion.sh
  .claude/statusline-command.sh
  .claude/skills/general-auto-research/SKILL.md
  .claude/skills/brainstorming/SKILL.md
  .claude/skills/planning/SKILL.md
  .claude/skills/commit/SKILL.md
  .claude/skills/implement/SKILL.md
  .claude/skills/merge/SKILL.md
  .claude/skills/issue/SKILL.md
  .claude/skills/adversarial-doc-review/SKILL.md
  .claude/skills/code-review/SKILL.md
  .omp/profiles/review/agent/AGENTS.md
  .omp/profiles/review/agent/config.yml
  .omp/profiles/review/agent/models.yml
)
for path in "${protected_symlink_files[@]}"; do
  mkdir -p "$PROTECTED_SOURCE/$(dirname "$path")" "$TEST_HOME/$(dirname "$path")"
  printf 'protected legacy content: %s\n' "$path" >"$PROTECTED_SOURCE/$path"
  ln -s "$PROTECTED_SOURCE/$path" "$TEST_HOME/$path"
done

mkdir -p "$TEST_HOME/.omp/agent" "$TEST_HOME/.omp/profiles/review/agent"
printf 'OPENROUTER_API_KEY=protected\n' >"$TEST_HOME/.omp/agent/.env"
chmod 600 "$TEST_HOME/.omp/agent/.env"
ln -s ../../../agent/.env "$TEST_HOME/.omp/profiles/review/agent/.env"

mkdir -p "$TEST_HOME/.local/bin" "$TEST_HOME/.codex/rules"
for runner in agentrc-codex-doc-review agentrc-codex-code-review; do
  printf 'protected runner: %s\n' "$runner" >"$TEST_HOME/.local/bin/$runner"
  chmod 700 "$TEST_HOME/.local/bin/$runner"
done
for rule in claude-review.rules omp-review.rules; do
  printf 'protected rule: %s\n' "$rule" >"$TEST_HOME/.codex/rules/$rule"
  chmod 600 "$TEST_HOME/.codex/rules/$rule"
done

mkdir -p "$PROTECTED_SOURCE/claude-doc-review/nested" "$PROTECTED_SOURCE/claude-code-review/nested"
printf 'protected skill: claude-doc-review\n' >"$PROTECTED_SOURCE/claude-doc-review/SKILL.md"
printf 'tree marker\n' >"$PROTECTED_SOURCE/claude-doc-review/nested/marker"
printf 'protected skill: claude-code-review\n' >"$PROTECTED_SOURCE/claude-code-review/SKILL.md"
printf 'tree marker\n' >"$PROTECTED_SOURCE/claude-code-review/nested/marker"
mkdir -p "$TEST_HOME/.agents/skills"
ln -s "$PROTECTED_SOURCE/claude-doc-review" "$TEST_HOME/.agents/skills/claude-doc-review"
ln -s "$PROTECTED_SOURCE/claude-code-review" "$TEST_HOME/.agents/skills/claude-code-review"

mkdir -p "$TEST_HOME/.codex" "$TEST_HOME/.agents/skills/unrelated"
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
printf 'unrelated skill\n' >"$TEST_HOME/.agents/skills/unrelated/SKILL.md"

cp "$TEST_HOME/.codex/config.toml" "$TEST_HOME/config-before.toml"
python3 "$ROOT_DIR/scripts/merge-codex-config.py" \
  "$TEST_HOME/config-before.toml" "$ROOT_DIR/codex/config.toml" \
  >"$TEST_HOME/config-expected.toml"
snapshot_protected "$TEST_HOME/protected-before.tsv"

HOME="$TEST_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null

snapshot_protected "$TEST_HOME/protected-after.tsv"
if ! cmp -s "$TEST_HOME/protected-before.tsv" "$TEST_HOME/protected-after.tsv"; then
  diff -u "$TEST_HOME/protected-before.tsv" "$TEST_HOME/protected-after.tsv" >&2
  echo "Codex install changed protected legacy state" >&2
  exit 1
fi

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

for role in doc_reviewer.toml code_reviewer.toml; do
  target="$TEST_HOME/.codex/agents/$role"
  if [ ! -f "$target" ] || [ -L "$target" ] ||
     ! cmp -s "$target" "$ROOT_DIR/codex/agents/$role"; then
    echo "Expected exact regular Codex role copy: $role" >&2
    exit 1
  fi
done

for skill in general-auto-research adversarial-doc-review brainstorming planning code-review commit implement merge issue; do
  target="$TEST_HOME/.agents/skills/$skill"
  expected="$ROOT_DIR/codex/skills/$skill"
  if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$expected" ]; then
    echo "Unexpected active Codex skill link: $skill" >&2
    exit 1
  fi
  if [ ! -f "$expected/SKILL.md" ] || [ -L "$expected/SKILL.md" ]; then
    echo "Expected regular Codex-owned skill source: $expected/SKILL.md" >&2
    exit 1
  fi
done

grep -F 'pattern=["existing"]' "$TEST_HOME/.codex/rules/default.rules" >/dev/null
grep -F 'pattern=["custom"]' "$TEST_HOME/.codex/rules/custom.rules" >/dev/null
grep -Fx 'unrelated skill' "$TEST_HOME/.agents/skills/unrelated/SKILL.md" >/dev/null

mkdir -p "$MIGRATION_HOME/.codex"
ln -s "$ROOT_DIR/codex/config.toml" "$MIGRATION_HOME/.codex/config.toml"
HOME="$MIGRATION_HOME" "$ROOT_DIR/codex/install.sh" >/dev/null
if [ -L "$MIGRATION_HOME/.codex/config.toml" ]; then
  echo "Expected a tracked config symlink to be migrated to a regular merged file" >&2
  exit 1
fi

echo "Codex installer test passed (24 protected legacy paths unchanged)."
