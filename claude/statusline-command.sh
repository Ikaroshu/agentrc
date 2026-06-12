#!/bin/bash
# Claude Code status line — cwd, git branch, model, context bar.
# Segments are packed across as many rows as needed to fit $COLUMNS, so a long
# path or branch name never pushes the model/context bar off-screen.
input=$(cat)

BAR_WIDTH=20
COLS=$(( ${COLUMNS:-80} - 1 ))   # -1 guards the exact-fit boundary

reset='\033[0m'
dim='\033[38;5;242m'
cyan='\033[38;5;81m'
magenta='\033[38;5;177m'
yellow='\033[38;5;229m'
red='\033[38;5;203m'

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

repo_cwd=$(echo "$input" | jq -r '.cwd // empty')

# --- Current working directory (home abbreviated as ~) ---
cwd="$repo_cwd"
if [ -z "$cwd" ]; then
  cwd=$(pwd)
fi
cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

# --- Git branch (only if inside a git repo) ---
branch=""
git_dir=$(git -C "$repo_cwd" rev-parse --git-dir 2>/dev/null)
if [ -n "$git_dir" ]; then
  branch=$(git -C "$repo_cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$repo_cwd" rev-parse --short HEAD 2>/dev/null)
  fi
fi

# --- Git status indicators ---
git_status=""
if [ -n "$git_dir" ]; then
  staged=$(git -C "$repo_cwd" diff --cached --quiet 2>/dev/null; echo $?)
  unstaged=$(git -C "$repo_cwd" diff --quiet 2>/dev/null; echo $?)
  untracked=$(git -C "$repo_cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)
  if [ "$staged" = "1" ]; then git_status="${git_status}+"; fi
  if [ "$unstaged" = "1" ]; then git_status="${git_status}!"; fi
  if [ -n "$untracked" ]; then git_status="${git_status}?"; fi
fi

# --- Model display name ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Context window usage ---
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$ctx_pct" ]; then
  ctx_pct=0
fi
ctx_pct=$(printf '%.0f' "$ctx_pct")

# --- Build segments (parallel arrays: plain text for width, colored for output,
#     and the separator to use when this segment follows another on the same row) ---
seg_plain=()
seg_color=()
seg_sep_plain=()
seg_sep_color=()

add_seg() {
  seg_plain+=("$1")
  seg_color+=("$2")
  seg_sep_plain+=("$3")
  seg_sep_color+=("$4")
}

# Path — truncate with a leading ellipsis if it alone exceeds the terminal width.
path_plain="$cwd"
if [ ${#path_plain} -gt "$COLS" ] && [ "$COLS" -gt 1 ]; then
  keep=$(( COLS - 1 ))
  path_plain="…${path_plain: -keep}"
fi
add_seg "$path_plain" "${cyan}${path_plain}${reset}" "" ""

# Branch (+ status)
if [ -n "$branch" ]; then
  if [ -n "$git_status" ]; then
    bp="on ${branch} [${git_status}]"
    bc="${dim}on${reset} ${magenta}${branch}${reset} ${dim}[${reset}${red}${git_status}${dim}]${reset}"
  else
    bp="on ${branch}"
    bc="${dim}on${reset} ${magenta}${branch}${reset}"
  fi
  add_seg "$bp" "$bc" " " " "
fi

# Model
if [ -n "$model" ]; then
  add_seg "$model" "${yellow}${model}${reset}" " | " " ${dim}|${reset} "
fi

# Context bar
bar_color=$(make_bar "$ctx_pct")
bar_w=$(( BAR_WIDTH + 7 ))   # "[" + bar + "] " + "100%"
bar_plain=$(printf '%*s' "$bar_w" '')
add_seg "$bar_plain" "$bar_color" " | " " ${dim}|${reset} "

# --- Greedily pack segments across rows so each row fits within $COLS ---
out=""
line_w=0
first_on_line=1

n=${#seg_plain[@]}
i=0
while [ "$i" -lt "$n" ]; do
  w=${#seg_plain[$i]}
  if [ "$first_on_line" -eq 1 ]; then
    out="${out}${seg_color[$i]}"
    line_w=$w
    first_on_line=0
  else
    sep_w=${#seg_sep_plain[$i]}
    if [ $(( line_w + sep_w + w )) -le "$COLS" ]; then
      out="${out}${seg_sep_color[$i]}${seg_color[$i]}"
      line_w=$(( line_w + sep_w + w ))
    else
      out="${out}\n${seg_color[$i]}"
      line_w=$w
    fi
  fi
  i=$(( i + 1 ))
done

printf '%b' "$out"
