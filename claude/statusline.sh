#!/usr/bin/env bash
# Claude Code status line: model + effort · directory · Git branch · 5-hour and weekly limits left.

set -euo pipefail

input="$(cat)"
model="$(jq -r '.model.display_name' <<<"$input")"
effort="$(jq -r '.effort.level // empty' <<<"$input")"
cwd="$(jq -r '.workspace.current_dir' <<<"$input")"
five_hour_left="$(jq -r '.rate_limits.five_hour.used_percentage // empty | 100 - . | round' <<<"$input")"
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

if [ -n "$five_hour_left" ]; then
  parts+=("5h $five_hour_left% left")
fi

if [ -n "$weekly_left" ]; then
  parts+=("weekly $weekly_left% left")
fi

line="${parts[0]}"
for part in "${parts[@]:1}"; do
  line+=" · $part"
done
printf '%s\n' "$line"
