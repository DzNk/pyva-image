"""Offline OCI installer-policy and blob-integrity regressions."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
from unittest.mock import patch

from image_manifest import JAVA_MANIFEST, check_layer, local, packaging_path


java_tags = {major: "_".join(entry["version"].split("+"))
             for major, entry in json.loads(JAVA_MANIFEST.read_text()).items()}


def tar(names):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w") as archive:
        for name in names:
            member = tarfile.TarInfo(name)
            member.size = 2
            archive.addfile(member, io.BytesIO(b"ok"))
    return stream.getvalue()


def rejected(operation):
    try:
        operation()
    except (ValueError, tarfile.TarError):
        pass
    else:
        raise AssertionError("invalid candidate accepted")


def layout(root, minor, layers, arches=("amd64", "arm64"), annotation=None, label=None, java="21"):
    blobs = root / "blobs/sha256"
    blobs.mkdir(exist_ok=True, parents=True)

    def save(data):
        raw = data if isinstance(data, bytes) else json.dumps(data).encode()
        sha = hashlib.sha256(raw).hexdigest()
        (blobs / sha).write_bytes(raw)
        return {"digest": "sha256:" + sha, "size": len(raw)}

    children = []
    for arch in arches:
        descriptors = [dict(save(data), mediaType="application/vnd.oci.image.layer.v1.tar" + ("+gzip" if data.startswith(b"\x1f\x8b") else "")) for data in layers]
        metadata = {"org.opencontainers.image.version": minor + f".99-java{java}-debian13"}
        if label is not None:
            metadata["io.pyva.cpu.variant"] = label
        config = save({"os": "linux", "architecture": arch, "config": {
            "Labels": metadata},
            "rootfs": {"type": "layers", "diff_ids": ["sha256:" + hashlib.sha256(gzip.decompress(data) if data.startswith(b"\x1f\x8b") else data).hexdigest() for data in layers]}})
        config["mediaType"] = "application/vnd.oci.image.config.v1+json"
        annotations = {"io.pyva.cpu.variant": annotation} if annotation is not None else {}
        child = save({"schemaVersion": 2, "config": config, "layers": descriptors, "annotations": annotations})
        child["mediaType"] = "application/vnd.oci.image.manifest.v1+json"
        child["platform"] = {"os": "linux", "architecture": arch}
        children.append(child)
    index = dict(save({"schemaVersion": 2, "manifests": children}), mediaType="application/vnd.oci.image.index.v1+json")
    (root / "index.json").write_text(json.dumps({"schemaVersion": 2, "manifests": [index]}))


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for minor in ("3.13", "3.14"):
        stdlib = "usr/lib/python" + minor + "/"
        allowed = ["usr/bin/python" + minor, stdlib + "ssl.py", stdlib + "venv/__init__.py"] + [
            stdlib + "site-packages/" + path for path in (
                "cffi/setuptools_ext.py", "msgpack/__init__.py", "pipelines/__init__.py",
                "setuptools_scm/__init__.py", "JPype1-1.7.1.dist-info/METADATA",
                "my-pip-tool-1.dist-info/METADATA",
            )]
        for name in allowed:
            assert not packaging_path(name), name
        good = tar(allowed)
        for data in (good, gzip.compress(good, mtime=0)):
            check_layer(data)
            layout(root, minor, [data])
            assert local(root, minor)[0] == f"{minor}.99-java{java_tags['21']}-debian13"
        forbidden = ["usr/bin/pip", "usr/bin/pip3", "usr/bin/pip" + minor,
                     stdlib + "ensurepip/_bundled/pip-26.2.1-py3-none-any.whl"] + [
            stdlib + "site-packages/" + path for path in (
                "pip/__init__.py", "pip/__pycache__/__init__.pyc",
                "pip/_vendor/msgpack/__init__.py", "pip/_vendor/pkg_resources/__init__.py",
                "pip-26.2.1.dist-info/METADATA", "setuptools/__init__.py",
                "setuptools-70.3.0.dist-info/METADATA", "pkg_resources/__init__.py",
                "_distutils_hack/__init__.py", "distutils-precedence.pth",
            )]
        layout(root, minor, [good], java="25")
        assert local(root, minor, java="25")[0] == f"{minor}.99-java{java_tags['25']}-debian13"
        rejected(lambda: local(root, minor))
        for name in forbidden:
            assert packaging_path("./" + name), name
            for data in (tar([name]), gzip.compress(tar([name]), mtime=0)):
                rejected(lambda: check_layer(data))
                layout(root, minor, [data, tar([stdlib + "site-packages/.wh.pip"])])
                rejected(lambda: local(root, minor))
        for name in ("/usr/bin/pip", "usr/../usr/bin/pip", "usr\\bin\\pip"):
            rejected(lambda: check_layer(tar([name])))
        layout(root, minor, [])
        rejected(lambda: local(root, minor))
        layout(root, minor, [b"not a tar archive"])
        rejected(lambda: local(root, minor))
        layout(root, minor, [good])
        (root / "blobs/sha256" / hashlib.sha256(good).hexdigest()).write_bytes(b"corrupted")
        rejected(lambda: local(root, minor))
        for kwargs in ({"arches": ("amd64",)}, {"arches": ()}, {"arches": ("amd64", "amd64")},
                       {"label": "v2"}, {"label": "v3"}, {"annotation": "v2"}, {"annotation": "v3"}):
            layout(root, minor, [good], **kwargs)
            rejected(lambda: local(root, minor))
        layout(root, minor, [good], label="v1", annotation="v1")
        assert local(root, minor)[0] == f"{minor}.99-java{java_tags['21']}-debian13"
        layout(root, minor, [good], java="25")
        pin = root / "java_runtime.json"
        with patch("image_manifest.JAVA_MANIFEST", pin):
            pin.write_text('{"25": {"version": "25.0.5.1+10"}}')
            assert local(root, minor, java="25")[0] == f"{minor}.99-java25.0.5.1_10-debian13"
            for invalid in ("21.0.13.1+2", "25.0.5.1-ea+10"):
                pin.write_text(json.dumps({"25": {"version": invalid}}))
                rejected(lambda: local(root, minor, java="25"))
print("OCI policy passed: every layer, gzip, hidden installers, retained dependencies and integrity")
