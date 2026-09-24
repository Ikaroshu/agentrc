#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def merge_settings(machine: dict[str, Any], repo: dict[str, Any]) -> dict[str, Any]:
    merged = dict(machine)
    for key, value in repo.items():
        current = merged.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            merged[key] = merge_settings(current, value)
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
