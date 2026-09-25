#!/usr/bin/env bash
set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Keep a small setup bundle on the host so activation can also run there later.
ssh "$REMOTE" 'mkdir -p ~/.local/share/agentrc-herdr/herdr ~/.local/share/agentrc-herdr/scripts'
scp -q "$ROOT_DIR"/herdr/{install.sh,configure.py,activate.sh,config.toml,automatic-rename.sh,sidebar.json,shell.zsh,plugins.tsv,README.md} \
  "$REMOTE:~/.local/share/agentrc-herdr/herdr/"
scp -q "$ROOT_DIR/scripts/merge-codex-config.py" "$REMOTE:~/.local/share/agentrc-herdr/scripts/"
ssh "$REMOTE" 'zsh -lc '\''export PATH="$HOME/.local/bin:$PATH"; bash "$HOME/.local/share/agentrc-herdr/herdr/install.sh" --merge'\'''
echo "Deployed Herdr settings and plugins -> $REMOTE"
echo 'For a running server, activate with: ~/.local/share/agentrc-herdr/herdr/activate.sh'
