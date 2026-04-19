#!/bin/bash
# Global file suggestion for Claude Code @ autocomplete
# Uses rg for file listing + fzf for fuzzy matching with path-aware scoring
#
# Per-project customization:
#   Create .claude/file-suggestion-extra.sh in your project root.
#   It runs in the project directory and should output additional file/folder
#   paths (one per line) to include in suggestions. Example:
#
#     #!/bin/bash
#     EXCLUDES=(-g '!__pycache__/' -g '!*.pyc')
#     # Include gitignored scratch dirs
#     [ -d zscratches ] && rg --files --follow --no-ignore-vcs "${EXCLUDES[@]}" zscratches
#     [ -d docs ] && rg --files --follow --no-ignore-vcs "${EXCLUDES[@]}" docs
#     # Include their subdirectories
#     [ -d zscratches ] && find zscratches -type d -not -name __pycache__ -print | sed 's|$|/|'

read -r INPUT
QUERY=$(printf '%s' "$INPUT" | sed -n 's/.*"query" *: *"\([^"]*\)".*/\1/p')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

EXCLUDES=(-g '!.git/' -g '!.github/' -g '!__pycache__/' -g '!.venv/' -g '!.cache/' -g '!*.pyc' -g '!node_modules/')

list_dirs() {
  fd --type d --follow --hidden \
     --exclude .git --exclude __pycache__ --exclude .venv --exclude .cache --exclude node_modules \
     --exclude .pytest_cache --exclude .ruff_cache --exclude .mypy_cache --exclude .github \
     . "$1" 2>/dev/null \
    | sed "s|^\./||"
}

{
  # Git-tracked files
  rg --files --follow --hidden "${EXCLUDES[@]}" . 2>/dev/null

  # Tracked directories
  list_dirs .

  # Project-local extras (gitignored dirs, custom sources, etc.)
  EXTRA="$PROJECT_DIR/.claude/file-suggestion-extra.sh"
  [ -x "$EXTRA" ] && "$EXTRA"
} | sed 's|^\./||' | sort -u | fzf --filter "$QUERY" --scheme=path | head -15
