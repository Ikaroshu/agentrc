#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOC_RUNNER="$ROOT_DIR/shared/skills/adversarial-doc-review/scripts/agentrc-codex-doc-review"
CODE_RUNNER="$ROOT_DIR/shared/skills/code-review/scripts/agentrc-codex-code-review"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
DOC_SKILL="$TEST_DIR/doc-SKILL.md"
CODE_SKILL="$TEST_DIR/code-SKILL.md"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"
touch "$DOC_SKILL" "$CODE_SKILL"

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
elif [ "${1:-}" != "exec" ] || [ "${2:-}" = "review" ]; then
  echo "Document runner did not use general Codex exec mode" >&2
  exit 1
fi
if [ "${!#}" != "$EXPECTED_PROMPT" ]; then
  echo "Prompt argument was not preserved" >&2
  exit 1
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

prompt=$'Review this precisely.\nPreserve '\''quotes'\'' and newlines.'
output="$(
  PATH="$BIN_DIR:$PATH" \
    EXPECTED_PROMPT="$prompt" \
    "$DOC_RUNNER" high "$DOC_SKILL" "$prompt"
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
      "$runner" high "$skill_path" "$prompt"
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
    "$runner" high "$skill_path" "$prompt" \
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
