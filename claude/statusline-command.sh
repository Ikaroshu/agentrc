#!/bin/sh
# Claude Code status line — cwd, git branch, model, context bar
input=$(cat)

BAR_WIDTH=20

reset='\033[0m'
dim='\033[38;5;242m'
bold='\033[1m'
cyan='\033[38;5;81m'
magenta='\033[38;5;177m'
yellow='\033[38;5;229m'

make_bar() {
  pct="$1"

  if [ "$pct" -lt 0 ]; then pct=0; fi
  if [ "$pct" -gt 100 ]; then pct=100; fi

  filled=$(( pct * BAR_WIDTH / 100 ))
  empty=$(( BAR_WIDTH - filled ))

  if [ "$pct" -ge 80 ]; then
    fill_color='\033[38;5;203m'   # red
  elif [ "$pct" -ge 50 ]; then
    fill_color='\033[38;5;229m'   # yellow
  else
    fill_color='\033[38;5;114m'   # green
  fi

  filled_str=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    filled_str="${filled_str}█"
    i=$(( i + 1 ))
  done

  empty_str=""
  i=0
  while [ "$i" -lt "$empty" ]; do
    empty_str="${empty_str}░"
    i=$(( i + 1 ))
  done

  printf "${dim}[${fill_color}%s${dim}%s${reset}${dim}] %3d%%${reset}" \
    "$filled_str" "$empty_str" "$pct"
}

# --- Current working directory ---
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  cwd=$(pwd)
fi
# Abbreviate home directory as ~
cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

# --- Git branch (only if inside a git repo) ---
branch=""
git_dir=$(git -C "$(echo "$input" | jq -r '.cwd // empty')" rev-parse --git-dir 2>/dev/null)
if [ -n "$git_dir" ]; then
  branch=$(git -C "$(echo "$input" | jq -r '.cwd // empty')" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    # Detached HEAD — show short commit hash
    branch=$(git -C "$(echo "$input" | jq -r '.cwd // empty')" rev-parse --short HEAD 2>/dev/null)
  fi
fi

# --- Git status indicators ---
git_status=""
if [ -n "$git_dir" ]; then
  repo_cwd=$(echo "$input" | jq -r '.cwd // empty')
  staged=$(git -C "$repo_cwd" diff --cached --quiet 2>/dev/null; echo $?)
  unstaged=$(git -C "$repo_cwd" diff --quiet 2>/dev/null; echo $?)
  untracked=$(git -C "$repo_cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)
  if [ "$staged" = "1" ]; then git_status="${git_status}+"; fi
  if [ "$unstaged" = "1" ]; then git_status="${git_status}!"; fi
  if [ -n "$untracked" ]; then git_status="${git_status}?"; fi
fi

# --- Model display name ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Context window usage bar ---
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$ctx_pct" ]; then
  ctx_pct=0
fi
ctx_pct=$(printf '%.0f' "$ctx_pct")

# --- Compose output ---
# cwd
printf "${cyan}${cwd}${reset}"

# git branch
if [ -n "$branch" ]; then
  if [ -n "$git_status" ]; then
    printf " ${dim}on${reset} ${magenta}${branch}${reset} ${dim}[${reset}\033[38;5;203m%s${dim}]${reset}" "$git_status"
  else
    printf " ${dim}on${reset} ${magenta}${branch}${reset}"
  fi
fi

# model
if [ -n "$model" ]; then
  printf " ${dim}|${reset} ${yellow}${model}${reset}"
fi

# context bar
printf " ${dim}|${reset} "
make_bar "$ctx_pct"
