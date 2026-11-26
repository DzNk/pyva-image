#!/usr/bin/env python3
"""Read native OCI layouts and verify Docker buildx registry descriptors."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import sys
import tarfile

from update_java_manifest import MANIFEST as JAVA_MANIFEST, version_key


ARCHES = ("amd64", "arm64")


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


def check_baseline(metadata):
    if metadata.get("io.pyva.cpu.variant", "") not in ("", "v1"):
        raise ValueError("optimized image cannot substitute baseline")


def children(index):
    result = {}
    for child in index["manifests"]:
        platform = child["platform"]
        arch = platform["architecture"]
        if platform["os"] != "linux" or arch not in ARCHES or arch in result:
            raise ValueError("index platform set differs from selected release")
        result[arch] = digest(child["digest"])
    if set(result) != set(ARCHES):
        raise ValueError("incomplete platform index")
    return result


def local(root, minor, java="21"):
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
        labels = config["config"]["Labels"]
        check_baseline(labels)
        check_baseline(manifest.get("annotations", {}))
        if not manifest["layers"]:
            raise ValueError("candidate has no filesystem layers")
        for layer in manifest["layers"]:
            check_layer(blob(layer))
        if (config["os"], config["architecture"]) != ("linux", arch):
            raise ValueError("config platform differs from index")
        version = re.fullmatch(rf"({re.escape(minor)}\.[0-9]+)-java{re.escape(java)}-debian13",
                               labels["org.opencontainers.image.version"])
        if not version:
            raise ValueError("unexpected runtime identity")
        versions.add(version[1])
        configs[arch] = digest(manifest["config"]["digest"])
    if len(versions) != 1:
        raise ValueError("platform Python identities differ")
    java_version = json.loads(JAVA_MANIFEST.read_text())[java]["version"]
    numbers, _ = version_key(java_version)
    if numbers[0] != int(java):
        raise ValueError("Temurin pin does not match the selected Java major")
    family = f"{versions.pop()}-java{java_version.replace('+', '_')}-debian13"
    return [family, digest(descriptor["digest"])] + [child_digests[a] for a in ARCHES] + [configs[a] for a in ARCHES]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--java", choices=("21", "25"), default="21")
    parser.add_argument("mode", choices=("local", "remote", "loaded"))
    parser.add_argument("args", nargs="+")
    params = parser.parse_intermixed_args()
    if params.mode == "local":
        root, minor = params.args
        print(" ".join(local(Path(root), minor, params.java)))
    elif params.mode == "remote":
        descriptor = json.load(sys.stdin)
        expected = [digest(d) for d in params.args]
        actual = children(descriptor)
        if [digest(descriptor["digest"])] + [actual[a] for a in ARCHES] != expected:
            raise ValueError("remote index/child digests differ from validated candidate")
    elif params.mode == "loaded":
        # Containerd-backed Docker may report a converted manifest as .Id.
        root, config_digest = params.args
        config = json.loads((Path(root) / "blobs/sha256" / digest(config_digest).split(":")[1]).read_text())
        check_baseline(config["config"]["Labels"])
        loaded = json.load(sys.stdin)
        if (loaded["Os"], loaded["Architecture"], loaded["Config"], loaded["RootFS"]["Layers"]) != (
            config["os"], config["architecture"], config["config"], config["rootfs"]["diff_ids"]
        ):
            raise ValueError("loaded configuration/layer digests differ from candidate")


if __name__ == "__main__":
    main()
