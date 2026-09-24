#!/usr/bin/env bash
# Claude Code status line: model, directory, Git branch, and context used.

set -euo pipefail

input="$(cat)"
model="$(jq -r '.model.display_name' <<<"$input")"
cwd="$(jq -r '.workspace.current_dir // .cwd' <<<"$input")"
context="$(jq -r '.context_window.used_percentage // 0 | floor' <<<"$input")"
branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"

line="$model | ${cwd/#"$HOME"/\~}"
if [ -n "$branch" ]; then
  line+=" | $branch"
fi
printf '%s | %s%% context\n' "$line" "$context"
