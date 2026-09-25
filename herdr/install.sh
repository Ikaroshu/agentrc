#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
command -v herdr
command -v jq

python3 - "$REPO_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
home = Path.home()
files = {
    'config.toml': '.config/herdr/config.toml',
    'automatic-rename.sh': '.config/herdr-automatic-rename/config.sh',
    'sidebar.json': '.local/state/herdr/plugins/herdr-sidebar/state.json',
    'shell.zsh': '.config/herdr/agentrc.zsh',
}
# Existing installations need a deliberate merge.
targets = [home / target for target in files.values()] + [home / '.local/bin/herdr-sidebar']
existing = [str(target) for target in targets if target.exists() or target.is_symlink()]
if existing:
    raise SystemExit('Fresh setup only; merge settings manually for existing files:\n' + '\n'.join(existing))
for source, target in files.items():
    destination = home / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / source, destination)
rc = home / '.zshrc'
text = rc.read_text() if rc.exists() else ''
line = 'source "$HOME/.config/herdr/agentrc.zsh"'
if line not in text.splitlines():
    rc.write_text(text.rstrip() + '\n\n' + line + '\n')
PY

while read -r plugin source revision; do
  herdr plugin install "$source" --ref "$revision" --yes
done < "$REPO_DIR/plugins.tsv"

SIDEBAR_ROOT="$(jq -r '.[] | select(.plugin_id == "herdr-sidebar") | .plugin_root' "$HOME/.config/herdr/plugins.json")"
mkdir -p "$HOME/.local/bin"
ln -s "$SIDEBAR_ROOT/target/release/herdr-sidebar" "$HOME/.local/bin/herdr-sidebar"
herdr config check
echo 'Installed. Select the font described in herdr/README.md, launch Herdr, then run herdr/activate.sh.'
