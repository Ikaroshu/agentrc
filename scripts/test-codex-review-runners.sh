#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOC_RUNNER="$ROOT_DIR/shared/review-runners/agentrc-codex-doc-review"
CODE_RUNNER="$ROOT_DIR/shared/review-runners/agentrc-codex-code-review"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
FALLBACK_BIN_DIR="$TEST_DIR/fallback-bin"
APP_RESOURCES_DIR="$TEST_DIR/app-resources"
DOC_SKILL="$ROOT_DIR/claude/skills/adversarial-doc-review/SKILL.md"
CODE_SKILL="$ROOT_DIR/claude/skills/code-review/SKILL.md"
CODEX_DOC_SKILL="$ROOT_DIR/codex/skills/adversarial-doc-review/SKILL.md"
CODEX_CODE_SKILL="$ROOT_DIR/codex/skills/code-review/SKILL.md"
EXPECTED_SKILLS_CONFIG='skills.config=[{name="adversarial-doc-review",enabled=false},{name="code-review",enabled=false},{name="claude-doc-review",enabled=false},{name="claude-code-review",enabled=false}]'

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$FALLBACK_BIN_DIR" "$APP_RESOURCES_DIR"

for skill_path in "$DOC_SKILL" "$CODE_SKILL" "$CODEX_DOC_SKILL" "$CODEX_CODE_SKILL"; do
  if [ ! -f "$skill_path" ]; then
    echo "Missing split review skill fixture: $skill_path" >&2
    exit 1
  fi
done
if [ "$DOC_SKILL" -ef "$CODEX_DOC_SKILL" ] ||
   [ "$CODE_SKILL" -ef "$CODEX_CODE_SKILL" ]; then
  echo "Expected distinct Claude and Codex review skill paths" >&2
  exit 1
fi

export DOC_SKILL CODE_SKILL CODEX_DOC_SKILL CODEX_CODE_SKILL EXPECTED_SKILLS_CONFIG

cat >"$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

if [ "${RUST_LOG:-}" != "off" ]; then
  echo "RUST_LOG was not disabled" >&2
  exit 1
fi
if IFS= read -r input; then
  echo "Codex stdin was not closed: $input" >&2
  exit 1
fi
if [ "${EXPECT_ISOLATED_PYTHON:-false}" = true ] &&
   { [ -n "${PYTHONPATH:-}" ] || [ -n "${VIRTUAL_ENV:-}" ]; }; then
  echo "Python environment leaked into code review" >&2
  exit 1
fi
if [ "${EXPECT_REVIEW_MODE:-false}" = true ]; then
  if [ "${1:-}" != "exec" ] || [ "${2:-}" != "review" ]; then
    echo "Code runner did not use Codex review mode" >&2
    exit 1
  fi
  caller_skill_path="$CODE_SKILL"
  installed_skill_path="$CODEX_CODE_SKILL"
elif [ "${1:-}" != "exec" ] || [ "${2:-}" = "review" ]; then
  echo "Document runner did not use general Codex exec mode" >&2
  exit 1
else
  caller_skill_path="$DOC_SKILL"
  installed_skill_path="$CODEX_DOC_SKILL"
fi
if [ "$caller_skill_path" -ef "$installed_skill_path" ]; then
  echo "Runner test did not exercise split Claude and Codex skill paths" >&2
  exit 1
fi

skills_config_count=0
previous_arg=""
for arg in "$@"; do
  case "$arg" in
    skills.config=*)
      skills_config_count=$((skills_config_count + 1))
      if [ "$previous_arg" != "--config" ]; then
        echo "Skills config was not passed through --config" >&2
        exit 1
      fi
      if [ "$arg" != "$EXPECTED_SKILLS_CONFIG" ]; then
        echo "Unexpected review-skill selector: $arg" >&2
        exit 1
      fi
      ;;
  esac
  previous_arg="$arg"
done
if [ "$skills_config_count" -ne 1 ]; then
  echo "Expected exactly one name-based review-skills config" >&2
  exit 1
fi
if [ "${!#}" != "$EXPECTED_PROMPT" ]; then
  echo "Prompt argument was not preserved" >&2
  exit 1
fi
if [ -n "${FAKE_CODEX_DELAY_SECONDS:-}" ]; then
  sleep "$FAKE_CODEX_DELAY_SECONDS"
fi
echo "DISCARD_SUCCESS_STDERR" >&2

printf '%s\n' \
  '{"type":"thread.started"}' \
  '{"type":"item.completed","item":{"type":"reasoning","text":"discard me"}}'
jq --null-input --compact-output --arg text "PRELIMINARY_MESSAGE" \
  '{type:"item.completed",item:{type:"agent_message",text:$text}}'

if [ "${FAKE_CODEX_MODE:-success}" = error ]; then
  echo "REPLAY_FAILURE_STDERR" >&2
  printf '%s\n' '{"type":"error","message":"EXPECTED_FAILURE"}'
  exit 1
fi

jq --null-input --compact-output --arg text "${EXPECTED_FINAL:-FINAL_ONLY}" \
  '{type:"item.completed",item:{type:"agent_message",text:$text}}'
printf '%s\n' '{"type":"turn.completed"}'
EOF
chmod +x "$BIN_DIR/codex"
touch "$BIN_DIR/codex-code-mode-host"
chmod +x "$BIN_DIR/codex-code-mode-host"
cp "$BIN_DIR/codex" "$APP_RESOURCES_DIR/codex"
touch "$APP_RESOURCES_DIR/codex-code-mode-host"
chmod +x "$APP_RESOURCES_DIR/codex" "$APP_RESOURCES_DIR/codex-code-mode-host"
cat >"$FALLBACK_BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash

echo "PATH Codex without its sibling host should not run" >&2
exit 1
EOF
chmod +x "$FALLBACK_BIN_DIR/codex"

prompt=$'Review this precisely.\nPreserve '\''quotes'\'' and newlines.'
output="$(
  PATH="$BIN_DIR:$PATH" \
    EXPECTED_PROMPT="$prompt" \
    "$DOC_RUNNER" xhigh "$DOC_SKILL" "$prompt"
)"
if [ "$output" != "FINAL_ONLY" ]; then
  echo "Unexpected runner output: $output" >&2
  exit 1
fi

output="$(
  PATH="$BIN_DIR:$PATH" \
    PYTHONPATH=leak \
    VIRTUAL_ENV=leak \
    EXPECT_ISOLATED_PYTHON=true \
    EXPECT_REVIEW_MODE=true \
    EXPECTED_PROMPT="$prompt" \
    "$CODE_RUNNER" max "$CODE_SKILL" "$prompt"
)"
if [ "$output" != "FINAL_ONLY" ]; then
  echo "Unexpected isolated runner output: $output" >&2
  exit 1
fi

for runner in "$DOC_RUNNER" "$CODE_RUNNER"; do
  if "$runner" high "$DOC_SKILL" "$prompt" >/dev/null 2>&1; then
    echo "Runner accepted the obsolete high effort: $runner" >&2
    exit 1
  fi
done

for runner in "$DOC_RUNNER" "$CODE_RUNNER"; do
  heartbeat_log="$TEST_DIR/$(basename "$runner").heartbeat.log"
  review_mode=false
  if [ "$runner" = "$CODE_RUNNER" ]; then
    review_mode=true
    skill_path="$CODE_SKILL"
  else
    skill_path="$DOC_SKILL"
  fi

  output="$(
    PATH="$BIN_DIR:$PATH" \
      AGENTRC_REVIEW_HEARTBEAT_SECONDS=0.02 \
      FAKE_CODEX_DELAY_SECONDS=0.08 \
      EXPECT_REVIEW_MODE="$review_mode" \
      EXPECTED_PROMPT="$prompt" \
      "$runner" xhigh "$skill_path" "$prompt" \
      2>"$heartbeat_log"
  )"
  if [ "$output" != "FINAL_ONLY" ]; then
    echo "Heartbeat changed runner output: $runner" >&2
    exit 1
  fi
  grep -F "Review still running; waiting for completion." "$heartbeat_log" >/dev/null
done

for runner in "$DOC_RUNNER" "$CODE_RUNNER"; do
  review_mode=false
  if [ "$runner" = "$CODE_RUNNER" ]; then
    review_mode=true
    skill_path="$CODE_SKILL"
  else
    skill_path="$DOC_SKILL"
  fi

  output="$(
    PATH="$FALLBACK_BIN_DIR:$PATH" \
      AGENTRC_CODEX_APP_RESOURCES_DIR="$APP_RESOURCES_DIR" \
      EXPECT_REVIEW_MODE="$review_mode" \
      EXPECTED_PROMPT="$prompt" \
      "$runner" xhigh "$skill_path" "$prompt"
  )"
  if [ "$output" != "FINAL_ONLY" ]; then
    echo "Runner did not select the app-bundled Codex fallback: $runner" >&2
    exit 1
  fi
done

large_final=$'## Verdict\nAPPROVE WITH CHANGES\n\nQuotes: "double" and '\''single'\''.\nUnicode: 測試 ✓'
for index in {1..512}; do
  large_final+=$'\n'
  large_final+="Finding $index: preserve this complete line while discarding intermediate events."
done
large_final+=$'\nEND_OF_FINAL_MESSAGE_SENTINEL'
if [ "${#large_final}" -lt 40000 ]; then
  echo "Large final-message fixture is unexpectedly small" >&2
  exit 1
fi

for runner in "$DOC_RUNNER" "$CODE_RUNNER"; do
  review_mode=false
  if [ "$runner" = "$CODE_RUNNER" ]; then
    review_mode=true
    skill_path="$CODE_SKILL"
  else
    skill_path="$DOC_SKILL"
  fi

  output="$(
    PATH="$BIN_DIR:$PATH" \
      EXPECT_REVIEW_MODE="$review_mode" \
      EXPECTED_PROMPT="$prompt" \
      EXPECTED_FINAL="$large_final" \
      "$runner" xhigh "$skill_path" "$prompt"
  )"
  if [ "$output" != "$large_final" ]; then
    echo "Runner truncated or changed the final message: $runner" >&2
    exit 1
  fi
done

for runner in "$DOC_RUNNER" "$CODE_RUNNER"; do
  error_name="$(basename "$runner")"
  error_log="$TEST_DIR/$error_name.error.log"
  error_output="$TEST_DIR/$error_name.error.out"
  review_mode=false
  if [ "$runner" = "$CODE_RUNNER" ]; then
    review_mode=true
    skill_path="$CODE_SKILL"
  else
    skill_path="$DOC_SKILL"
  fi

  if PATH="$BIN_DIR:$PATH" \
    FAKE_CODEX_MODE=error \
    EXPECT_REVIEW_MODE="$review_mode" \
    EXPECTED_PROMPT="$prompt" \
    "$runner" xhigh "$skill_path" "$prompt" \
    >"$error_output" 2>"$error_log"; then
    echo "Runner accepted a failed Codex invocation: $runner" >&2
    exit 1
  fi
  grep -F "EXPECTED_FAILURE" "$error_log" >/dev/null
  grep -F "REPLAY_FAILURE_STDERR" "$error_log" >/dev/null
  if grep -F "DISCARD_SUCCESS_STDERR" "$error_output" >/dev/null; then
    echo "Runner mixed Codex stderr into stdout: $runner" >&2
    exit 1
  fi
done

echo "Codex review runners test passed."
