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


def cpu_identity(metadata, cpu):
    actual = metadata.get("io.pyva.cpu.variant", "")
    if (cpu and actual != cpu) or (not cpu and actual not in ("", "v1")):
        raise ValueError("CPU identity differs from selected variant")


def children(index, cpu=""):
    if cpu not in ("", "v2", "v3"):
        raise ValueError("CPU variant must be v2 or v3")
    expected = {"amd64"} if cpu else {"amd64", "arm64"}
    result = {}
    for child in index["manifests"]:
        platform = child["platform"]
        arch = platform["architecture"]
        if platform["os"] != "linux" or arch not in expected or arch in result:
            raise ValueError("index platform set differs from selected release")
        result[arch] = digest(child["digest"])
    if set(result) != expected:
        raise ValueError("incomplete platform index")
    return result


def local(root, minor, cpu=""):
    def blob(descriptor):
        expected = digest(descriptor["digest"])
        data = (root / "blobs/sha256" / expected.split(":")[1]).read_bytes()
        if "sha256:" + hashlib.sha256(data).hexdigest() != expected or len(data) != descriptor["size"]:
            raise ValueError("candidate blob differs from its descriptor")
        return data

    descriptor, = json.loads((root / "index.json").read_text())["manifests"]
    index = json.loads(blob(descriptor))
    child_digests = children(index, cpu)
    versions = set()
    configs = {}
    for child in index["manifests"]:
        arch = child["platform"]["architecture"]
        manifest = json.loads(blob(child))
        config = json.loads(blob(manifest["config"]))
        cpu_identity(config["config"]["Labels"], cpu)
        cpu_identity(manifest.get("annotations", {}), cpu)
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
    arches = ("amd64",) if cpu else ("amd64", "arm64")
    family = versions.pop() + ("-amd64-" + cpu if cpu else "")
    return [family, digest(descriptor["digest"])] + [child_digests[a] for a in arches] + [configs[a] for a in arches]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cpu", choices=("v2", "v3"), default="")
    parser.add_argument("mode", choices=("local", "remote", "loaded"))
    parser.add_argument("args", nargs="+")
    params = parser.parse_intermixed_args()
    if params.mode == "local":
        root, minor = params.args
        print(" ".join(local(Path(root), minor, params.cpu)))
    elif params.mode == "remote":
        descriptor = json.load(sys.stdin)
        expected = [digest(d) for d in params.args]
        actual = children(descriptor, params.cpu)
        arches = ("amd64",) if params.cpu else ("amd64", "arm64")
        if [digest(descriptor["digest"])] + [actual[a] for a in arches] != expected:
            raise ValueError("remote index/child digests differ from validated candidate")
    elif params.mode == "loaded":
        # Containerd-backed Docker may report a converted manifest as .Id.
        root, config_digest = params.args
        config = json.loads((Path(root) / "blobs/sha256" / digest(config_digest).split(":")[1]).read_text())
        cpu_identity(config["config"]["Labels"], params.cpu)
        loaded = json.load(sys.stdin)
        if (loaded["Os"], loaded["Architecture"], loaded["Config"], loaded["RootFS"]["Layers"]) != (
            config["os"], config["architecture"], config["config"], config["rootfs"]["diff_ids"]
        ):
            raise ValueError("loaded configuration/layer digests differ from candidate")


if __name__ == "__main__":
    main()
