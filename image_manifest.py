#!/usr/bin/env python3
"""Read native OCI layouts and verify Docker buildx registry descriptors."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import sys
import tarfile


def packaging_path(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name:
        raise ValueError("invalid layer member path: " + name)
    name = str(path)
    if re.fullmatch(r"usr/bin/pip(?:3(?:\.(?:13|14))?)?", name):
        return True
    match = re.fullmatch(r"usr/lib/python3\.(?:13|14)/(.*)", name)
    if not match:
        return False
    relative = match[1]
    if relative.split("/", 1)[0] == "ensurepip":
        return True
    if relative.startswith("site-packages/"):
        package = relative.split("/", 2)[1]
        return package in {"pip", "setuptools", "pkg_resources", "_distutils_hack", "distutils-precedence.pth"} or bool(
            re.fullmatch(r"(?:pip|setuptools)-[^/]+\.dist-info", package)
        )
    return False


def check_layer(data):
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as archive:
        for member in archive:
            if packaging_path(member.name):
                raise ValueError("installer payload in base layer: " + member.name)


def digest(value):
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", value):
        raise ValueError("invalid SHA-256 digest")
    return value


def children(index):
    result = {}
    for child in index["manifests"]:
        platform = child["platform"]
        arch = platform["architecture"]
        if platform["os"] != "linux" or arch not in ("amd64", "arm64") or arch in result:
            raise ValueError("index must contain exactly linux/amd64 and linux/arm64")
        result[arch] = digest(child["digest"])
    if set(result) != {"amd64", "arm64"}:
        raise ValueError("incomplete platform index")
    return result


def local(root, minor):
    def blob(descriptor):
        expected = digest(descriptor["digest"])
        data = (root / "blobs/sha256" / expected.split(":")[1]).read_bytes()
        if "sha256:" + hashlib.sha256(data).hexdigest() != expected or len(data) != descriptor["size"]:
            raise ValueError("candidate blob differs from its descriptor")
        return data

    descriptor, = json.loads((root / "index.json").read_text())["manifests"]
    index = json.loads(blob(descriptor))
    child_digests = children(index)
    versions = set()
    configs = {}
    for child in index["manifests"]:
        arch = child["platform"]["architecture"]
        manifest = json.loads(blob(child))
        config = json.loads(blob(manifest["config"]))
        if not manifest["layers"]:
            raise ValueError("candidate has no filesystem layers")
        for layer in manifest["layers"]:
            check_layer(blob(layer))
        if (config["os"], config["architecture"]) != ("linux", arch):
            raise ValueError("config platform differs from index")
        version = config["config"]["Labels"]["org.opencontainers.image.version"]
        if not re.fullmatch(re.escape(minor) + r"\.[0-9]+-java21-debian13", version):
            raise ValueError("unexpected runtime identity")
        versions.add(version)
        configs[arch] = digest(manifest["config"]["digest"])
    if len(versions) != 1:
        raise ValueError("platform Python identities differ")
    return [versions.pop(), digest(descriptor["digest"])] + [child_digests[a] for a in ("amd64", "arm64")] + [configs[a] for a in ("amd64", "arm64")]


def main():
    if sys.argv[1] == "local":
        print(" ".join(local(Path(sys.argv[2]), sys.argv[3])))
    elif sys.argv[1] == "remote":
        descriptor = json.load(sys.stdin)
        expected = [digest(d) for d in sys.argv[2:]]
        actual = children(descriptor)
        if [digest(descriptor["digest"]), actual["amd64"], actual["arm64"]] != expected:
            raise ValueError("remote index/child digests differ from validated candidate")
    elif sys.argv[1] == "loaded":
        # Containerd-backed Docker may report a converted manifest as .Id.
        config = json.loads((Path(sys.argv[2]) / "blobs/sha256" / digest(sys.argv[3]).split(":")[1]).read_text())
        loaded = json.load(sys.stdin)
        if (loaded["Os"], loaded["Architecture"], loaded["Config"], loaded["RootFS"]["Layers"]) != (
            config["os"], config["architecture"], config["config"], config["rootfs"]["diff_ids"]
        ):
            raise ValueError("loaded configuration/layer digests differ from candidate")
    else:
        raise ValueError("expected local, remote or loaded mode")


if __name__ == "__main__":
    main()
