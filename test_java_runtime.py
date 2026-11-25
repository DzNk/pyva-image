"""Offline Temurin input, version policy and archive packaging checks."""

import io
import json
from pathlib import Path
import tarfile
import tempfile

from package_temurin import package
from update_java_manifest import ARCHITECTURES, MANIFEST, refresh, verify_runtime


def upstream(major, version, checksums):
    return {
        "tag_name": "jdk-" + version,
        "draft": False,
        "prerelease": False,
        "assets": [
            {
                "name": f"OpenJDK{major}U-jre_{cpu}_linux_hotspot_{version.replace('+', '_')}.tar.gz",
                "state": "uploaded",
                "digest": "sha256:" + checksums[arch],
            }
            for arch, cpu in ARCHITECTURES.items()
        ],
    }


saved = json.loads(MANIFEST.read_text())
releases = {
    major: upstream(major, entry["version"], {arch: data["sha256"] for arch, data in entry["archives"].items()})
    for major, entry in saved.items()
}
with tempfile.TemporaryDirectory() as directory:
    destination = Path(directory) / "java_runtime.json"
    original = MANIFEST.read_text()
    destination.write_text(original)
    assert refresh(destination, releases.__getitem__) == saved
    changed = upstream("25", "25.0.5.1+10", dict.fromkeys(ARCHITECTURES, "a" * 64))
    broken_digest = upstream("25", "25.0.5.1+10", dict.fromkeys(ARCHITECTURES, "bad"))
    for invalid in (
        {**changed, "assets": changed["assets"][:1]},
        {**changed, "prerelease": True},
        broken_digest,
        upstream("25", "25.0.5+99", dict.fromkeys(ARCHITECTURES, "a" * 64)),
        upstream("25", "25.0.5.1+1", dict.fromkeys(ARCHITECTURES, "a" * 64)),
        upstream("25", "25.0.5.1+2", dict.fromkeys(ARCHITECTURES, "a" * 64)),
    ):
        try:
            refresh(destination, {**releases, "25": invalid}.__getitem__)
        except ValueError:
            assert destination.read_text() == original
        else:
            raise AssertionError(f"accepted invalid Temurin release: {invalid}")
    assert refresh(destination, {**releases, "25": changed}.__getitem__)["25"]["version"] == "25.0.5.1+10"

    archive = Path(directory) / "fixture.tar.gz"
    output = Path(directory) / "layer.tar.gz"
    java_home = "usr/lib/jvm/java-21-openjdk-arm64"
    for link_target in ("../release", "../../outside"):
        with tarfile.open(archive, "w:gz") as source:
            for name in ("bin/java", "lib/server/libjvm.so", "release", "lib/security/cacerts"):
                member = tarfile.TarInfo(f"jre/{name}")
                member.mode = 0o755 if name == "bin/java" else 0o644
                member.uid, member.gid, member.mtime = 123, 456, 789
                member.size = 1
                source.addfile(member, io.BytesIO(b"x"))
            member = tarfile.TarInfo("jre/legal/license")
            member.type = tarfile.SYMTYPE
            member.linkname = link_target
            source.addfile(member)
        if link_target == "../release":
            package(archive, output, java_home)
            first = output.read_bytes()
            package(archive, output, java_home)
            assert output.read_bytes() == first
            with tarfile.open(output) as layer:
                java = layer.getmember(java_home + "/bin/java")
                assert (java.mode, java.uid, java.gid, java.mtime) == (0o755, 0, 0, 0)
                assert layer.getmember(java_home + "/legal/license").linkname == "../release"
        else:
            try:
                package(archive, output, java_home)
            except ValueError:
                assert output.read_bytes() == first
            else:
                raise AssertionError("accepted a link escaping the JRE")

for major, entry in saved.items():
    version, build = entry["version"].split("+")
    vendor = "Eclipse Adoptium"
    verify_runtime(major, {"java.runtime.version": entry["version"] + "-LTS", "java.vendor": vendor})
    for detected, detected_vendor in (
        (version.rsplit(".", 1)[0] + "+99", vendor),
        (version + "-ea+" + build, vendor),
        (version + "+99", vendor),
        ("unparseable", vendor),
        (entry["version"], "Other vendor"),
    ):
        try:
            verify_runtime(major, {"java.runtime.version": detected, "java.vendor": detected_vendor})
        except ValueError as error:
            assert "CVE-2026-114938" in str(error)
        else:
            raise AssertionError(f"accepted the wrong runtime: {detected} / {detected_vendor}")

print("Temurin manifest, version policy and archive packaging passed")
