#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

require_file() {
  local path="$1"

  if [ ! -f "$ROOT_DIR/$path" ]; then
    echo "Missing required file: $path" >&2
    return 1
  fi
}

require_symlink() {
  local path="$1"
  local expected="$2"
  local target

  if [ ! -L "$ROOT_DIR/$path" ]; then
    echo "Expected symlink: $path" >&2
    return 1
  fi

  target="$(readlink "$ROOT_DIR/$path")"
  if [ "$target" != "$expected" ]; then
    echo "Unexpected symlink target for $path: $target" >&2
    echo "Expected: $expected" >&2
    return 1
  fi
}

require_executable() {
  local path="$1"

  if [ ! -x "$ROOT_DIR/$path" ]; then
    echo "Expected executable: $path" >&2
    return 1
  fi
}

require_file "AGENTS.md"
require_file "shared/AGENTS.md"
require_file "shared/skills/auto-research/SKILL.md"
require_symlink "CLAUDE.md" "AGENTS.md"
require_symlink "claude/CLAUDE.md" "../shared/AGENTS.md"
require_symlink "codex/AGENTS.md" "../shared/AGENTS.md"
require_symlink "claude/skills/auto-research/SKILL.md" "../../../shared/skills/auto-research/SKILL.md"
require_symlink "codex/skills/auto-research/SKILL.md" "../../../shared/skills/auto-research/SKILL.md"

require_file "claude/settings.json"
require_file "codex/config.toml"
require_file "codex/commands/commit.md"
require_file "codex/commands/merge.md"

require_executable "install.sh"
require_executable "sync-remote.sh"
require_executable "claude/install.sh"
require_executable "codex/install.sh"
require_executable "claude/sync-remote.sh"
require_executable "codex/sync-remote.sh"
require_executable "scripts/validate-config.sh"
require_executable "scripts/merge-codex-config.py"
require_executable "scripts/test-merge-codex-config.py"

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/sync-remote.sh"
bash -n "$ROOT_DIR/claude/install.sh"
bash -n "$ROOT_DIR/codex/install.sh"
bash -n "$ROOT_DIR/claude/sync-remote.sh"
bash -n "$ROOT_DIR/codex/sync-remote.sh"
bash -n "$ROOT_DIR/scripts/validate-config.sh"

python3 -m json.tool "$ROOT_DIR/claude/settings.json" >/dev/null
python3 -c 'import pathlib, tomllib, sys; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' "$ROOT_DIR/codex/config.toml"
python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"

echo "Config repository validation passed."
