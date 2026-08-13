#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
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


def output_hash(output: bytes) -> str:
    return hashlib.sha256(output).hexdigest()


def untracked_state(
    repository: Path,
    registered_worktrees: set[Path],
) -> dict[str, dict[str, object]]:
    paths = run_git(
        repository,
        "ls-files",
        "--others",
        "--exclude-standard",
        "-z",
    ).split(b"\0")
    entries = {}
    for raw_path in paths:
        if not raw_path:
            continue
        relative = raw_path.decode(errors="surrogateescape")
        path = repository / relative
        metadata = path.lstat()
        if path.is_symlink():
            kind = "symlink"
            payload = os.readlink(path)
        elif path.is_file():
            kind = "file"
            payload = hashlib.sha256(path.read_bytes()).hexdigest()
        elif path.is_dir() and path.resolve() in registered_worktrees:
            continue
        else:
            raise SystemExit(f"unsupported untracked path type: {path}")
        entries[relative] = {
            "kind": kind,
            "mode": stat.S_IMODE(metadata.st_mode),
            "payload": payload,
        }
    return entries


def worktree_paths(repository: Path) -> tuple[bytes, list[Path]]:
    inventory = run_git(repository, "worktree", "list", "--porcelain", "-z")
    paths = [
        Path(field.removeprefix(b"worktree ").decode(errors="surrogateescape"))
        for field in inventory.split(b"\0")
        if field.startswith(b"worktree ")
    ]
    return inventory, paths


def semantic_index(repository: Path) -> str:
    return output_hash(run_git(repository, "ls-files", "--stage", "-v", "-z"))


def sibling_worktree_states(repository: Path, paths: list[Path]) -> dict[str, object]:
    states = {}
    registered_worktrees = {path.resolve() for path in paths}
    for path in paths:
        resolved = path.resolve()
        if resolved == repository:
            continue
        states[str(resolved)] = {
            "status": output_hash(
                run_git(
                    resolved,
                    "status",
                    "--porcelain=v1",
                    "-z",
                    "--untracked-files=all",
                )
            ),
            "diff": output_hash(
                run_git(resolved, "diff", "--no-ext-diff", "--binary", "HEAD", "--")
            ),
            "cached_diff": output_hash(
                run_git(
                    resolved,
                    "diff",
                    "--cached",
                    "--no-ext-diff",
                    "--binary",
                    "HEAD",
                    "--",
                )
            ),
            "index": semantic_index(resolved),
            "untracked": untracked_state(resolved, registered_worktrees),
        }
    return states


def protected_path_state(path: Path) -> dict[str, object]:
    absolute = Path(os.path.abspath(path))
    if not absolute.exists():
        return {"missing": True}
    if not absolute.is_file():
        raise SystemExit(f"protected path must be a file: {absolute}")
    metadata = absolute.lstat()
    return {
        "missing": False,
        "mode": stat.S_IMODE(metadata.st_mode),
        "symlink": os.readlink(absolute) if absolute.is_symlink() else None,
        "content": hashlib.sha256(absolute.read_bytes()).hexdigest(),
    }


def protected_paths_state(paths: list[Path]) -> dict[str, object]:
    return {
        str(Path(os.path.abspath(path))): protected_path_state(path) for path in paths
    }


def snapshot_state(
    repository: Path,
    require_clean: bool,
    protected_paths: list[Path],
) -> dict[str, object]:
    root = repository_root(repository)
    status = run_git(root, "status", "--porcelain=v1", "--untracked-files=all")
    if require_clean and status:
        sys.stderr.write("worktree must be completely clean before dispatch:\n")
        sys.stderr.buffer.write(status)
        raise SystemExit(1)

    worktrees, paths = worktree_paths(root)

    return {
        "repository": str(root),
        "head": run_git(root, "rev-parse", "HEAD").decode().strip(),
        "branch": run_git(root, "branch", "--show-current").decode().strip(),
        "refs": run_git(
            root,
            "for-each-ref",
            "--format=%(refname) %(objectname) %(symref)",
        ).decode(),
        "index": semantic_index(root),
        "worktrees": worktrees.decode(errors="surrogateescape"),
        "sibling_worktrees": sibling_worktree_states(root, paths),
        "protected_paths": protected_paths_state(protected_paths),
    }


def write_snapshot(repository: Path, output: Path, protected_paths: list[Path]) -> None:
    for path in protected_paths:
        absolute = Path(os.path.abspath(path))
        if not absolute.exists():
            raise SystemExit(f"protected path does not exist: {absolute}")
    state = snapshot_state(repository, require_clean=True, protected_paths=protected_paths)
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
    protected_paths = [Path(path) for path in before["protected_paths"]]
    after = snapshot_state(
        repository,
        require_clean=False,
        protected_paths=protected_paths,
    )

    violations = []
    for field in (
        "repository",
        "head",
        "branch",
        "refs",
        "index",
        "worktrees",
        "sibling_worktrees",
        "protected_paths",
    ):
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
    snapshot_parser.add_argument("--protect-path", action="append", type=Path, default=[])

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--repository", type=Path, required=True)
    verify_parser.add_argument("--snapshot", type=Path, required=True)
    verify_parser.add_argument("--allow-path", action="append", default=[])

    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    if arguments.command == "snapshot":
        write_snapshot(arguments.repository, arguments.output, arguments.protect_path)
    else:
        verify_snapshot(arguments.repository, arguments.snapshot, arguments.allow_path)


if __name__ == "__main__":
    main()
