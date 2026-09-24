#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-${TMPDIR:-/tmp}/agentrc_pycache}"
export PYTHONPYCACHEPREFIX

require_regular_file() {
  local path="$1"

  if [ ! -f "$ROOT_DIR/$path" ] || [ -L "$ROOT_DIR/$path" ]; then
    echo "Expected regular file: $path" >&2
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

python_with_module() {
  local module="$1"
  local configured="$2"
  local candidate

  for candidate in "$configured" python3.12 python3.11 python3; do
    if [ -n "$candidate" ] &&
       command -v "$candidate" >/dev/null 2>&1 &&
       "$candidate" -c "import $module" >/dev/null 2>&1; then
      echo "$candidate"
      return
    fi
  done

  echo "No Python with $module found." >&2
  return 1
}

PYTHON_TOML_BIN="$(python_with_module tomllib "${PYTHON_TOML:-}")"
PYTHON_YAML_BIN="$(python_with_module yaml "${PYTHON_YAML:-}")"

required_files=(
  AGENTS.md
  codex/AGENTS.md
  codex/config.toml
  claude/AGENTS.md
  claude/settings.json
  claude/statusline.sh
  scripts/merge-codex-config.py
  scripts/test-merge-codex-config.py
  scripts/merge-claude-settings.py
  scripts/test-merge-claude-settings.py
)
for path in "${required_files[@]}"; do
  require_regular_file "$path"
done

for role_file in "$ROOT_DIR"/codex/agents/*.toml; do
  require_regular_file "codex/agents/${role_file##*/}"
done

skills=()
for skill_dir in "$ROOT_DIR"/codex/skills/*; do
  skill="${skill_dir##*/}"
  require_regular_file "codex/skills/$skill/SKILL.md"
  skills+=("$skill")
done

for agent_file in "$ROOT_DIR"/claude/agents/*.md; do
  require_regular_file "claude/agents/${agent_file##*/}"
done

claude_skills=()
for skill_dir in "$ROOT_DIR"/claude/skills/*; do
  skill="${skill_dir##*/}"
  require_regular_file "claude/skills/$skill/SKILL.md"
  claude_skills+=("$skill")
done

active_symlinks="$(find "$ROOT_DIR/codex" "$ROOT_DIR/claude" -type l -print)"
if [ -n "$active_symlinks" ]; then
  echo "Active Codex and Claude sources must be regular files:" >&2
  echo "$active_symlinks" >&2
  exit 1
fi

executables=(
  install.sh
  sync-remote.sh
  codex/install.sh
  codex/sync-remote.sh
  claude/install.sh
  claude/sync-remote.sh
  claude/statusline.sh
  scripts/validate-config.sh
  scripts/test-codex-install.sh
  scripts/test-claude-install.sh
  scripts/test-sync-remote.sh
  scripts/merge-codex-config.py
  scripts/test-merge-codex-config.py
  scripts/merge-claude-settings.py
  scripts/test-merge-claude-settings.py
)
for path in "${executables[@]}"; do
  require_executable "$path"
done

shell_scripts=(
  install.sh
  sync-remote.sh
  codex/install.sh
  codex/sync-remote.sh
  claude/install.sh
  claude/sync-remote.sh
  claude/statusline.sh
  scripts/validate-config.sh
  scripts/test-codex-install.sh
  scripts/test-claude-install.sh
  scripts/test-sync-remote.sh
)
for path in "${shell_scripts[@]}"; do
  bash -n "$ROOT_DIR/$path"
done

runtime_paths=(
  "$ROOT_DIR/install.sh"
  "$ROOT_DIR/sync-remote.sh"
  "$ROOT_DIR/codex"
  "$ROOT_DIR/claude"
  "$ROOT_DIR/scripts/merge-codex-config.py"
  "$ROOT_DIR/scripts/test-merge-codex-config.py"
  "$ROOT_DIR/scripts/merge-claude-settings.py"
  "$ROOT_DIR/scripts/test-merge-claude-settings.py"
  "$ROOT_DIR/scripts/test-codex-install.sh"
  "$ROOT_DIR/scripts/test-claude-install.sh"
  "$ROOT_DIR/scripts/test-sync-remote.sh"
)
if rg -n 'archive/' "${runtime_paths[@]}"; then
  echo "Active Codex or Claude code references the inert archive" >&2
  exit 1
fi

"$PYTHON_TOML_BIN" - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])

with (root / "codex/config.toml").open("rb") as config_file:
    config = tomllib.load(config_file)
if set(config) != {
    "model",
    "model_reasoning_effort",
    "personality",
    "tui",
    "desktop",
}:
    raise SystemExit("codex/config.toml must contain only portable behavior and UI settings")

if config["model"] != "gpt-6-astra" or config["model_reasoning_effort"] != "high":
    raise SystemExit("expected Astra with high reasoning as the portable default")

recursive_skills = {
    "implement",
    "handoff",
    "adversarial-doc-review",
    "code-review",
    "claude-doc-review",
    "claude-code-review",
}
role_specs = {
    "doc_reviewer.toml": ("doc_reviewer", True, "gpt-6-astra", "xhigh"),
    "code_reviewer.toml": ("code_reviewer", True, "gpt-6-astra", "xhigh"),
    "implementer.toml": ("implementer", True, "gpt-6-sol", "xhigh"),
    "research_worker.toml": ("research_worker", False, "gpt-6-astra", "high"),
    "explorer.toml": ("explorer", False, "gpt-6-sol", "high"),
    "worker.toml": ("worker", False, "gpt-6-sol", "high"),
}
role_files = {path.name for path in (root / "codex/agents").glob("*.toml")}
if role_files != set(role_specs):
    raise SystemExit(f"unexpected active roles: {sorted(role_files)}")

for filename, (expected_name, blocks_recursion, expected_model, expected_effort) in role_specs.items():
    with (root / "codex/agents" / filename).open("rb") as role_file:
        role = tomllib.load(role_file)
    expected_keys = {"name", "description", "developer_instructions", "model", "model_reasoning_effort"}
    if blocks_recursion:
        expected_keys.add("skills")
    if set(role) != expected_keys:
        raise SystemExit(f"{filename}: unexpected top-level keys: {sorted(role)}")
    if role["name"] != expected_name:
        raise SystemExit(f"{filename}: expected role name {expected_name!r}")
    if role["model"] != expected_model or role["model_reasoning_effort"] != expected_effort:
        raise SystemExit(f"{filename}: expected {expected_model} with {expected_effort} reasoning")
    for field in ("description", "developer_instructions"):
        if not isinstance(role[field], str) or not role[field].strip():
            raise SystemExit(f"{filename}: {field} must be a non-empty string")
    if not blocks_recursion:
        continue
    selectors = role["skills"].get("config", [])
    if (
        not isinstance(selectors, list)
        or any(set(item) != {"name", "enabled"} for item in selectors)
        or any(item["enabled"] is not False for item in selectors)
        or {item["name"] for item in selectors} != recursive_skills
        or len(selectors) != len(recursive_skills)
    ):
        raise SystemExit(
            f"{filename}: expected exactly the six disabled recursive workflow skills"
        )
PY

for skill in adversarial-doc-review code-review; do
  skill_file="$ROOT_DIR/codex/skills/$skill/SKILL.md"
  grep -F 'fork_turns="none"' "$skill_file" >/dev/null
  grep -F 'model="gpt-6-astra"' "$skill_file" >/dev/null
  grep -F 'reasoning_effort="xhigh"' "$skill_file" >/dev/null
  grep -F 'reasoning_effort="max"' "$skill_file" >/dev/null
done
grep -F 'agent_type="doc_reviewer"' "$ROOT_DIR/codex/skills/adversarial-doc-review/SKILL.md" >/dev/null
grep -F 'agent_type="code_reviewer"' "$ROOT_DIR/codex/skills/code-review/SKILL.md" >/dev/null

implement_skill="$ROOT_DIR/codex/skills/implement/SKILL.md"
grep -F 'agent_type="implementer"' "$implement_skill" >/dev/null
grep -F 'fork_turns="none"' "$implement_skill" >/dev/null
grep -F 'model="gpt-6-sol"' "$implement_skill" >/dev/null
grep -F 'reasoning_effort="xhigh"' "$implement_skill" >/dev/null

"$PYTHON_YAML_BIN" - "$ROOT_DIR" <<'PY'
from pathlib import Path
import json
import sys
import yaml

root = Path(sys.argv[1])

settings = json.loads((root / "claude/settings.json").read_text())
if settings != {
    "model": "opus",
    "effortLevel": "high",
    "statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"},
}:
    raise SystemExit("claude/settings.json must contain only the portable model, effort, and status line")

agent_specs = {
    "code-reviewer.md": ("xhigh", "Agent, Skill"),
    "doc-reviewer.md": ("xhigh", "Agent, Skill"),
    "implementer.md": ("medium", "Skill"),
    "research-worker.md": ("high", None),
    "explorer.md": ("low", None),
    "worker.md": ("medium", None),
}
agent_files = {path.name for path in (root / "claude/agents").glob("*.md")}
if agent_files != set(agent_specs):
    raise SystemExit(f"unexpected active Claude subagents: {sorted(agent_files)}")

for filename, (expected_effort, expected_disallowed) in agent_specs.items():
    text = (root / "claude/agents" / filename).read_text()
    _, frontmatter, body = text.split("---\n", 2)
    agent = yaml.safe_load(frontmatter)
    expected_keys = {"name", "description", "model", "effort"}
    if expected_disallowed:
        expected_keys.add("disallowedTools")
    if set(agent) != expected_keys:
        raise SystemExit(f"{filename}: unexpected frontmatter keys: {sorted(agent)}")
    if agent["name"] != filename.removesuffix(".md"):
        raise SystemExit(f"{filename}: name must match the filename")
    if agent["model"] != "opus" or agent["effort"] != expected_effort:
        raise SystemExit(f"{filename}: expected opus with {expected_effort} effort")
    if agent.get("disallowedTools") != expected_disallowed:
        raise SystemExit(f"{filename}: expected disallowedTools {expected_disallowed!r}")
    if not isinstance(agent["description"], str) or not agent["description"].strip() or not body.strip():
        raise SystemExit(f"{filename}: description and instructions must be non-empty")
PY

grep -F 'subagent_type="doc-reviewer"' "$ROOT_DIR/claude/skills/adversarial-doc-review/SKILL.md" >/dev/null
grep -F 'subagent_type="code-reviewer"' "$ROOT_DIR/claude/skills/code-review/SKILL.md" >/dev/null
grep -F 'subagent_type="implementer"' "$ROOT_DIR/claude/skills/implement/SKILL.md" >/dev/null
if rg -n -i 'codex|gpt-|spawn_agent|followup_task|fork_turns|\bagent_type=' "$ROOT_DIR/claude"; then
  echo "Active Claude sources reference Codex-only runtime constructs" >&2
  exit 1
fi

SKILL_VALIDATOR="${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py"
if [ ! -f "$SKILL_VALIDATOR" ]; then
  echo "Skill validator is unavailable: $SKILL_VALIDATOR" >&2
  exit 1
fi
for skill in "${skills[@]}"; do
  "$PYTHON_YAML_BIN" "$SKILL_VALIDATOR" "$ROOT_DIR/codex/skills/$skill"
done
for skill in "${claude_skills[@]}"; do
  "$PYTHON_YAML_BIN" "$SKILL_VALIDATOR" "$ROOT_DIR/claude/skills/$skill"
done

python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py" "$ROOT_DIR/scripts/test-merge-codex-config.py" \
  "$ROOT_DIR/scripts/merge-claude-settings.py" "$ROOT_DIR/scripts/test-merge-claude-settings.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"
python3 "$ROOT_DIR/scripts/test-merge-claude-settings.py"
"$ROOT_DIR/scripts/test-codex-install.sh"
"$ROOT_DIR/scripts/test-claude-install.sh"
"$ROOT_DIR/scripts/test-sync-remote.sh"

echo "Config repository validation passed."
