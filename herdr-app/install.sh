#!/usr/bin/env bash

set -euo pipefail

# Copies the managed mods and layout into this Mac's Herdr app home and merges the managed keys
# into its keys.json. The app reloads them on save; other mods, layouts, keys, settings, and the
# app's own state are left alone.
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"

mkdir -p "$APP_HOME"
cp -R "$SOURCE_DIR/mods" "$SOURCE_DIR/layouts" "$APP_HOME/"
python3 - "$SOURCE_DIR/keys.json" "$APP_HOME/keys.json" <<'PY'
import json
import sys
from pathlib import Path

managed = json.loads(Path(sys.argv[1]).read_text())
target = Path(sys.argv[2])
keys = json.loads(target.read_text())
for section, bindings in managed.items():
    keys.setdefault(section, {}).update(bindings)
target.write_text(json.dumps(keys, indent=2) + "\n")
PY
