#!/usr/bin/env bash

set -euo pipefail

# Sets up this Mac's Herdr app from the repository, with the app running (its first launch creates
# keys.json). Copies the managed mods and layout into the app home, merges the managed keys and
# settings into its keys.json and settings.json, shows the managed layout, and installs the font
# the Files panel's file icons use. The app reloads them on save; other mods, layouts, keys,
# settings, and the app's own state are left alone.
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
LAYOUT=main-titled

mkdir -p "$APP_HOME"
cp -R "$SOURCE_DIR/mods" "$SOURCE_DIR/layouts" "$APP_HOME/"
python3 - "$SOURCE_DIR" "$APP_HOME" <<'PY'
import json
import sys
from pathlib import Path

source, home = Path(sys.argv[1]), Path(sys.argv[2])
keys = json.loads((home / "keys.json").read_text())
for section, bindings in json.loads((source / "keys.json").read_text()).items():
    keys.setdefault(section, {}).update(bindings)
(home / "keys.json").write_text(json.dumps(keys, indent=2) + "\n")

# A new app home may have no settings.json yet.
target = home / "settings.json"
settings = json.loads(target.read_text()) if target.exists() else {}
settings.update(json.loads((source / "settings.json").read_text()))
target.write_text(json.dumps(settings, indent=2) + "\n")
PY

# Switching rebuilds the window's blocks, so only when another layout shows.
if ! herdr-app status | grep -q "\"layout\": \"$LAYOUT\""; then
  herdr-app do layout.switch --name "$LAYOUT"
fi

brew list --cask font-symbols-only-nerd-font >/dev/null 2>&1 || brew install --cask font-symbols-only-nerd-font
