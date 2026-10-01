"""python3 test_python_manifest.py [--bazel]; default checks require no network."""

import ast
import pathlib
import re
import subprocess
import sys
import tempfile
from unittest.mock import patch

from update_python_manifest import manifest, refresh, render


tag = "20260929"


def record(version, target="x86_64-unknown-linux-gnu", flavor="install_only_stripped", sha="a" * 64):
    return f"{sha}  cpython-{version}+{tag}-{target}-{flavor}.tar.gz"


# Synthetic patches test numeric ordering; they are not claimed upstream releases.
checksums = "\n".join([
    record("3.13.15"), record("3.14.9"), record("3.14.10"),
    record("3.14.10"), record("3.14.11rc1"),
    record("3.14.11", "aarch64-unknown-linux-gnu"),
    record("3.14.11", "x86_64-unknown-linux-musl"),
    record("3.14.11", "x86_64_v3-unknown-linux-gnu"),
    record("3.14.11", "x86_64-unknown-linux-gnu-freethreaded"),
    record("3.14.10", flavor="install_only", sha="b" * 64),
])
selected = manifest(tag, checksums)
assert [v for v, _, _ in selected] == ["3.13.15", "3.14.10"]
assert manifest(tag, "\n".join(reversed(checksums.splitlines()))) == selected
assert all(f"/download/{tag}/" in url for _, url, _ in selected)
assert all(url.endswith("-install_only_stripped.tar.gz") for _, url, _ in selected)
contents = render(selected)
assert contents == render(manifest(tag, checksums))
assert 'minor_mapping = {\n    "3.13": "3.13.15",\n    "3.14": "3.14.10",\n}' in contents
assert "available_python_versions" not in contents
assert contents.count("python.single_version_platform_override(") == 2
assert 'python.toolchain(python_version = "3.13")' in contents
assert 'python.toolchain(python_version = "3.14")' in contents
for version, url, sha in selected:
    assert f'python_version = "{version}"' in contents
    assert f'urls = ["{url}"]' in contents and f'sha256 = "{sha}"' in contents

with tempfile.TemporaryDirectory() as directory:
    destination = pathlib.Path(directory) / "python_runtimes.MODULE.bazel"
    assert refresh(tag, checksums, destination) == contents
    assert destination.read_text() == contents
    for release_tag, data in [
        (tag, record("3.13.15")), ("../bad", checksums), (None, checksums),
        (tag, checksums + "\n" + record("3.14.10", sha="b" * 64)),
        (tag, checksums + "\n" + record("3.14.11", sha="bad")),
        (tag, checksums + "\n" + record("3.14.11").split()[-1]),
        (tag, record("3.13.15") + "\n" + record("3.14.10", flavor="install_only")),
        (tag, checksums + "\n" + record("3.14.11", flavor="install_only")),
        (tag, record("3.13.15") + "\n" + record("3.14.11rc1")),
        (tag, record("3.13.15") + "\n" + record("3.14.10", "aarch64-unknown-linux-gnu")),
    ]:
        try:
            refresh(release_tag, data, destination)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid or conflicting input was accepted")
        assert destination.read_text() == contents
        assert list(pathlib.Path(directory).iterdir()) == [destination]
    with patch.object(pathlib.Path, "replace", side_effect=OSError("test write failure")):
        try:
            refresh(tag, checksums, destination)
        except OSError:
            pass
        else:
            raise AssertionError("write failure was swallowed")
    assert destination.read_text() == contents
    assert list(pathlib.Path(directory).iterdir()) == [destination]
print("Astral selection, exact overrides and atomic refresh checks passed")

if sys.argv[1:] == ["--bazel"]:
    root = pathlib.Path(__file__).resolve().parent
    dependency = re.search(r'bazel_dep\(name = "rules_python", version = "[^"]+"\)',
                           (root / "MODULE.bazel").read_text()).group()
    # Both patches exist below the built-in latest versions.
    # Synthetic saved metadata overrides URL/hash; show_repo downloads no interpreter.
    saved = manifest(tag, "\n".join([
        record("3.13.12"), record("3.14.3"),
        record("3.13.12", flavor="install_only", sha="b" * 64),
        record("3.14.3", flavor="install_only", sha="b" * 64),
    ]))
    with tempfile.TemporaryDirectory(prefix="pyva-catalog-check-") as directory:
        project = pathlib.Path(directory)
        (project / ".bazelversion").write_text((root / ".bazelversion").read_text())
        (project / "BUILD.bazel").write_text("")
        (project / "MODULE.bazel").write_text(dependency + '\ninclude("//:python_runtimes.MODULE.bazel")\n')
        (project / "python_runtimes.MODULE.bazel").write_text(render(saved))
        resolved = subprocess.run(
            ["bazel", "--batch", f"--output_base={project / 'output'}", "mod", "show_repo",
             "@pythons_hub", "@cpython_3_13", "@cpython_3_14", "--lockfile_mode=off"],
            cwd=project, text=True, capture_output=True,
        )
        if resolved.returncode:
            raise SystemExit(resolved.stderr)
        result = resolved.stdout
        mapping = ast.literal_eval(re.search(r"minor_mapping = (\{[^\n]+\})", result).group(1))
        assert {minor: mapping[minor] for minor in ("3.13", "3.14")} == {
            "3.13": "3.13.12", "3.14": "3.14.3",
        }, mapping
        assert "3.11" in mapping, mapping
        for minor, (version, url, sha) in zip(["3_13", "3_14"], saved):
            repo = result.split(f"## @cpython_{minor}:")[1].split("\n## ")[0]
            assert f'python_version = "{version}"' in repo
            assert f'urls = ["{url}"]' in repo and f'sha256 = "{sha}"' in repo
        print("Native Bazel catalog isolation passed: saved patches, URLs and SHA-256 win")
elif sys.argv[1:]:
    raise SystemExit("usage: python3 test_python_manifest.py [--bazel]")
