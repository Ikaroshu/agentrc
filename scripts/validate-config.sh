#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-${TMPDIR:-/tmp}/agentrc_pycache}"
export PYTHONPYCACHEPREFIX

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

python_with_tomllib() {
  local candidate

  for candidate in "${PYTHON_TOML:-}" python3.12 python3.11 python3; do
    if [ -z "$candidate" ]; then
      continue
    fi

    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  echo "No Python with tomllib found. Set PYTHON_TOML to a Python 3.11+ binary." >&2
  return 1
}

PYTHON_TOML_BIN="$(python_with_tomllib)"

require_file "AGENTS.md"
require_file "shared/AGENTS.md"
require_file "shared/skills/auto-research/SKILL.md"
require_file "shared/skills/brainstorming/SKILL.md"
require_file "shared/skills/commit/SKILL.md"
require_file "shared/skills/implement/SKILL.md"
require_file "shared/skills/merge/SKILL.md"
require_file "shared/skills/issue/SKILL.md"
require_symlink "CLAUDE.md" "AGENTS.md"
require_symlink "claude/CLAUDE.md" "../shared/AGENTS.md"
require_symlink "codex/AGENTS.md" "../shared/AGENTS.md"
require_symlink "claude/skills/auto-research/SKILL.md" "../../../shared/skills/auto-research/SKILL.md"
require_symlink "codex/skills/auto-research/SKILL.md" "../../../shared/skills/auto-research/SKILL.md"
for skill in brainstorming commit implement merge issue; do
  require_symlink "claude/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
  require_symlink "codex/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
done

require_file "claude/settings.json"
require_file "claude/skills/adversarial-doc-review/SKILL.md"
require_file "claude/skills/codex-code-review/SKILL.md"
require_file "codex/config.toml"
require_file "codex/rules/claude-review.rules"
require_file "codex/skills/adversarial-doc-review/SKILL.md"
require_file "codex/skills/claude-code-review/SKILL.md"

require_executable "install.sh"
require_executable "sync-remote.sh"
require_executable "claude/install.sh"
require_executable "codex/install.sh"
require_executable "claude/sync-remote.sh"
require_executable "codex/sync-remote.sh"
require_executable "scripts/validate-config.sh"
require_executable "scripts/test-codex-install.sh"
require_executable "scripts/merge-codex-config.py"
require_executable "scripts/test-merge-codex-config.py"

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/sync-remote.sh"
bash -n "$ROOT_DIR/claude/install.sh"
bash -n "$ROOT_DIR/codex/install.sh"
bash -n "$ROOT_DIR/claude/sync-remote.sh"
bash -n "$ROOT_DIR/codex/sync-remote.sh"
bash -n "$ROOT_DIR/scripts/validate-config.sh"
bash -n "$ROOT_DIR/scripts/test-codex-install.sh"

python3 -m json.tool "$ROOT_DIR/claude/settings.json" >/dev/null
"$PYTHON_TOML_BIN" -c 'import pathlib, tomllib, sys; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' "$ROOT_DIR/codex/config.toml"
python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"
"$ROOT_DIR/scripts/test-codex-install.sh"
codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/claude-review.rules" -- \
  claude -p --permission-mode plan --output-format text review \
  | grep -F '"decision": "allow"' >/dev/null
codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/claude-review.rules" -- \
  env -u PYTHONPATH -u VIRTUAL_ENV \
  claude -p --permission-mode plan --output-format text review \
  | grep -F '"decision": "allow"' >/dev/null

echo "Config repository validation passed."
