#!/usr/bin/env bash
# Claude Code status line: model + reasoning effort, directory basename, and Git branch.

set -euo pipefail

input="$(cat)"
model="$(jq -r '.model.display_name' <<<"$input")"
cwd="$(jq -r '.workspace.current_dir // .cwd' <<<"$input")"
effort="$(jq -r '.effort.level // empty' <<<"$input")"
if [ -z "$effort" ]; then
  effort="$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null || true)"
fi
dir="$(basename "$cwd")"
branch="$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)"

line="$model"
if [ -n "$effort" ]; then
  line+=" ($effort)"
fi
line+=" | $dir"
if [ -n "$branch" ]; then
  line+=" | $branch"
fi
printf '%s\n' "$line"
