#!/usr/bin/env bash
# Sync Codex CLI settings to a remote machine via scp.
# Copies AGENTS.md directly. Merges config.toml so machine-specific
# project trust settings are preserved.
#
# Usage:
#   ./codex/sync-remote.sh mini

set -euo pipefail

REMOTE="${1:?Usage: $0 <ssh-host>}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

ssh "$REMOTE" 'mkdir -p ~/.codex'

# AGENTS.md: always overwrite (no machine-specific content)
scp -q "$REPO_DIR/AGENTS.md" "$REMOTE:~/.codex/AGENTS.md"

# config.toml: merge — keep remote's [projects.*] and [notice.*] sections,
# update shared keys (model, personality, plugins)
REMOTE_CONFIG=$(ssh "$REMOTE" 'cat ~/.codex/config.toml 2>/dev/null || echo ""')
REPO_CONFIG=$(cat "$REPO_DIR/config.toml")

python3 -c '
import sys, re

remote = sys.argv[1]
repo = sys.argv[2]

# Parse TOML sections naively (good enough for flat codex config)
def parse_sections(text):
    """Return (top-level keys, section blocks)."""
    top = []
    sections = {}
    current = None
    for line in text.splitlines():
        header = re.match(r"^\[(.+)\]$", line)
        if header:
            current = header.group(0)
            sections[current] = [line]
        elif current:
            sections[current].append(line)
        else:
            top.append(line)
    return top, sections

repo_top, repo_sections = parse_sections(repo)
remote_top, remote_sections = parse_sections(remote)

# Start with repo top-level keys (model, personality, etc.)
out = list(repo_top)

# Add repo plugin sections only (not projects — those are machine-specific)
for key, lines in repo_sections.items():
    if key.startswith("[plugins."):
        out.append("")
        out.extend(lines)

# Preserve all remote sections (projects, notice, plugins not in repo, etc.)
for key, lines in remote_sections.items():
    if key not in repo_sections:
        out.append("")
        out.extend(lines)

print("\n".join(out))
' "$REMOTE_CONFIG" "$REPO_CONFIG" | ssh "$REMOTE" 'cat > ~/.codex/config.toml'

echo "Sync complete → $REMOTE"
