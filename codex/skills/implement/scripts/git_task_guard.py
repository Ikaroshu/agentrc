#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import subprocess
import sys


def run_git(repository: Path, *arguments: str) -> bytes:
    return subprocess.run(
        ["git", *arguments],
        cwd=repository,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout


def repository_root(repository: Path) -> Path:
    root = run_git(repository, "rev-parse", "--show-toplevel").decode().strip()
    return Path(root).resolve()


def snapshot_state(repository: Path, require_clean: bool) -> dict[str, object]:
    root = repository_root(repository)
    status = run_git(root, "status", "--porcelain=v1", "--untracked-files=all")
    if require_clean and status:
        sys.stderr.write("worktree must be completely clean before dispatch:\n")
        sys.stderr.buffer.write(status)
        raise SystemExit(1)

    return {
        "repository": str(root),
        "head": run_git(root, "rev-parse", "HEAD").decode().strip(),
        "branch": run_git(root, "branch", "--show-current").decode().strip(),
        "refs": run_git(
            root,
            "for-each-ref",
            "--format=%(refname) %(objectname) %(symref)",
            "refs/heads",
            "refs/remotes",
        ).decode(),
        "worktrees": run_git(root, "worktree", "list", "--porcelain").decode(),
    }


def write_snapshot(repository: Path, output: Path) -> None:
    state = snapshot_state(repository, require_clean=True)
    output.write_text(json.dumps(state, sort_keys=True, indent=2) + "\n")


def status_paths(repository: Path) -> list[str]:
    output = run_git(
        repository,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
    )
    records = output.split(b"\0")
    paths: list[str] = []
    index = 0
    while index < len(records) and records[index]:
        record = records[index]
        status = record[:2]
        paths.append(record[3:].decode(errors="surrogateescape"))
        index += 1
        if b"R" in status or b"C" in status:
            paths.append(records[index].decode(errors="surrogateescape"))
            index += 1
    return paths


def owned(path: str, allow_paths: list[str]) -> bool:
    for allowed in allow_paths:
        if allowed.endswith("/"):
            if path.startswith(allowed):
                return True
        elif path == allowed:
            return True
    return False


def verify_snapshot(repository: Path, snapshot: Path, allow_paths: list[str]) -> None:
    before = json.loads(snapshot.read_text())
    after = snapshot_state(repository, require_clean=False)

    violations = []
    for field in ("repository", "head", "branch", "refs", "worktrees"):
        if before[field] != after[field]:
            violations.append(f"{field} changed during implementation phase")

    outside_ownership = sorted(
        path for path in status_paths(repository_root(repository)) if not owned(path, allow_paths)
    )
    if outside_ownership:
        violations.append(
            "paths outside task ownership changed: " + ", ".join(outside_ownership)
        )

    if violations:
        raise SystemExit("\n".join(violations))


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    snapshot_parser = subparsers.add_parser("snapshot")
    snapshot_parser.add_argument("--repository", type=Path, required=True)
    snapshot_parser.add_argument("--output", type=Path, required=True)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--repository", type=Path, required=True)
    verify_parser.add_argument("--snapshot", type=Path, required=True)
    verify_parser.add_argument("--allow-path", action="append", default=[])

    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    if arguments.command == "snapshot":
        write_snapshot(arguments.repository, arguments.output)
    else:
        verify_snapshot(arguments.repository, arguments.snapshot, arguments.allow_path)


if __name__ == "__main__":
    main()
