#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sys
import tarfile
from pathlib import PurePosixPath


def normalized(name: str) -> str:
    while name.startswith("./"):
        name = name[2:]
    return name


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify_release_archive.py ARCHIVE", file=sys.stderr)
        return 2
    archive_path = sys.argv[1]
    with tarfile.open(archive_path, "r:gz") as archive:
        regular: dict[str, tarfile.TarInfo] = {}
        for member in archive.getmembers():
            name = normalized(member.name)
            path = PurePosixPath(name)
            if not name or path.is_absolute() or ".." in path.parts:
                print(f"[verify] unsafe archive path: {member.name}", file=sys.stderr)
                return 1
            if member.issym() or member.islnk() or member.isdev():
                print(f"[verify] unsupported archive member: {member.name}", file=sys.stderr)
                return 1
            if member.isfile():
                regular[name] = member

        manifest_member = regular.get("RELEASE-MANIFEST.sha256")
        if manifest_member is None:
            print("[verify] RELEASE-MANIFEST.sha256 is missing", file=sys.stderr)
            return 1
        manifest_handle = archive.extractfile(manifest_member)
        if manifest_handle is None:
            print("[verify] cannot read release manifest", file=sys.stderr)
            return 1
        expected: dict[str, str] = {}
        for line in manifest_handle.read().decode("utf-8").splitlines():
            digest, separator, name = line.partition("  ")
            if not separator or len(digest) != 64 or not name:
                print("[verify] malformed manifest row", file=sys.stderr)
                return 1
            expected[name] = digest

        actual_names = set(regular) - {"RELEASE-MANIFEST.sha256"}
        if actual_names != set(expected):
            missing = sorted(set(expected) - actual_names)
            extra = sorted(actual_names - set(expected))
            print(f"[verify] manifest mismatch; missing={missing}, extra={extra}", file=sys.stderr)
            return 1
        required_members = {
            "backend/server.py",
            # Both dependency manifests must ship: the installer reads them to
            # build the venv, and a missing one only surfaces at runtime as
            # "后端缺少 xxx 依赖" on the login / campus-service endpoints.
            "backend/requirements-storage.txt",
            "backend/requirements-auth.txt",
            "web/index.html",
        }
        missing_required = sorted(required_members - actual_names)
        # Either frontend layout: Flutter Web at the root, or the static
        # export with the Flutter admin console under web/admin/.
        flutter_web = "web/main.dart.js" in actual_names and "web/admin/index.html" not in actual_names
        static_web = {"web/feed.html", "web/admin/index.html", "web/admin/main.dart.js"} <= actual_names and any(
            name.startswith("web/_next/static/") for name in actual_names
        )
        if not (flutter_web or static_web):
            missing_required.append("web/main.dart.js (Flutter Web) or web/feed.html + web/_next/static/ + web/admin/ (static web)")
        if missing_required:
            print(
                f"[verify] required release files are missing: {missing_required}",
                file=sys.stderr,
            )
            return 1
        for name, digest in expected.items():
            handle = archive.extractfile(regular[name])
            if handle is None:
                print(f"[verify] cannot read {name}", file=sys.stderr)
                return 1
            actual = hashlib.sha256(handle.read()).hexdigest()
            if actual != digest:
                print(f"[verify] checksum mismatch: {name}", file=sys.stderr)
                return 1
    print("[verify] release archive passed path and checksum validation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
