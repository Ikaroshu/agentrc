#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


SECTION_RE = re.compile(r"^(\[\[?.+\]\]?)$")
TOP_LEVEL_KEY_RE = re.compile(r"^([A-Za-z0-9_-]+)\s*=")


@dataclass(frozen=True)
class Block:
    header: str
    lines: list[str]

    @property
    def name(self) -> str:
        if self.header.startswith("[["):
            return self.header[2:-2].strip()

        return self.header[1:-1].strip()


def split_blocks(text: str) -> tuple[list[str], list[Block]]:
    top_lines: list[str] = []
    blocks: list[Block] = []
    current_header: str | None = None
    current_lines: list[str] = []

    for line in text.splitlines():
        match = SECTION_RE.match(line)
        if match:
            if current_header is not None:
                blocks.append(Block(current_header, current_lines))

            current_header = match.group(1)
            current_lines = [line]
            continue

        if current_header is None:
            top_lines.append(line)
        else:
            current_lines.append(line)

    if current_header is not None:
        blocks.append(Block(current_header, current_lines))

    return trim_blank_edges(top_lines), blocks


def trim_blank_edges(lines: list[str]) -> list[str]:
    start = 0
    end = len(lines)

    while start < end and lines[start] == "":
        start += 1

    while end > start and lines[end - 1] == "":
        end -= 1

    return lines[start:end]


def is_machine_specific(name: str) -> bool:
    return (
        name.startswith("projects.")
        or name.startswith("notice.")
        or name.startswith("marketplaces.")
        or name == "skills.config"
    )


def append_block(output: list[str], block: Block) -> None:
    if output and output[-1] != "":
        output.append("")

    output.extend(block.lines)


def merge(remote_text: str, repo_text: str) -> str:
    repo_top, repo_blocks = split_blocks(repo_text)
    remote_top, remote_blocks = split_blocks(remote_text)

    repo_top_keys = {
        match.group(1)
        for line in repo_top
        if (match := TOP_LEVEL_KEY_RE.match(line)) is not None
    }
    remote_machine_top = [
        line
        for line in remote_top
        if (match := TOP_LEVEL_KEY_RE.match(line)) is not None
        and match.group(1) not in repo_top_keys
    ]

    repo_shared_blocks = [block for block in repo_blocks if not is_machine_specific(block.name)]
    repo_shared_names = {block.name for block in repo_shared_blocks}

    output = list(repo_top)

    if remote_machine_top:
        output.append("")
        output.extend(remote_machine_top)

    for block in repo_shared_blocks:
        append_block(output, block)

    for block in remote_blocks:
        if is_machine_specific(block.name) or block.name not in repo_shared_names:
            append_block(output, block)

    return "\n".join(output).rstrip() + "\n"


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <remote-config.toml> <repo-config.toml>", file=sys.stderr)
        raise SystemExit(2)

    remote_path = Path(sys.argv[1])
    repo_path = Path(sys.argv[2])
    sys.stdout.write(merge(remote_path.read_text(), repo_path.read_text()))


if __name__ == "__main__":
    main()
