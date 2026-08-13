#!/usr/bin/env python3

from collections.abc import Callable
import io
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile


REPOSITORY = Path(__file__).resolve().parent.parent
SOURCE_ARCHIVE = REPOSITORY / "archive" / "legacy-harnesses"
VALIDATOR = REPOSITORY / "scripts" / "validate-legacy-archive.py"
ARCHIVE_NAME = "agentrc-pre-codex-only.tar.gz"


Transform = Callable[
    [int, tarfile.TarInfo, bytes | None],
    tuple[tarfile.TarInfo, bytes | None] | None,
]


def _run_validator(archive_directory: Path, expected_error: str | None = None) -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(VALIDATOR),
            str(archive_directory),
            "--repository",
            str(REPOSITORY),
        ],
        capture_output=True,
        text=True,
    )
    if expected_error is None:
        if result.returncode != 0:
            raise AssertionError(result.stderr)
        return
    if result.returncode == 0:
        raise AssertionError(f"validator accepted corruption: {expected_error}")
    if expected_error not in result.stderr:
        raise AssertionError(
            f"expected {expected_error!r} in validator error, got {result.stderr!r}"
        )


def _fixture_directory(root: Path, name: str) -> Path:
    destination = root / name
    shutil.copytree(SOURCE_ARCHIVE, destination)
    return destination


def _rewrite_archive(
    archive_directory: Path,
    transform: Transform,
) -> None:
    archive_path = archive_directory / ARCHIVE_NAME
    replacement_path = archive_directory / f"{ARCHIVE_NAME}.replacement"
    with tarfile.open(archive_path, "r:gz") as source, tarfile.open(
        replacement_path, "w:gz"
    ) as destination:
        for index, member in enumerate(source):
            payload = source.extractfile(member).read() if member.isreg() else None
            transformed = transform(index, member, payload)
            if transformed is None:
                continue
            transformed_member, transformed_payload = transformed
            destination.addfile(
                transformed_member,
                io.BytesIO(transformed_payload)
                if transformed_payload is not None
                else None,
            )
    replacement_path.replace(archive_path)


def _first_regular_payload(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.isreg() and member.name == ".gitignore":
        corrupted = b"corrupt\n" + (payload or b"")
        member.size = len(corrupted)
        return member, corrupted
    return member, payload


def _executable_mode(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.isreg() and member.name == "install.sh":
        member.mode = 0o664
    return member, payload


def _symlink_target(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.issym() and member.name == "CLAUDE.md":
        member.linkname = "wrong-target"
    return member, payload


def _absolute_path(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.name == ".gitignore":
        member.name = "/.gitignore"
    return member, payload


def _traversal_path(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.name == ".gitignore":
        member.name = "../.gitignore"
    return member, payload


def _hard_link(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.isreg() and member.name == ".gitignore":
        member.type = tarfile.LNKTYPE
        member.linkname = "AGENTS.md"
        member.size = 0
        return member, None
    return member, payload


def _unexpected_directory(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None]:
    if member.name == ".gitignore":
        member.name = "unexpected/"
        member.type = tarfile.DIRTYPE
        member.mode = 0o775
        member.size = 0
        return member, None
    return member, payload


def _missing_entry(
    index: int, member: tarfile.TarInfo, payload: bytes | None
) -> tuple[tarfile.TarInfo, bytes | None] | None:
    if member.name == ".gitignore":
        return None
    return member, payload


def _append_duplicate(archive_directory: Path) -> None:
    archive_path = archive_directory / ARCHIVE_NAME
    replacement_path = archive_directory / f"{ARCHIVE_NAME}.replacement"
    with tarfile.open(archive_path, "r:gz") as source:
        members = []
        for member in source:
            payload = source.extractfile(member).read() if member.isreg() else None
            members.append((member, payload))
    with tarfile.open(replacement_path, "w:gz") as destination:
        for member, payload in members:
            destination.addfile(member, io.BytesIO(payload) if payload is not None else None)
        member, payload = next(item for item in members if item[0].name == ".gitignore")
        destination.addfile(member, io.BytesIO(payload))
    replacement_path.replace(archive_path)


def _replace_manifest_value(path: Path, old: str, new: str) -> None:
    content = path.read_text()
    if old not in content:
        raise AssertionError(f"fixture value not found: {old}")
    path.write_text(content.replace(old, new, 1))


def main() -> None:
    _run_validator(SOURCE_ARCHIVE)
    cases = (
        ("payload", _first_regular_payload, "blob ID mismatch"),
        ("executable-mode", _executable_mode, "mode mismatch"),
        ("symlink-target", _symlink_target, "symlink target mismatch"),
        ("absolute-path", _absolute_path, "unsafe archive path"),
        ("traversal-path", _traversal_path, "unsafe archive path"),
        ("hard-link", _hard_link, "unsupported archive member type"),
        ("unexpected-directory", _unexpected_directory, "unexpected directory entry"),
        ("missing-entry", _missing_entry, "missing archive entries"),
    )
    with tempfile.TemporaryDirectory() as temporary_directory:
        root = Path(temporary_directory)
        for name, transform, expected_error in cases:
            directory = _fixture_directory(root, name)
            _rewrite_archive(directory, transform)
            _run_validator(directory, expected_error)

        directory = _fixture_directory(root, "duplicate-name")
        _append_duplicate(directory)
        _run_validator(directory, "duplicate archive path")

        directory = _fixture_directory(root, "manifest-object-id")
        manifest = directory / "MANIFEST.tsv"
        lines = manifest.read_text().splitlines()
        first_record = lines[3].split("\t")
        original_object_id = first_record[2]
        _replace_manifest_value(manifest, original_object_id, "0" * len(original_object_id))
        _run_validator(directory, "manifest does not match source tree")

        directory = _fixture_directory(root, "source-commit")
        manifest = directory / "MANIFEST.tsv"
        source_commit = manifest.read_text().splitlines()[0].split("\t", 1)[1]
        _replace_manifest_value(manifest, source_commit, "0" * len(source_commit))
        _run_validator(directory, "source commit is not available")

    print(f"legacy archive validation tests passed ({len(cases) + 3} corruptions)")


if __name__ == "__main__":
    main()
