"""Rebase a pinned Temurin tarball to its image path without extracting it."""

import gzip
import posixpath
import sys
import tarfile


def package(source, output, java_home):
    with tarfile.open(source, "r:gz") as archive:
        entries = {}
        for entry in archive:
            parts = entry.name.split("/")
            if not all(part and part not in (".", "..") for part in parts) or entry.name in entries:
                raise ValueError(f"invalid Temurin archive path: {entry.name!r}")
            if not (entry.isfile() or entry.isdir() or entry.issym() or entry.islnk()):
                raise ValueError(f"unexpected Temurin archive member: {entry.name!r}")
            entries[entry.name] = entry

        root, = {name.split("/", 1)[0] for name in entries}
        if root in entries and not entries[root].isdir():
            raise ValueError("invalid Temurin archive root")
        for required in ("bin/java", "lib/server/libjvm.so", "release", "lib/security/cacerts"):
            if not entries[f"{root}/{required}"].isfile():
                raise ValueError(f"invalid Temurin file: {required}")

        # The JRE uses relative license symlinks. Keep their targets inside the JRE.
        for entry in entries.values():
            parent = posixpath.dirname(entry.name)
            while parent:
                if parent in entries and not entries[parent].isdir():
                    raise ValueError(f"invalid Temurin archive parent: {parent!r}")
                parent = posixpath.dirname(parent)
            if entry.issym():
                target = posixpath.normpath(posixpath.join(posixpath.dirname(entry.name), entry.linkname))
            elif entry.islnk():
                target = entry.linkname
            else:
                continue
            if not target.startswith(root + "/") or target not in entries or not entries[target].isfile():
                raise ValueError(f"invalid Temurin archive link: {entry.name!r} -> {entry.linkname!r}")

        with open(output, "wb") as file, gzip.GzipFile(filename="", fileobj=file, mode="wb", mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w|") as layer:
                for entry in entries.values():
                    name = java_home + entry.name[len(root):]
                    normalized = tarfile.TarInfo(name)
                    normalized.type = entry.type
                    normalized.mode = entry.mode & 0o777
                    normalized.size = entry.size
                    normalized.linkname = java_home + entry.linkname[len(root):] if entry.islnk() else entry.linkname
                    layer.addfile(normalized, archive.extractfile(entry) if entry.isfile() else None)


if __name__ == "__main__":
    package(*sys.argv[1:])
