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
require_file "shared/skills/general-auto-research/SKILL.md"
require_file "shared/skills/brainstorming/SKILL.md"
require_file "shared/skills/adversarial-doc-review/SKILL.md"
require_file "shared/skills/code-review/SKILL.md"
require_file "shared/skills/commit/SKILL.md"
require_file "shared/skills/implement/SKILL.md"
require_file "shared/skills/merge/SKILL.md"
require_file "shared/skills/issue/SKILL.md"
require_symlink "omp/AGENTS.md" "../shared/AGENTS.md"
require_file "omp/config.yml"
require_file "omp/models.yml"
require_symlink "CLAUDE.md" "AGENTS.md"
require_symlink "claude/CLAUDE.md" "../shared/AGENTS.md"
require_symlink "codex/AGENTS.md" "../shared/AGENTS.md"
require_symlink "claude/skills/general-auto-research/SKILL.md" "../../../shared/skills/general-auto-research/SKILL.md"
require_symlink "codex/skills/general-auto-research/SKILL.md" "../../../shared/skills/general-auto-research/SKILL.md"
for skill in brainstorming commit implement merge issue; do
  require_symlink "claude/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
  require_symlink "codex/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
done
for skill in adversarial-doc-review code-review; do
  require_symlink "claude/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
  require_symlink "codex/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
done

require_file "claude/settings.json"
require_file "codex/config.toml"
require_file "codex/rules/omp-review.rules"

require_executable "install.sh"
require_executable "sync-remote.sh"
require_executable "claude/install.sh"
require_executable "codex/install.sh"
require_executable "claude/sync-remote.sh"
require_executable "codex/sync-remote.sh"
require_executable "omp/install.sh"
require_executable "scripts/validate-config.sh"
require_executable "scripts/test-codex-install.sh"
require_executable "scripts/test-omp-install.sh"
require_executable "scripts/merge-codex-config.py"
require_executable "scripts/test-merge-codex-config.py"
require_executable "scripts/test-sync-remote.sh"

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/sync-remote.sh"
bash -n "$ROOT_DIR/claude/install.sh"
bash -n "$ROOT_DIR/codex/install.sh"
bash -n "$ROOT_DIR/claude/sync-remote.sh"
bash -n "$ROOT_DIR/codex/sync-remote.sh"
bash -n "$ROOT_DIR/omp/install.sh"
bash -n "$ROOT_DIR/scripts/validate-config.sh"
bash -n "$ROOT_DIR/scripts/test-codex-install.sh"
bash -n "$ROOT_DIR/scripts/test-omp-install.sh"
bash -n "$ROOT_DIR/scripts/test-sync-remote.sh"

python3 -m json.tool "$ROOT_DIR/claude/settings.json" >/dev/null
for yaml_file in "$ROOT_DIR/omp/config.yml" "$ROOT_DIR/omp/models.yml"; do
  ruby -e 'require "yaml"; YAML.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [], aliases: false)' "$yaml_file"
done
if grep -Eq 'sk-or-v1-|OPENROUTER_API_KEY=' "$ROOT_DIR/omp/config.yml" "$ROOT_DIR/omp/models.yml"; then
  echo "OMP tracked config contains an OpenRouter secret" >&2
  exit 1
fi
"$PYTHON_TOML_BIN" -c 'import pathlib, tomllib, sys; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' "$ROOT_DIR/codex/config.toml"
python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"
"$ROOT_DIR/scripts/test-codex-install.sh"
"$ROOT_DIR/scripts/test-omp-install.sh"
"$ROOT_DIR/scripts/test-sync-remote.sh"
review_models=(
  "openrouter/deepseek/deepseek-v4-pro"
  "openrouter/x-ai/grok-4.5"
  "openrouter/moonshotai/kimi-k3"
)
for model in "${review_models[@]}"; do
  codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/omp-review.rules" -- \
    omp --profile review -p --no-session --no-extensions --no-skills --no-rules \
    --no-lsp --tools read,grep,glob --approval-mode always-ask \
    --model "$model" review \
    | grep -F '"decision": "allow"' >/dev/null
done
if codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/omp-review.rules" -- \
  omp --profile review -p --no-session --no-extensions --no-skills --no-rules \
  --no-lsp --tools read,grep,glob,bash --approval-mode always-ask \
  --model openrouter/moonshotai/kimi-k3 review \
  | grep -F '"decision": "allow"' >/dev/null; then
  echo "OMP review permission rule allowed a mutation-capable tool" >&2
  exit 1
fi
grep -F 'transmit supplied repository documents and diffs through OpenRouter' \
  "$ROOT_DIR/codex/rules/omp-review.rules" >/dev/null

echo "Config repository validation passed."
