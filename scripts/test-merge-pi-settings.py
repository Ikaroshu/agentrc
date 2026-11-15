#!/usr/bin/env python3

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MERGE_SCRIPT = ROOT_DIR / "scripts" / "merge-pi-settings.py"


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
        "defaultModel": "old-model",
        "lastChangelogVersion": "1.5.2",
        "enabledModels": ["machine/model", "openai/gpt-6.1-terra"],
        "packages": [
            "npm:pi-memory@0.4.1",
            "npm:@scope/local-tool@2.0.0",
            {"source": "npm:pi-web-search@1.6.0", "extensions": []},
            "git:github.com/user/machine-pkg",
        ],
        "skills": ["~/machine-skills"],
    }
    repo = {
        "defaultModel": "gpt-6.1-terra",
        "enabledModels": ["openai/gpt-6.1-terra", "anthropic/claude-opus-5-5"],
        "packages": ["npm:pi-web-search@1.7.0", "npm:pi-memory@0.4.2", "npm:@scope/new-tool@1.0.0"],
        "skills": ["!~/.agents/skills/**"],
    }
    expected = {
        "defaultModel": "gpt-6.1-terra",
        "lastChangelogVersion": "1.5.2",
        "enabledModels": ["machine/model", "openai/gpt-6.1-terra", "anthropic/claude-opus-5-5"],
        "packages": [
            "npm:pi-memory@0.4.2",
            "npm:@scope/local-tool@2.0.0",
            "npm:pi-web-search@1.7.0",
            "git:github.com/user/machine-pkg",
            "npm:@scope/new-tool@1.0.0",
        ],
        "skills": ["~/machine-skills", "!~/.agents/skills/**"],
    }

    with tempfile.TemporaryDirectory() as directory:
        merged = run_merge(Path(directory), json.dumps(machine), json.dumps(repo))
        if merged != expected:
            raise SystemExit(f"unexpected merge result: {merged}")
        if run_merge(Path(directory), "", json.dumps(repo)) != repo:
            raise SystemExit("missing machine settings should yield the repository baseline")

    print("Pi settings merge test passed.")


if __name__ == "__main__":
    main()
