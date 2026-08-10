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
    echo "Expected obsolete path to be absent: $path" >&2
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
require_file "shared/skills/planning/SKILL.md"
require_absent "shared/skills/adversarial-doc-review"
require_absent "shared/skills/code-review"
require_regular_file "claude/skills/adversarial-doc-review/SKILL.md"
require_regular_file "claude/skills/code-review/SKILL.md"
require_file "shared/review-runners/agentrc-codex-doc-review"
require_file "shared/review-runners/agentrc-codex-code-review"
require_file "shared/skills/commit/SKILL.md"
require_file "shared/skills/implement/SKILL.md"
require_file "shared/skills/merge/SKILL.md"
require_file "shared/skills/issue/SKILL.md"
require_file "codex/skills/claude-doc-review/SKILL.md"
require_file "codex/skills/claude-code-review/SKILL.md"
require_regular_file "codex/skills/adversarial-doc-review/SKILL.md"
require_regular_file "codex/skills/code-review/SKILL.md"
require_file "codex/agents/doc_reviewer.toml"
require_file "codex/agents/code_reviewer.toml"
require_symlink "omp/AGENTS.md" "../shared/AGENTS.md"
require_file "omp/config.yml"
require_file "omp/models.yml"
require_symlink "CLAUDE.md" "AGENTS.md"
require_symlink "claude/CLAUDE.md" "../shared/AGENTS.md"
require_symlink "codex/AGENTS.md" "../shared/AGENTS.md"
require_symlink "claude/skills/general-auto-research/SKILL.md" "../../../shared/skills/general-auto-research/SKILL.md"
require_symlink "codex/skills/general-auto-research/SKILL.md" "../../../shared/skills/general-auto-research/SKILL.md"
for skill in brainstorming planning commit implement merge issue; do
  require_symlink "claude/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
  require_symlink "codex/skills/$skill/SKILL.md" "../../../shared/skills/$skill/SKILL.md"
done
require_file "claude/settings.json"
require_file "codex/config.toml"
require_file "codex/rules/claude-review.rules"
require_file "codex/rules/omp-review.rules"
require_absent "codex/rules/codex-review.rules"

require_executable "install.sh"
require_executable "sync-remote.sh"
require_executable "claude/install.sh"
require_executable "codex/install.sh"
require_executable "claude/sync-remote.sh"
require_executable "codex/sync-remote.sh"
require_executable "omp/install.sh"
require_executable "omp/sync-remote.sh"
require_executable "scripts/validate-config.sh"
require_executable "scripts/test-claude-install.sh"
require_executable "scripts/test-codex-install.sh"
require_executable "scripts/test-codex-review-runners.sh"
require_executable "scripts/test-omp-install.sh"
require_executable "scripts/merge-codex-config.py"
require_executable "scripts/test-merge-codex-config.py"
require_executable "scripts/test-sync-remote.sh"
require_executable "shared/review-runners/agentrc-codex-doc-review"
require_executable "shared/review-runners/agentrc-codex-code-review"

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/sync-remote.sh"
bash -n "$ROOT_DIR/claude/install.sh"
bash -n "$ROOT_DIR/codex/install.sh"
bash -n "$ROOT_DIR/claude/sync-remote.sh"
bash -n "$ROOT_DIR/codex/sync-remote.sh"
bash -n "$ROOT_DIR/omp/install.sh"
bash -n "$ROOT_DIR/omp/sync-remote.sh"
bash -n "$ROOT_DIR/scripts/validate-config.sh"
bash -n "$ROOT_DIR/scripts/test-claude-install.sh"
bash -n "$ROOT_DIR/scripts/test-codex-install.sh"
bash -n "$ROOT_DIR/scripts/test-codex-review-runners.sh"
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
"$PYTHON_TOML_BIN" - "$ROOT_DIR" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
review_skills = {
    "adversarial-doc-review",
    "code-review",
    "claude-doc-review",
    "claude-code-review",
}
routing_keys = {
    "model",
    "model_provider",
    "model_providers",
    "model_reasoning_effort",
    "service_tier",
}


def load_role(filename: str, expected_name: str) -> dict[str, object]:
    path = root / "codex" / "agents" / filename
    with path.open("rb") as role_file:
        role = tomllib.load(role_file)

    if role.get("name") != expected_name:
        raise SystemExit(f"{filename}: expected role name {expected_name!r}")
    for field in ("description", "developer_instructions"):
        value = role.get(field)
        if not isinstance(value, str) or not value.strip():
            raise SystemExit(f"{filename}: {field} must be a non-empty string")
    if role.get("sandbox_mode") != "read-only":
        raise SystemExit(f"{filename}: sandbox_mode must be 'read-only'")

    present_routing_keys = sorted(routing_keys & role.keys())
    if present_routing_keys:
        raise SystemExit(
            f"{filename}: role must not override caller routing: {present_routing_keys}"
        )

    skill_entries = role.get("skills", {}).get("config", [])
    if not isinstance(skill_entries, list) or len(skill_entries) != len(review_skills):
        raise SystemExit(f"{filename}: expected exactly four disabled review skills")
    if any(set(entry) != {"name", "enabled"} for entry in skill_entries):
        raise SystemExit(f"{filename}: review skills must use only name and enabled selectors")
    if any(entry["enabled"] is not False for entry in skill_entries):
        raise SystemExit(f"{filename}: every review skill must be disabled")
    configured_names = {entry["name"] for entry in skill_entries}
    if configured_names != review_skills:
        raise SystemExit(
            f"{filename}: unexpected disabled review skills: {sorted(configured_names)}"
        )

    return role


doc_role = load_role("doc_reviewer.toml", "doc_reviewer")
code_role = load_role("code_reviewer.toml", "code_reviewer")

doc_instructions = doc_role["developer_instructions"]
for required_text in (
    "Problem validity and proportionality",
    "Correctness and completeness",
    "Risk and blast radius",
    "Design and alternatives",
    "Testability",
    "Process and scope",
    "## Verdict",
    "## Blocking findings",
    "## Non-blocking suggestions",
    "## Questions for the author",
):
    if required_text not in doc_instructions:
        raise SystemExit(f"doc_reviewer.toml: missing stable contract text {required_text!r}")

code_instructions = code_role["developer_instructions"]
for required_text in (
    "Correctness bugs, regressions",
    "Security vulnerabilities, data-loss risks",
    "Important missing tests",
    "Maintainability problems",
    "severity, confidence, file and line, problem, impact, and minimum fix",
    "## Findings",
    "## Test gaps",
    "## Residual risk",
):
    if required_text not in code_instructions:
        raise SystemExit(f"code_reviewer.toml: missing stable contract text {required_text!r}")

for filename, instructions in (
    ("doc_reviewer.toml", doc_instructions),
    ("code_reviewer.toml", code_instructions),
):
    for required_text in (
        "Remain strictly read-only",
        "Do not delegate",
        "request approvals or escalations",
        "launch Codex, Claude, OMP, a review runner",
    ):
        if required_text not in instructions:
            raise SystemExit(f"{filename}: missing no-side-effect contract {required_text!r}")

if "shell_environment_policy" in doc_role:
    raise SystemExit("doc_reviewer.toml: document review must inherit the shell environment")
if "allow_login_shell" in doc_role:
    raise SystemExit("doc_reviewer.toml: document review must inherit login-shell behavior")

if code_role.get("allow_login_shell") is not False:
    raise SystemExit("code_reviewer.toml: allow_login_shell must be false")

code_shell_policy = code_role.get("shell_environment_policy")
expected_filters = {"PYTHONPATH": "exclude", "VIRTUAL_ENV": "exclude"}
if not isinstance(code_shell_policy, dict) or set(code_shell_policy) != {"filters"}:
    raise SystemExit("code_reviewer.toml: expected only canonical shell filters")
if code_shell_policy["filters"] != expected_filters:
    raise SystemExit(
        "code_reviewer.toml: expected exact PYTHONPATH and VIRTUAL_ENV exclusion filters"
    )
PY
for skill in adversarial-doc-review code-review; do
  claude_skill_file="$ROOT_DIR/claude/skills/$skill/SKILL.md"
  grep -F "agentrc-codex-" "$claude_skill_file" >/dev/null
  grep -F 'three completed substantive reviewer turns' "$claude_skill_file" >/dev/null
  if grep -Eq 'spawn_agent|agent_type|followup_task|fork_turns' "$claude_skill_file"; then
    echo "Claude CLI skill contains native reviewer lifecycle text: $skill" >&2
    exit 1
  fi

  skill_file="$ROOT_DIR/codex/skills/$skill/SKILL.md"
  if grep -Eq 'agentrc-codex-|codex exec|managed runner|managed CLI' "$skill_file"; then
    echo "Codex-native skill contains managed runner plumbing: $skill" >&2
    exit 1
  fi
  grep -F 'fork_turns="none"' "$skill_file" >/dev/null
  grep -F 'model="gpt-5.6-sol"' "$skill_file" >/dev/null
  grep -F 'reasoning_effort="xhigh"' "$skill_file" >/dev/null
  grep -F 'reasoning_effort="max"' "$skill_file" >/dev/null
done
grep -F 'agent_type="doc_reviewer"' \
  "$ROOT_DIR/codex/skills/adversarial-doc-review/SKILL.md" >/dev/null
grep -F 'agent_type="code_reviewer"' \
  "$ROOT_DIR/codex/skills/code-review/SKILL.md" >/dev/null
python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"
"$ROOT_DIR/scripts/test-claude-install.sh"
"$ROOT_DIR/scripts/test-codex-install.sh"
"$ROOT_DIR/scripts/test-codex-review-runners.sh"
"$ROOT_DIR/scripts/test-omp-install.sh"
"$ROOT_DIR/scripts/test-sync-remote.sh"
review_models=(
  "openrouter/deepseek/deepseek-v4-pro"
  "openrouter/z-ai/glm-5.2"
  "openrouter/x-ai/grok-4.5"
)
for model in "${review_models[@]}"; do
  codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/omp-review.rules" -- \
    omp --profile review -p --no-session --no-extensions --no-skills --no-rules \
    --no-lsp --tools read,grep,glob --approval-mode always-ask \
    --model "$model" review \
    | grep -F '"decision": "allow"' >/dev/null
done
codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/claude-review.rules" -- \
  claude -p --permission-mode plan --output-format text review \
  | grep -F '"decision": "allow"' >/dev/null
codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/claude-review.rules" -- \
  env -u PYTHONPATH -u VIRTUAL_ENV claude -p --permission-mode plan --output-format text review \
  | grep -F '"decision": "allow"' >/dev/null
if codex execpolicy check --pretty --rules "$ROOT_DIR/codex/rules/omp-review.rules" -- \
  omp --profile review -p --no-session --no-extensions --no-skills --no-rules \
  --no-lsp --tools read,grep,glob,bash --approval-mode always-ask \
  --model openrouter/x-ai/grok-4.5 review \
  | grep -F '"decision": "allow"' >/dev/null; then
  echo "OMP review permission rule allowed a mutation-capable tool" >&2
  exit 1
fi
grep -F 'transmit supplied repository documents and diffs through OpenRouter' \
  "$ROOT_DIR/codex/rules/omp-review.rules" >/dev/null

echo "Config repository validation passed."
