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

require_absent() {
  local path="$1"

  if [ -e "$ROOT_DIR/$path" ] || [ -L "$ROOT_DIR/$path" ]; then
    echo "Expected retired path to be absent: $path" >&2
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
  codex/agents/doc_reviewer.toml
  codex/agents/code_reviewer.toml
  codex/agents/implementer.toml
  codex/agents/research_worker.toml
  scripts/merge-codex-config.py
  scripts/test-merge-codex-config.py
)
for path in "${required_files[@]}"; do
  require_regular_file "$path"
done

skills=(
  adversarial-doc-review
  brainstorming
  code-review
  commit
  handoff
  implement
  merge
  issue
)
for skill in "${skills[@]}"; do
  require_regular_file "codex/skills/$skill/SKILL.md"
done

retired_paths=(
  codex/skills/general-auto-research
  codex/skills/planning
  codex/skills/implement/scripts/git_task_guard.py
  codex/skills/implement/scripts/test_git_task_guard.py
  scripts/validate-legacy-archive.py
  scripts/test-legacy-archive-validation.py
)
for path in "${retired_paths[@]}"; do
  require_absent "$path"
done

active_skill_names="$(find "$ROOT_DIR/codex/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
expected_skill_names="$(printf '%s\n' "${skills[@]}" | sort)"
if [ "$active_skill_names" != "$expected_skill_names" ]; then
  echo "Active skill directories do not match the managed skill set" >&2
  diff -u <(printf '%s\n' "$expected_skill_names") <(printf '%s\n' "$active_skill_names") >&2
  exit 1
fi

active_symlinks="$(find "$ROOT_DIR/codex" -type l -print)"
if [ -n "$active_symlinks" ]; then
  echo "Active Codex sources must be regular files:" >&2
  echo "$active_symlinks" >&2
  exit 1
fi

executables=(
  install.sh
  sync-remote.sh
  codex/install.sh
  codex/sync-remote.sh
  scripts/validate-config.sh
  scripts/test-codex-install.sh
  scripts/test-sync-remote.sh
  scripts/merge-codex-config.py
  scripts/test-merge-codex-config.py
)
for path in "${executables[@]}"; do
  require_executable "$path"
done

shell_scripts=(
  install.sh
  sync-remote.sh
  codex/install.sh
  codex/sync-remote.sh
  scripts/validate-config.sh
  scripts/test-codex-install.sh
  scripts/test-sync-remote.sh
)
for path in "${shell_scripts[@]}"; do
  bash -n "$ROOT_DIR/$path"
done

runtime_paths=(
  "$ROOT_DIR/install.sh"
  "$ROOT_DIR/sync-remote.sh"
  "$ROOT_DIR/codex"
  "$ROOT_DIR/scripts/merge-codex-config.py"
  "$ROOT_DIR/scripts/test-merge-codex-config.py"
  "$ROOT_DIR/scripts/test-codex-install.sh"
  "$ROOT_DIR/scripts/test-sync-remote.sh"
)
if rg -n 'archive/' "${runtime_paths[@]}"; then
  echo "Active Codex code references the inert archive" >&2
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

recursive_skills = {
    "implement",
    "handoff",
    "adversarial-doc-review",
    "code-review",
    "claude-doc-review",
    "claude-code-review",
}
role_specs = {
    "doc_reviewer.toml": ("doc_reviewer", True),
    "code_reviewer.toml": ("code_reviewer", True),
    "implementer.toml": ("implementer", True),
    "research_worker.toml": ("research_worker", False),
}

for filename, (expected_name, blocks_recursion) in role_specs.items():
    with (root / "codex/agents" / filename).open("rb") as role_file:
        role = tomllib.load(role_file)
    expected_keys = {"name", "description", "developer_instructions"}
    if blocks_recursion:
        expected_keys.add("skills")
    if set(role) != expected_keys:
        raise SystemExit(f"{filename}: unexpected top-level keys: {sorted(role)}")
    if role["name"] != expected_name:
        raise SystemExit(f"{filename}: expected role name {expected_name!r}")
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
  grep -F 'model="gpt-5.6-sol"' "$skill_file" >/dev/null
  grep -F 'reasoning_effort="xhigh"' "$skill_file" >/dev/null
  grep -F 'reasoning_effort="max"' "$skill_file" >/dev/null
done
grep -F 'agent_type="doc_reviewer"' "$ROOT_DIR/codex/skills/adversarial-doc-review/SKILL.md" >/dev/null
grep -F 'agent_type="code_reviewer"' "$ROOT_DIR/codex/skills/code-review/SKILL.md" >/dev/null

behavior_contract=(
  'needs user-only `sudo` or other privileged work'
  'ask once and end the turn'
  'Do not poll or try workarounds'
  'unprivileged path directly only if it is equivalent'
)
for required_text in "${behavior_contract[@]}"; do
  grep -F -- "$required_text" "$ROOT_DIR/codex/AGENTS.md" >/dev/null
done

implement_skill="$ROOT_DIR/codex/skills/implement/SKILL.md"
implement_contract=(
  'agent_type="implementer"'
  'fork_turns="none"'
  'model="gpt-5.6-sol"'
  'reasoning_effort="xhigh"'
  'one persistent owner'
  'followup_task'
  'until the requested implementer returns'
  'code-review'
  'design, outcome, and verification'
  'Design flaws'
)
for required_text in "${implement_contract[@]}"; do
  grep -F -- "$required_text" "$implement_skill" >/dev/null
done

grep -F 'followup_task' "$ROOT_DIR/codex/skills/code-review/SKILL.md" >/dev/null
grep -F 'Own delivery of the supplied design, outcome, and truthful verification evidence' "$ROOT_DIR/codex/agents/implementer.toml" >/dev/null
grep -F 'Do not delegate overall ownership or invoke an implementer or reviewer role' "$ROOT_DIR/codex/agents/implementer.toml" >/dev/null
grep -F 'exact clean status' "$ROOT_DIR/codex/agents/implementer.toml" >/dev/null
grep -F 'own the technical inspection and the quality and actionability of every finding' "$ROOT_DIR/codex/agents/code_reviewer.toml" >/dev/null
grep -F 'same commit and tree' "$ROOT_DIR/codex/skills/merge/SKILL.md" >/dev/null
grep -F "Accept that recorded evidence without inspecting the implementation diff or rerunning its verification" "$ROOT_DIR/codex/skills/merge/SKILL.md" >/dev/null
grep -F 'full immutable review-base-to-candidate diff' "$ROOT_DIR/codex/skills/code-review/SKILL.md" >/dev/null
grep -F 'does not inspect the implementation diff, reproduce reviewer findings, rerun verification' "$ROOT_DIR/codex/skills/code-review/SKILL.md" >/dev/null
grep -F 'do not inspect or review the implementation diff, rerun its verification' "$implement_skill" >/dev/null
grep -F '[brainstorm ->] worktree -> implement -> code-review -> merge' "$ROOT_DIR/codex/AGENTS.md" >/dev/null
grep -F 'at most read-only candidate identity and status checks for coordination' "$ROOT_DIR/codex/AGENTS.md" >/dev/null
grep -F 'settle the **goal** with the user first' "$ROOT_DIR/codex/skills/brainstorming/SKILL.md" >/dev/null
grep -F 'code-review pass two requires a pass-one repair' "$ROOT_DIR/codex/AGENTS.md" >/dev/null
old_orchestrator_contract=(
  'inspect the clean worktree'
  'Run the settled verification and every repository-required check'
  'Verify every finding'
  'rerun the settled and repository-required verification'
)
for forbidden_text in "${old_orchestrator_contract[@]}"; do
  if grep -F -- "$forbidden_text" "$implement_skill" "$ROOT_DIR/codex/skills/code-review/SKILL.md"; then
    echo "Active workflow still assigns implementation or review verification to the orchestrator" >&2
    exit 1
  fi
done
if grep -F 'Run the same tests on main.' "$ROOT_DIR/codex/skills/merge/SKILL.md"; then
  echo "Merge workflow still duplicates accepted implementation verification" >&2
  exit 1
fi
if rg -n 'cumulative|checkpoint|incremental review' "$ROOT_DIR/codex/AGENTS.md" "$ROOT_DIR/codex/agents" "$ROOT_DIR/codex/skills"; then
  echo "Active workflow still contains retired multi-stage code-review language" >&2
  exit 1
fi

handoff_skill="$ROOT_DIR/codex/skills/handoff/SKILL.md"
handoff_contract=(
  'git worktree list --porcelain'
  "Resolve the current task's host before selecting a project"
  'require both the exact parent path and the current task'
  'whether its `projectKind` is `"local"` or `"remote"`'
  'environment: { type: "local" }'
  'reuse that exact worktree with explicit workdirs'
  '<project-root>/.worktrees/'
  'Never fork the current task'
  "app's Hand off action"
)
for required_text in "${handoff_contract[@]}"; do
  grep -F -- "$required_text" "$handoff_skill" >/dev/null
done
if rg -n 'git_task_guard|general-auto-research' "$ROOT_DIR/codex" "$ROOT_DIR/install.sh" "$ROOT_DIR/sync-remote.sh"; then
  echo "Active configuration references retired guard machinery" >&2
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

python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py" "$ROOT_DIR/scripts/test-merge-codex-config.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"
"$ROOT_DIR/scripts/test-codex-install.sh"
"$ROOT_DIR/scripts/test-sync-remote.sh"

echo "Config repository validation passed."
