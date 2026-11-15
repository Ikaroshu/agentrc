#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def package_identity(entry: str | dict[str, Any]) -> str:
    source = entry["source"] if isinstance(entry, dict) else entry
    if source.startswith("npm:"):
        name = source.removeprefix("npm:")
        version_at = name.find("@", 1)
        return "npm:" + (name[:version_at] if version_at > 0 else name)
    return source


def merge_packages(machine: list[Any], repo: list[Any]) -> list[Any]:
    """Repository pins replace the machine's entry for the same package, so a version bump leaves one copy."""
    repo_by_identity = {package_identity(entry): entry for entry in repo}
    merged = [repo_by_identity.pop(package_identity(entry), entry) for entry in machine]
    return merged + list(repo_by_identity.values())


def merge_settings(machine: dict[str, Any], repo: dict[str, Any]) -> dict[str, Any]:
    merged = dict(machine)
    for key, value in repo.items():
        current = merged.get(key)
        if key == "packages" and isinstance(current, list):
            merged[key] = merge_packages(current, value)
        elif isinstance(value, dict) and isinstance(current, dict):
            merged[key] = merge_settings(current, value)
        elif isinstance(value, list) and isinstance(current, list):
            merged[key] = current + [item for item in value if item not in current]
        else:
            merged[key] = value
    return merged


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <machine-settings.json> <repo-settings.json>", file=sys.stderr)
        raise SystemExit(2)

    machine_text = Path(sys.argv[1]).read_text()
    machine = json.loads(machine_text) if machine_text.strip() else {}
    repo = json.loads(Path(sys.argv[2]).read_text())
    sys.stdout.write(json.dumps(merge_settings(machine, repo), indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
