"""Offline update/push regressions with real temporary Git repositories."""

import contextlib
import io
import json
import os
import pathlib
import subprocess
import tempfile
from unittest.mock import patch

import ci_update_python as ci
import update_python_manifest as updater
from test_ci_workflow import WORKFLOW, shell


push_script = shell(WORKFLOW.read_text(), "Save source before publishing")
assert "--force" not in push_script and "git config" not in push_script
real_run = ci.run
real_refresh_java = ci.java_updater.refresh
saved_java = json.loads(ci.java_updater.MANIFEST.read_text())


def records(tag, patch_version):
    return "\n".join(
        f"{'a' * 64}  cpython-{minor}.{patch_version}+{tag}-{platform}-install_only_stripped.tar.gz"
        for minor in updater.MINORS for platform in updater.PLATFORMS.values()
    )


def temurin_release(major, version, checksums):
    return {
        "tag_name": f"jdk-{version}", "draft": False, "prerelease": False,
        "assets": [
            {"name": f"OpenJDK{major}U-jre_{cpu}_linux_hotspot_{version.replace('+', '_')}.tar.gz",
             "state": "uploaded", "digest": f"sha256:{checksums[arch]}"}
            for arch, cpu in ci.java_updater.ARCHITECTURES.items()
        ],
    }


def scenario(case):
    with tempfile.TemporaryDirectory(prefix="pyva-update-test-") as directory:
        root = pathlib.Path(directory)
        repo = root / "repo"
        repo.mkdir()
        original_cwd = pathlib.Path.cwd()
        os.chdir(repo)
        try:
            real_run("git", "init", "--bare", "--quiet", str(root / "remote"))
            real_run("git", "init", "--quiet", "-b", "main")
            real_run("git", "config", "user.name", "Fixture")
            real_run("git", "config", "user.email", "fixture@example.invalid")
            fragment = repo / "python_runtimes.MODULE.bazel"
            fragment.write_text(updater.render(updater.manifest("20260929", records("20260929", 9))))
            java_manifest = repo / "java_runtime.json"
            original_java = json.dumps(saved_java, indent=2) + "\n"
            java_manifest.write_text(original_java)
            (repo / "MODULE.bazel.lock").write_text("old lock\n")
            real_run("git", "add", ".")
            real_run("git", "commit", "--quiet", "-m", "fixture")
            real_run("git", "remote", "add", "origin", str(root / "remote"))
            real_run("git", "push", "--quiet", "origin", "main")
            before = real_run("git", "rev-parse", "HEAD").strip()
            candidate_tag = "20260930" if case == "astral-rebuild" else "20260929"
            candidate_patch = 9 if case in ("no-change", "astral-rebuild", "java-only") else 10
            if case == "downgrade":
                candidate_patch = 8
            data = records(candidate_tag, candidate_patch)
            if case.startswith("missing-") and case != "missing-java":
                target = updater.PLATFORMS[case.removeprefix("missing-")]
                data = "\n".join(line for line in data.splitlines() if f"-{target}-" not in line)
            if case == "bad-checksum":
                data = data.replace("a" * 64, "bad")
            releases = {
                major: temurin_release(major, entry["version"],
                                       {arch: value["sha256"] for arch, value in entry["archives"].items()})
                for major, entry in saved_java.items()
            }
            java_changed = case in ("java-only", "python-and-java")
            java_version, java_build = saved_java["25"]["version"].split("+")
            new_java = f"{java_version}+{int(java_build) + 1}"
            if java_changed or case == "missing-java":
                releases["25"] = temurin_release("25", new_java, dict.fromkeys(ci.java_updater.ARCHITECTURES, "b" * 64))
            if case == "missing-java":
                releases["25"]["assets"].pop()

            def download(url):
                if url == updater.LATEST:
                    return "bad JSON" if case == "bad-metadata" else json.dumps({"tag": candidate_tag})
                assert url == f"{updater.RELEASES}/{candidate_tag}/SHA256SUMS"
                return data

            def run(*args):
                if args[0] == "bazel":
                    if case not in ("no-change", "java-only"):
                        (repo / "MODULE.bazel.lock").write_text("candidate lock\n")
                    if case == "unexpected-file":
                        (repo / "surprise.txt").write_text("not an input")
                    return ""
                if args[0] in ("bash", "python3"):
                    if case == "failed-check":
                        raise subprocess.CalledProcessError(1, args)
                    return ""
                return real_run(*args)

            def refresh_java():
                return real_refresh_java(java_manifest, releases.__getitem__)

            failed = False
            try:
                with patch.object(updater, "OUTPUT", fragment), patch.object(updater, "download", download), patch.object(ci.java_updater, "refresh", refresh_java), patch.object(ci, "run", run), contextlib.redirect_stdout(io.StringIO()):
                    ci.main()
            except (ValueError, subprocess.CalledProcessError):
                failed = True
            invalid = case.startswith("missing-") or case in ("downgrade", "bad-checksum", "bad-metadata", "unexpected-file", "failed-check")
            assert failed == invalid, case
            if invalid:
                assert real_run("git", "rev-parse", "HEAD").strip() == before
                assert real_run("git", "ls-remote", "origin", "refs/heads/main").split()[0] == before
                if case.startswith("missing-"):
                    assert java_manifest.read_text() == original_java
                    assert not real_run("git", "status", "--porcelain", "--untracked-files=all")
                return
            after = real_run("git", "rev-parse", "HEAD").strip()
            assert (after == before) == (case == "no-change")
            assert int(real_run("git", "rev-list", "--count", f"{before}..{after}")) == int(after != before)
            expected_files = set() if case == "no-change" else {"python_runtimes.MODULE.bazel", "MODULE.bazel.lock"}
            if case == "java-only":
                expected_files.clear()
            if java_changed:
                expected_files.add("java_runtime.json")
                pins = json.loads(real_run("git", "show", f"{after}:java_runtime.json"))
                assert pins["21"] == saved_java["21"] and pins["25"]["version"] == new_java
                assert set(pins["25"]["archives"]) == set(ci.java_updater.ARCHITECTURES)
            assert set(real_run("git", "diff", "--name-only", before, after).splitlines()) == expected_files
            assert ci.versions(real_run("git", "show", f"{after}:python_runtimes.MODULE.bazel")) == {
                "3.13": (3, 13, candidate_patch), "3.14": (3, 14, candidate_patch),
            }
            assert not real_run("git", "status", "--porcelain", "--untracked-files=all")
            assert "extraheader" not in (repo / ".git/config").read_text()
            if case == "rejected-push":
                hook = root / "remote/hooks/pre-receive"
                hook.write_text("#!/bin/sh\nexit 1\n")
                hook.chmod(0o755)
            if case == "concurrent-main":
                real_run("git", "clone", "--quiet", "-b", "main", str(root / "remote"), str(root / "other"))
                real_run("git", "-C", str(root / "other"), "-c", "user.name=Other", "-c", "user.email=other@example.invalid", "commit", "--quiet", "--allow-empty", "-m", "concurrent")
                real_run("git", "-C", str(root / "other"), "push", "--quiet", "origin", "main")
            output = root / "output"
            result = subprocess.run(
                ["bash", "-e", "-o", "pipefail", "-c", push_script], text=True, capture_output=True,
                env={**os.environ, "GH_TOKEN": "fixture-token", "BASE_SHA": before, "GITHUB_OUTPUT": str(output)},
            )
            if case in ("rejected-push", "concurrent-main"):
                assert result.returncode and not output.exists(), case
            else:
                assert result.returncode == 0, result.stderr
                assert output.read_text().strip() == f"sha={after}"
                assert real_run("git", "ls-remote", "origin", "refs/heads/main").split()[0] == after
                if case == "update":
                    # A later schedule must retry publication even with no new source diff.
                    with patch.object(updater, "OUTPUT", fragment), patch.object(updater, "download", download), patch.object(ci.java_updater, "refresh"), patch.object(ci, "run", run), contextlib.redirect_stdout(io.StringIO()):
                        ci.main()
                    assert real_run("git", "rev-parse", "HEAD").strip() == after
            assert "fixture-token" not in result.stdout + result.stderr + (repo / ".git/config").read_text()
        finally:
            os.chdir(original_cwd)


for case in ("update", "java-only", "python-and-java", "no-change", "astral-rebuild", "downgrade",
             "bad-checksum", "bad-metadata", "unexpected-file", "failed-check", "rejected-push", "concurrent-main",
             "missing-java", *("missing-" + arch for arch in updater.PLATFORMS)):
    scenario(case)
print("CI update passed: numeric patches, atomic inputs, real Git push, no-change/retry and rejected/concurrent writes")
