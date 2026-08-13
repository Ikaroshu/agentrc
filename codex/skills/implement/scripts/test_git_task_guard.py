#!/usr/bin/env python3

from pathlib import Path
import subprocess
import sys
import tempfile


GUARD = Path(__file__).with_name("git_task_guard.py")


def run(*arguments: str, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        arguments,
        cwd=cwd,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def create_repository(parent: Path, name: str) -> Path:
    repository = parent / name
    repository.mkdir()
    run("git", "init", "-q", "-b", "main", cwd=repository)
    run("git", "config", "user.name", "Guard Test", cwd=repository)
    run("git", "config", "user.email", "guard@example.invalid", cwd=repository)
    (repository / "owned.txt").write_text("owned\n")
    (repository / "other.txt").write_text("other\n")
    run("git", "add", "owned.txt", "other.txt", cwd=repository)
    run("git", "commit", "-q", "-m", "fixture", cwd=repository)
    return repository


def snapshot(repository: Path, output: Path) -> subprocess.CompletedProcess[str]:
    return run(
        sys.executable,
        str(GUARD),
        "snapshot",
        "--repository",
        str(repository),
        "--output",
        str(output),
        cwd=repository,
        check=False,
    )


def verify(
    repository: Path, output: Path, *allow_paths: str
) -> subprocess.CompletedProcess[str]:
    arguments = [
        sys.executable,
        str(GUARD),
        "verify",
        "--repository",
        str(repository),
        "--snapshot",
        str(output),
    ]
    for path in allow_paths:
        arguments.extend(("--allow-path", path))
    return run(*arguments, cwd=repository, check=False)


def require_failure(result: subprocess.CompletedProcess[str], text: str) -> None:
    assert result.returncode != 0, result
    assert text in result.stderr, result.stderr


def test_dirty_worktrees(parent: Path) -> None:
    scenarios = {
        "staged": lambda repository: (
            (repository / "owned.txt").write_text("staged\n"),
            run("git", "add", "owned.txt", cwd=repository),
        ),
        "unstaged": lambda repository: (
            (repository / "owned.txt").write_text("unstaged\n"),
        ),
        "untracked-file": lambda repository: (
            (repository / "untracked.txt").write_text("untracked\n"),
        ),
        "untracked-directory": lambda repository: (
            (repository / "untracked").mkdir(),
            (repository / "untracked" / "nested.txt").write_text("nested\n"),
        ),
    }
    for name, mutate in scenarios.items():
        repository = create_repository(parent, f"dirty-{name}")
        mutate(repository)
        result = snapshot(repository, parent / f"{name}.json")
        require_failure(result, "worktree must be completely clean before dispatch")


def test_allowed_changes(parent: Path) -> None:
    repository = create_repository(parent, "allowed")
    output = parent / "allowed.json"
    assert snapshot(repository, output).returncode == 0
    (repository / "owned.txt").write_text("allowed\n")
    (repository / "owned-dir").mkdir()
    (repository / "owned-dir" / "nested.txt").write_text("allowed nested\n")
    result = verify(repository, output, "owned.txt", "owned-dir/")
    assert result.returncode == 0, result.stderr


def test_head_change(parent: Path) -> None:
    repository = create_repository(parent, "head")
    output = parent / "head.json"
    assert snapshot(repository, output).returncode == 0
    (repository / "owned.txt").write_text("committed\n")
    run("git", "add", "owned.txt", cwd=repository)
    run("git", "commit", "-q", "-m", "forbidden", cwd=repository)
    require_failure(verify(repository, output, "owned.txt"), "head changed")


def test_branch_change(parent: Path) -> None:
    repository = create_repository(parent, "branch")
    run("git", "branch", "other", cwd=repository)
    output = parent / "branch.json"
    assert snapshot(repository, output).returncode == 0
    run("git", "switch", "-q", "other", cwd=repository)
    require_failure(verify(repository, output), "branch changed")


def test_ref_change(parent: Path) -> None:
    repository = create_repository(parent, "ref")
    output = parent / "ref.json"
    assert snapshot(repository, output).returncode == 0
    run("git", "update-ref", "refs/heads/other", "HEAD", cwd=repository)
    require_failure(verify(repository, output), "refs changed")


def test_worktree_change(parent: Path) -> None:
    repository = create_repository(parent, "worktree")
    output = parent / "worktree.json"
    assert snapshot(repository, output).returncode == 0
    linked = parent / "linked-worktree"
    run("git", "worktree", "add", "-q", "--detach", str(linked), "HEAD", cwd=repository)
    require_failure(verify(repository, output), "worktrees changed")


def test_out_of_ownership_change(parent: Path) -> None:
    repository = create_repository(parent, "ownership")
    output = parent / "ownership.json"
    assert snapshot(repository, output).returncode == 0
    (repository / "other.txt").write_text("outside ownership\n")
    require_failure(
        verify(repository, output, "owned.txt"),
        "paths outside task ownership changed: other.txt",
    )


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary_directory:
        parent = Path(temporary_directory)
        test_dirty_worktrees(parent)
        test_allowed_changes(parent)
        test_head_change(parent)
        test_branch_change(parent)
        test_ref_change(parent)
        test_worktree_change(parent)
        test_out_of_ownership_change(parent)
    print("Implement task guard tests passed (10 deterministic scenarios).")


if __name__ == "__main__":
    main()
