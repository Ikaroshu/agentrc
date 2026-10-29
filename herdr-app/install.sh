#!/usr/bin/env bash

set -euo pipefail

# Copies the managed mods and layout into this Mac's Herdr app home. The app reloads them on save;
# other mods, layouts, settings, and the app's own state are left alone.
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"

mkdir -p "$APP_HOME"
cp -R "$SOURCE_DIR/mods" "$SOURCE_DIR/layouts" "$APP_HOME/"
