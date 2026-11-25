"""Refresh pinned Eclipse Temurin JRE archives from the official releases."""

import json
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import quote
from urllib.request import Request, urlopen


MANIFEST = Path(__file__).with_name("java_runtime.json")
ARCHITECTURES = {"amd64": "x64", "arm64": "aarch64"}
MINIMUM = {"21": (21, 0, 13, 1), "25": (25, 0, 5, 1)}
VERSION = re.compile(r"([1-9][0-9]*(?:\.(?:0|[1-9][0-9]*))+)[+]([1-9][0-9]*)")


def version_key(version):
    match = VERSION.fullmatch(version)
    if not match:
        raise ValueError(f"invalid stable Java version: {version!r}")
    numbers = tuple(map(int, match[1].split(".")))
    return numbers, int(match[2])


def verify_runtime(major, properties):
    detected = properties["java.runtime.version"]
    version = detected.removesuffix("-LTS")
    minimum = ".".join(map(str, MINIMUM[major]))
    expected = json.loads(MANIFEST.read_text())[major]["version"]
    if (properties["java.vendor"] != "Eclipse Adoptium"
            or version != expected or version_key(version)[0] < MINIMUM[major]):
        raise ValueError(
            f"CVE-2026-114938: expected Temurin {expected} (minimum {minimum}), "
            f"found {properties['java.vendor']} {detected}"
        )


def release_entry(major, release):
    tag = release["tag_name"]
    if release["draft"] or release["prerelease"] or not tag.startswith("jdk-"):
        raise ValueError(f"Temurin {major} is not a stable release: {tag}")
    version = tag.removeprefix("jdk-")
    numbers, _ = version_key(version)
    if numbers[0] != int(major) or numbers < MINIMUM[major]:
        raise ValueError(f"Temurin {major} release {version} is below its required version")

    downloads = f"https://github.com/adoptium/temurin{major}-binaries/releases/download"
    archives = {}
    for arch, upstream_arch in ARCHITECTURES.items():
        name = f"OpenJDK{major}U-jre_{upstream_arch}_linux_hotspot_{version.replace('+', '_')}.tar.gz"
        matches = [asset for asset in release["assets"] if asset["name"] == name]
        if len(matches) != 1 or matches[0]["state"] != "uploaded":
            raise ValueError(f"expected one uploaded Temurin asset: {name}")
        digest = matches[0].get("digest") or ""
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise ValueError(f"missing or invalid SHA-256 for {name}")
        archives[arch] = {
            "url": f"{downloads}/{quote(tag, safe='')}/{name}",
            "sha256": digest.removeprefix("sha256:"),
        }
    return {"version": version, "archives": archives}


def latest_release(major):
    headers = {"Accept": "application/vnd.github+json"}
    if token := os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {token}"
    request = Request(
        f"https://api.github.com/repos/adoptium/temurin{major}-binaries/releases/latest",
        headers=headers,
    )
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def refresh(destination=MANIFEST, fetch=latest_release):
    saved = json.loads(destination.read_text())
    updated = {}
    for major in MINIMUM:
        current = saved[major]
        candidate = release_entry(major, fetch(major))
        current_version = version_key(current["version"])
        candidate_version = version_key(candidate["version"])
        if candidate_version < current_version:
            raise ValueError(f"Temurin {major} upstream version regressed")
        if candidate_version == current_version and candidate != current:
            raise ValueError(f"Temurin {major} archives changed for the saved release")
        updated[major] = candidate

    if updated != saved:
        with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as temporary:
            staged = Path(temporary.name)
        try:
            staged.write_text(json.dumps(updated, indent=2) + "\n")
            staged.chmod(0o644)
            staged.replace(destination)
        finally:
            staged.unlink(missing_ok=True)
    return updated


if __name__ == "__main__":
    try:
        versions = refresh()
    except (KeyError, TypeError, ValueError, OSError) as error:
        raise SystemExit(f"Java update failed: {error}") from error
    for major, entry in versions.items():
        print(f"Temurin {major}: {entry['version']}")
