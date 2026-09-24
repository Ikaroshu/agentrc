#!/usr/bin/env python3

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MERGE_SCRIPT = ROOT_DIR / "scripts" / "merge-claude-settings.py"


def run_merge(directory: Path, machine_text: str, repo_text: str) -> dict:
    machine = directory / "machine.json"
    repo = directory / "repo.json"
    machine.write_text(machine_text)
    repo.write_text(repo_text)
    output = subprocess.run(
        [sys.executable, str(MERGE_SCRIPT), str(machine), str(repo)],
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    return json.loads(output)


def main() -> None:
    machine = {
        "model": "old-model",
        "env": {"TOKEN": "secret"},
        "permissions": {"allow": ["Bash"], "defaultMode": "bypassPermissions"},
        "statusLine": {"type": "command", "command": "legacy", "padding": 1},
        "enabledPlugins": {"plugin@market": True},
    }
    repo = {
        "model": "opus",
        "effortLevel": "high",
        "statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"},
    }
    expected = {
        "model": "opus",
        "env": {"TOKEN": "secret"},
        "permissions": {"allow": ["Bash"], "defaultMode": "bypassPermissions"},
        "statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh", "padding": 1},
        "enabledPlugins": {"plugin@market": True},
        "effortLevel": "high",
    }

    with tempfile.TemporaryDirectory() as directory:
        merged = run_merge(Path(directory), json.dumps(machine), json.dumps(repo))
        if merged != expected:
            raise SystemExit(f"unexpected merge result: {merged}")
        if run_merge(Path(directory), "", json.dumps(repo)) != repo:
            raise SystemExit("missing machine settings should yield the repository baseline")

    print("Claude settings merge test passed.")


if __name__ == "__main__":
    main()
