#!/usr/bin/env python3

import argparse
from dataclasses import dataclass
import hashlib
from pathlib import Path
import stat
import subprocess
import sys
import tarfile
from typing import BinaryIO, Iterable, Iterator


ARCHIVE_NAME = "agentrc-pre-codex-only.tar.gz"
EXPECTED_TOP_LEVEL = {"README.md", "MANIFEST.tsv", ARCHIVE_NAME}
SUPPORTED_OBJECT_FORMATS = {"sha1": 40, "sha256": 64}


class ArchiveValidationError(Exception):
    pass


@dataclass(frozen=True)
class ManifestEntry:
    mode: str
    object_type: str
    object_id: str
    path: str


@dataclass(frozen=True)
class Manifest:
    source_commit: str
    object_format: str
    entries: dict[str, ManifestEntry]


def _validate_path(path: str, context: str) -> str:
    normalized = path.rstrip("/")
    components = normalized.split("/")
    if (
        not normalized
        or path.startswith("/")
        or any(component in {"", ".", ".."} for component in components)
    ):
        raise ArchiveValidationError(f"unsafe {context} path: {path!r}")
    return normalized


def _parse_manifest(path: Path) -> Manifest:
    lines = path.read_text().splitlines()
    if len(lines) < 4:
        raise ArchiveValidationError("manifest is incomplete")
    source_header = lines[0].split("\t", 1)
    format_header = lines[1].split("\t", 1)
    if len(source_header) != 2 or source_header[0] != "source_commit":
        raise ArchiveValidationError("manifest has no source_commit header")
    if len(format_header) != 2 or format_header[0] != "object_format":
        raise ArchiveValidationError("manifest has no object_format header")
    if lines[2] != "mode\tobject_type\tobject_id\tpath":
        raise ArchiveValidationError("manifest column header is invalid")

    source_commit = source_header[1]
    object_format = format_header[1]
    object_id_length = SUPPORTED_OBJECT_FORMATS.get(object_format)
    if object_id_length is None:
        raise ArchiveValidationError(f"unsupported Git object format: {object_format}")
    if len(source_commit) != object_id_length or any(
        character not in "0123456789abcdef" for character in source_commit
    ):
        raise ArchiveValidationError("manifest source commit is not a full object ID")

    entries: dict[str, ManifestEntry] = {}
    for line_number, line in enumerate(lines[3:], start=4):
        columns = line.split("\t", 3)
        if len(columns) != 4:
            raise ArchiveValidationError(f"invalid manifest record at line {line_number}")
        mode, object_type, object_id, entry_path = columns
        normalized = _validate_path(entry_path, "manifest")
        if normalized != entry_path:
            raise ArchiveValidationError(f"non-canonical manifest path: {entry_path!r}")
        if entry_path in entries:
            raise ArchiveValidationError(f"duplicate manifest path: {entry_path}")
        if mode not in {"100644", "100755", "120000"} or object_type != "blob":
            raise ArchiveValidationError(
                f"unsupported manifest entry: {mode} {object_type} {entry_path}"
            )
        if len(object_id) != object_id_length or any(
            character not in "0123456789abcdef" for character in object_id
        ):
            raise ArchiveValidationError(
                f"invalid object ID for manifest path: {entry_path}"
            )
        entries[entry_path] = ManifestEntry(mode, object_type, object_id, entry_path)
    return Manifest(source_commit, object_format, entries)


def _run_git(repository: Path, arguments: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        capture_output=True,
    )


def _source_entries(repository: Path, manifest: Manifest) -> dict[str, ManifestEntry]:
    format_result = _run_git(repository, ["rev-parse", "--show-object-format"])
    if format_result.returncode != 0:
        raise ArchiveValidationError("repository object format is unavailable")
    repository_format = format_result.stdout.decode().strip()
    if repository_format != manifest.object_format:
        raise ArchiveValidationError(
            "manifest object format does not match the repository object format"
        )

    commit_result = _run_git(
        repository, ["cat-file", "-e", f"{manifest.source_commit}^{{commit}}"]
    )
    if commit_result.returncode != 0:
        raise ArchiveValidationError(
            f"source commit is not available: {manifest.source_commit}"
        )

    tree_result = _run_git(repository, ["ls-tree", "-r", "-z", manifest.source_commit])
    if tree_result.returncode != 0:
        raise ArchiveValidationError("could not read source tree")
    entries: dict[str, ManifestEntry] = {}
    for record in tree_result.stdout.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode_bytes, object_type_bytes, object_id_bytes = metadata.split(b" ", 2)
        entry_path = raw_path.decode("utf-8", "surrogateescape")
        entries[entry_path] = ManifestEntry(
            mode_bytes.decode(),
            object_type_bytes.decode(),
            object_id_bytes.decode(),
            entry_path,
        )
    return entries


def _blob_id(
    object_format: str, size: int, chunks: Iterable[bytes]
) -> tuple[str, int]:
    digest = hashlib.new(object_format)
    digest.update(f"blob {size}\0".encode())
    observed_size = 0
    for chunk in chunks:
        observed_size += len(chunk)
        digest.update(chunk)
    return digest.hexdigest(), observed_size


def _file_chunks(file_object: BinaryIO) -> Iterator[bytes]:
    while chunk := file_object.read(1024 * 1024):
        yield chunk


def _validate_member(
    archive: tarfile.TarFile,
    member: tarfile.TarInfo,
    manifest: Manifest,
    seen: set[str],
) -> None:
    entry_path = _validate_path(member.name, "archive")
    if entry_path in seen:
        raise ArchiveValidationError(f"duplicate archive path: {entry_path}")
    seen.add(entry_path)

    if member.isdir():
        if member.linkname or member.size != 0:
            raise ArchiveValidationError(
                f"directory entry has a link or payload: {entry_path}"
            )
        prefix = f"{entry_path}/"
        if not any(path.startswith(prefix) for path in manifest.entries):
            raise ArchiveValidationError(f"unexpected directory entry: {entry_path}")
        return

    if member.name != entry_path:
        raise ArchiveValidationError(f"non-canonical archive path: {member.name!r}")
    if not member.isreg() and not member.issym():
        raise ArchiveValidationError(
            f"unsupported archive member type for {entry_path}: {member.type!r}"
        )

    expected = manifest.entries.get(entry_path)
    if expected is None:
        raise ArchiveValidationError(f"unmanifested archive entry: {entry_path}")

    if member.isreg():
        observed_mode = "100755" if member.mode & 0o111 else "100644"
        if observed_mode != expected.mode:
            raise ArchiveValidationError(
                f"mode mismatch for {entry_path}: {observed_mode} != {expected.mode}"
            )
        file_object = archive.extractfile(member)
        if file_object is None:
            raise ArchiveValidationError(f"regular file has no payload: {entry_path}")
        object_id, observed_size = _blob_id(
            manifest.object_format, member.size, _file_chunks(file_object)
        )
        if observed_size != member.size:
            raise ArchiveValidationError(f"payload size mismatch for {entry_path}")
    elif member.issym():
        if expected.mode != "120000":
            raise ArchiveValidationError(
                f"mode mismatch for {entry_path}: 120000 != {expected.mode}"
            )
        if member.size != 0:
            raise ArchiveValidationError(f"symlink has a payload: {entry_path}")
        target = member.linkname.encode("utf-8", "surrogateescape")
        object_id, observed_size = _blob_id(
            manifest.object_format, len(target), (target,)
        )
        if observed_size != len(target):
            raise ArchiveValidationError(f"symlink size mismatch for {entry_path}")
        if object_id != expected.object_id:
            raise ArchiveValidationError(f"symlink target mismatch for {entry_path}")
    if object_id != expected.object_id:
        raise ArchiveValidationError(
            f"blob ID mismatch for {entry_path}: {object_id} != {expected.object_id}"
        )


def _validate_archive(archive_path: Path, manifest: Manifest) -> None:
    seen: set[str] = set()
    try:
        with tarfile.open(archive_path, "r|gz") as archive:
            for member in archive:
                _validate_member(archive, member, manifest, seen)
    except (OSError, tarfile.TarError) as error:
        raise ArchiveValidationError(f"could not stream archive: {error}") from error
    missing = sorted(set(manifest.entries) - seen)
    if missing:
        raise ArchiveValidationError(
            f"missing archive entries: {', '.join(missing[:5])}"
        )


def _validate_container(archive_directory: Path) -> None:
    actual = {path.name for path in archive_directory.iterdir()}
    if actual != EXPECTED_TOP_LEVEL:
        raise ArchiveValidationError(
            f"archive directory contents differ: {sorted(actual)}"
        )
    for name in EXPECTED_TOP_LEVEL:
        path = archive_directory / name
        path_mode = path.lstat().st_mode
        if not stat.S_ISREG(path_mode):
            raise ArchiveValidationError(f"archive metadata path is not regular: {path}")
        if path_mode & 0o111:
            raise ArchiveValidationError(f"archive metadata path is executable: {path}")


def validate_archive(archive_directory: Path, repository: Path) -> Manifest:
    _validate_container(archive_directory)
    manifest = _parse_manifest(archive_directory / "MANIFEST.tsv")
    source_entries = _source_entries(repository, manifest)
    if manifest.entries != source_entries:
        raise ArchiveValidationError("manifest does not match source tree")
    if manifest.source_commit not in (archive_directory / "README.md").read_text():
        raise ArchiveValidationError("README does not identify the manifest source commit")
    _validate_archive(archive_directory / ARCHIVE_NAME, manifest)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive_directory", type=Path)
    parser.add_argument("--repository", type=Path, default=Path.cwd())
    arguments = parser.parse_args()
    try:
        manifest = validate_archive(arguments.archive_directory, arguments.repository)
    except ArchiveValidationError as error:
        print(f"legacy archive validation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
    print(
        "legacy archive validation passed: "
        f"{len(manifest.entries)} entries from {manifest.source_commit}"
    )


if __name__ == "__main__":
    main()
