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
    echo "Expected retired active path to be absent: $path" >&2
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
    if command -v "$candidate" >/dev/null 2>&1 &&
       "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
      echo "$candidate"
      return
    fi
  done

  echo "No Python with tomllib found. Set PYTHON_TOML to a Python 3.11+ binary." >&2
  return 1
}

PYTHON_TOML_BIN="$(python_with_tomllib)"

require_regular_file "AGENTS.md"
require_regular_file "codex/AGENTS.md"
require_regular_file "codex/config.toml"
require_regular_file "codex/agents/doc_reviewer.toml"
require_regular_file "codex/agents/code_reviewer.toml"
for skill in general-auto-research adversarial-doc-review brainstorming planning code-review commit implement merge issue; do
  require_regular_file "codex/skills/$skill/SKILL.md"
done
require_regular_file "archive/legacy-harnesses/README.md"
require_regular_file "archive/legacy-harnesses/MANIFEST.tsv"
require_regular_file "archive/legacy-harnesses/agentrc-pre-codex-only.tar.gz"
require_regular_file "scripts/merge-codex-config.py"
require_regular_file "scripts/test-merge-codex-config.py"
require_regular_file "scripts/validate-legacy-archive.py"
require_regular_file "scripts/test-legacy-archive-validation.py"

for path in \
  CLAUDE.md \
  claude \
  omp \
  shared \
  codex/skills/claude-doc-review \
  codex/skills/claude-code-review \
  codex/rules/claude-review.rules \
  codex/rules/omp-review.rules; do
  require_absent "$path"
done

active_symlinks="$(find "$ROOT_DIR/codex" -type l -print)"
if [ -n "$active_symlinks" ]; then
  echo "Active Codex sources must not be symlinks:" >&2
  echo "$active_symlinks" >&2
  exit 1
fi

for path in \
  install.sh \
  sync-remote.sh \
  codex/install.sh \
  codex/sync-remote.sh \
  scripts/validate-config.sh \
  scripts/test-codex-install.sh \
  scripts/test-sync-remote.sh \
  scripts/merge-codex-config.py \
  scripts/test-merge-codex-config.py \
  scripts/validate-legacy-archive.py \
  scripts/test-legacy-archive-validation.py; do
  require_executable "$path"
done

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/sync-remote.sh"
bash -n "$ROOT_DIR/codex/install.sh"
bash -n "$ROOT_DIR/codex/sync-remote.sh"
bash -n "$ROOT_DIR/scripts/validate-config.sh"
bash -n "$ROOT_DIR/scripts/test-codex-install.sh"
bash -n "$ROOT_DIR/scripts/test-sync-remote.sh"

if rg -n 'archive/legacy-harnesses' \
  "$ROOT_DIR/install.sh" "$ROOT_DIR/sync-remote.sh" "$ROOT_DIR/codex"; then
  echo "Active Codex runtime consumes the inert legacy archive" >&2
  exit 1
fi
while IFS= read -r path; do
  case "$path" in
    "$ROOT_DIR/scripts/validate-config.sh"|\
    "$ROOT_DIR/scripts/validate-legacy-archive.py"|\
    "$ROOT_DIR/scripts/test-legacy-archive-validation.py") ;;
    *)
      echo "Unexpected active script reference to the inert archive: $path" >&2
      exit 1
      ;;
  esac
done < <(rg -l 'archive/legacy-harnesses' "$ROOT_DIR/scripts" || true)

"$PYTHON_TOML_BIN" -c \
  'import pathlib, tomllib, sys; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
  "$ROOT_DIR/codex/config.toml"
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
    if "sandbox_mode" in role:
        raise SystemExit(f"{filename}: role must inherit the parent sandbox")

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
        "non-modifying by default",
        "main agent explicitly authorizes that exact action",
        "Do not delegate",
        "Do not request sandbox approvals or escalations",
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

python3 -m py_compile "$ROOT_DIR/scripts/merge-codex-config.py" \
  "$ROOT_DIR/scripts/validate-legacy-archive.py" \
  "$ROOT_DIR/scripts/test-legacy-archive-validation.py"
python3 "$ROOT_DIR/scripts/validate-legacy-archive.py" \
  "$ROOT_DIR/archive/legacy-harnesses" --repository "$ROOT_DIR"
python3 "$ROOT_DIR/scripts/test-legacy-archive-validation.py"
python3 "$ROOT_DIR/scripts/test-merge-codex-config.py"
"$ROOT_DIR/scripts/test-codex-install.sh"
"$ROOT_DIR/scripts/test-sync-remote.sh"

echo "Config repository validation passed."
