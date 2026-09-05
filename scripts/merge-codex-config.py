#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
import tomllib
from datetime import date, datetime, time
from pathlib import Path
from typing import Any


MACHINE_PATHS = {("projects",), ("notice",), ("marketplaces",), ("skills", "config")}


def merge_settings(machine: dict[str, Any], repo: dict[str, Any], path: tuple[str, ...] = ()) -> dict[str, Any]:
    merged = dict(machine)
    for key, value in repo.items():
        key_path = (*path, key)
        if key_path in MACHINE_PATHS:
            continue
        if isinstance(value, dict):
            current = merged.get(key, {})
            merged[key] = merge_settings(current if isinstance(current, dict) else {}, value, key_path)
        else:
            merged[key] = value
    return merged


def quoted_string(value: str) -> str:
    # TOML basic strings share JSON escapes, but also require escaping DEL.
    return json.dumps(value, ensure_ascii=False).replace("\x7f", "\\u007f")


def format_key(key: str) -> str:
    return key if re.fullmatch(r"[A-Za-z0-9_-]+", key) else quoted_string(key)


def format_value(value: Any) -> str:
    if isinstance(value, str):
        return quoted_string(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, (datetime, date, time)):
        return value.isoformat()
    if isinstance(value, list):
        return "[" + ", ".join(format_value(item) for item in value) + "]"
    return "{ " + ", ".join(f"{format_key(key)} = {format_value(item)}" for key, item in value.items()) + " }"


def is_table_array(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(item, dict) for item in value)


def format_table(table: dict[str, Any], path: tuple[str, ...] = (), array: bool = False) -> list[str]:
    header = ".".join(format_key(key) for key in path)
    lines = [("[[" + header + "]]" if array else "[" + header + "]")] if path else []
    for key, value in table.items():
        if not isinstance(value, dict) and not is_table_array(value):
            lines.append(f"{format_key(key)} = {format_value(value)}")
    for key, value in table.items():
        if isinstance(value, dict):
            lines.extend(["", *format_table(value, (*path, key))])
        elif is_table_array(value):
            # Codex edits skill selectors as arrays of tables, not inline arrays.
            for item in value:
                lines.extend(["", *format_table(item, (*path, key), array=True)])
    return lines


def merge(remote_text: str, repo_text: str) -> str:
    """Merge values, normalizing TOML layout and discarding source comments."""
    merged = merge_settings(tomllib.loads(remote_text), tomllib.loads(repo_text))
    return "\n".join(format_table(merged)).strip() + "\n"


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <remote-config.toml> <repo-config.toml>", file=sys.stderr)
        raise SystemExit(2)

    remote_path = Path(sys.argv[1])
    repo_path = Path(sys.argv[2])
    sys.stdout.write(merge(remote_path.read_text(), repo_path.read_text()))


if __name__ == "__main__":
    main()
