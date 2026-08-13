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


def snapshot(
    repository: Path, output: Path, *protected_paths: Path
) -> subprocess.CompletedProcess[str]:
    arguments = [
        sys.executable,
        str(GUARD),
        "snapshot",
        "--repository",
        str(repository),
        "--output",
        str(output),
    ]
    for path in protected_paths:
        arguments.extend(("--protect-path", str(path)))
    return run(*arguments, cwd=repository, check=False)


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


def test_ref_changes(parent: Path) -> None:
    scenarios = {
        "tag": lambda repository: run("git", "tag", "forbidden", cwd=repository),
        "stash": lambda repository: (
            (repository / "owned.txt").write_text("stashed\n"),
            run("git", "stash", "push", "-q", cwd=repository),
        ),
        "notes": lambda repository: run(
            "git", "notes", "add", "-m", "forbidden", "HEAD", cwd=repository
        ),
    }
    for name, mutate in scenarios.items():
        repository = create_repository(parent, f"ref-{name}")
        output = parent / f"ref-{name}.json"
        assert snapshot(repository, output).returncode == 0
        mutate(repository)
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


def test_staged_allowed_change(parent: Path) -> None:
    repository = create_repository(parent, "staged-return")
    output = parent / "staged-return.json"
    assert snapshot(repository, output).returncode == 0
    (repository / "owned.txt").write_text("staged by task owner\n")
    run("git", "add", "owned.txt", cwd=repository)
    require_failure(verify(repository, output, "owned.txt"), "index changed")


def test_index_flag_change(parent: Path) -> None:
    repository = create_repository(parent, "index-flag")
    output = parent / "index-flag.json"
    assert snapshot(repository, output).returncode == 0
    run("git", "update-index", "--assume-unchanged", "other.txt", cwd=repository)
    (repository / "other.txt").write_text("hidden outside ownership\n")
    require_failure(verify(repository, output, "owned.txt"), "index changed")


def test_sibling_worktree_change(parent: Path) -> None:
    repository = create_repository(parent, "sibling-repository")
    sibling = parent / "sibling-worktree"
    run(
        "git",
        "worktree",
        "add",
        "-q",
        "-b",
        "sibling",
        str(sibling),
        "HEAD",
        cwd=repository,
    )
    output = parent / "sibling.json"
    assert snapshot(repository, output).returncode == 0
    (sibling / "owned.txt").write_text("changed in sibling\n")
    require_failure(verify(repository, output), "sibling_worktrees changed")


def test_nested_worktree_layout(parent: Path) -> None:
    repository = create_repository(parent, "nested-repository")
    feature = repository / ".worktrees" / "feature"
    run(
        "git",
        "worktree",
        "add",
        "-q",
        "-b",
        "feature",
        str(feature),
        "HEAD",
        cwd=repository,
    )
    output = parent / "nested.json"
    result = snapshot(feature, output)
    assert result.returncode == 0, result.stderr
    result = verify(feature, output)
    assert result.returncode == 0, result.stderr
    (repository / "owned.txt").write_text("changed in main sibling\n")
    require_failure(verify(feature, output), "sibling_worktrees changed")


def test_ignored_protected_path_change(parent: Path) -> None:
    repository = create_repository(parent, "protected")
    (repository / ".gitignore").write_text(".plans/\n")
    run("git", "add", ".gitignore", cwd=repository)
    run("git", "commit", "-q", "-m", "ignore plans", cwd=repository)
    plan = repository / ".plans" / "plan.md"
    plan.parent.mkdir()
    plan.write_text("approved plan\n")
    output = parent / "protected.json"
    assert snapshot(repository, output, plan).returncode == 0
    plan.write_text("mutated plan\n")
    require_failure(verify(repository, output), "protected_paths changed")


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary_directory:
        parent = Path(temporary_directory)
        test_dirty_worktrees(parent)
        test_allowed_changes(parent)
        test_head_change(parent)
        test_branch_change(parent)
        test_ref_changes(parent)
        test_worktree_change(parent)
        test_out_of_ownership_change(parent)
        test_staged_allowed_change(parent)
        test_index_flag_change(parent)
        test_sibling_worktree_change(parent)
        test_nested_worktree_layout(parent)
        test_ignored_protected_path_change(parent)
    print("Implement task guard tests passed (17 deterministic scenarios).")


if __name__ == "__main__":
    main()
