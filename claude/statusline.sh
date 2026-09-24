#!/usr/bin/env bash
# Claude Code status line: model + effort · directory · Git branch · permission mode · weekly limit left.

set -euo pipefail

input="$(cat)"
model="$(jq -r '.model.display_name' <<<"$input")"
effort="$(jq -r '.effort.level // empty' <<<"$input")"
cwd="$(jq -r '.workspace.current_dir' <<<"$input")"
transcript="$(jq -r '.transcript_path' <<<"$input")"
weekly_left="$(jq -r '.rate_limits.seven_day.used_percentage // empty | 100 - . | round' <<<"$input")"

# Drop the context-size suffix, e.g. "Opus 5.5 (1M context)" -> "Opus 5.5".
parts=("${model% (*}${effort:+ $effort}")

case "$cwd" in
  "$HOME" | "$HOME"/*) parts+=("~${cwd#"$HOME"}") ;;
  *) parts+=("$cwd") ;;
esac

branch="$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)"
if [ -n "$branch" ]; then
  parts+=("$branch")
fi

# The status line input omits the permission mode, but the transcript records it on
# permission-mode entries and user messages. The transcript is absent before the first prompt.
mode=""
if [ -f "$transcript" ]; then
  mode="$(sed -n 's/.*"permissionMode":"\([^"]*\)".*/\1/p' "$transcript" | tail -n 1)"
fi
case "$mode" in
  "") ;;
  default) parts+=("Ask permissions") ;;
  acceptEdits) parts+=("Accept edits") ;;
  plan) parts+=("Plan mode") ;;
  auto) parts+=("Auto mode") ;;
  dontAsk) parts+=("Don't ask") ;;
  bypassPermissions) parts+=("Bypass permissions") ;;
  *) parts+=("$mode") ;;
esac

if [ -n "$weekly_left" ]; then
  parts+=("weekly $weekly_left% left")
fi

line="${parts[0]}"
for part in "${parts[@]:1}"; do
  line+=" · $part"
done
printf '%s\n' "$line"
