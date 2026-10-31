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


def records(tag, patch_version):
    return "\n".join(
        f"{'a' * 64}  cpython-{minor}.{patch_version}+{tag}-{platform}-install_only_stripped.tar.gz"
        for minor in updater.MINORS for platform in updater.PLATFORMS.values()
    )


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
            (repo / "MODULE.bazel.lock").write_text("old lock\n")
            real_run("git", "add", ".")
            real_run("git", "commit", "--quiet", "-m", "fixture")
            real_run("git", "remote", "add", "origin", str(root / "remote"))
            real_run("git", "push", "--quiet", "origin", "main")
            before = real_run("git", "rev-parse", "HEAD").strip()
            candidate_tag = "20260930" if case == "astral-rebuild" else "20260929"
            candidate_patch = 9 if case in ("no-change", "astral-rebuild") else 10
            if case == "downgrade":
                candidate_patch = 8
            data = records(candidate_tag, candidate_patch)
            if case.startswith("missing-"):
                target = updater.PLATFORMS[case.removeprefix("missing-")]
                data = "\n".join(line for line in data.splitlines() if f"-{target}-" not in line)
            if case == "bad-checksum":
                data = data.replace("a" * 64, "bad")

            def download(url):
                if url == updater.LATEST:
                    return "bad JSON" if case == "bad-metadata" else json.dumps({"tag": candidate_tag})
                assert url == f"{updater.RELEASES}/{candidate_tag}/SHA256SUMS"
                return data

            def run(*args):
                if args[0] == "bazel":
                    if case != "no-change":
                        (repo / "MODULE.bazel.lock").write_text("candidate lock\n")
                    if case == "unexpected-file":
                        (repo / "surprise.txt").write_text("not an input")
                    return ""
                if args[0] in ("bash", "python3"):
                    if case == "failed-check":
                        raise subprocess.CalledProcessError(1, args)
                    return ""
                return real_run(*args)

            failed = False
            try:
                with patch.object(updater, "OUTPUT", fragment), patch.object(updater, "download", download), patch.object(ci, "run", run), contextlib.redirect_stdout(io.StringIO()):
                    ci.main()
            except (ValueError, subprocess.CalledProcessError):
                failed = True
            invalid = case.startswith("missing-") or case in ("downgrade", "bad-checksum", "bad-metadata", "unexpected-file", "failed-check")
            assert failed == invalid, case
            if invalid:
                assert real_run("git", "rev-parse", "HEAD").strip() == before
                assert real_run("git", "ls-remote", "origin", "refs/heads/main").split()[0] == before
                return
            after = real_run("git", "rev-parse", "HEAD").strip()
            assert (after == before) == (case == "no-change")
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
                    with patch.object(updater, "OUTPUT", fragment), patch.object(updater, "download", download), patch.object(ci, "run", run), contextlib.redirect_stdout(io.StringIO()):
                        ci.main()
                    assert real_run("git", "rev-parse", "HEAD").strip() == after
            assert "fixture-token" not in result.stdout + result.stderr + (repo / ".git/config").read_text()
        finally:
            os.chdir(original_cwd)


for case in ("update", "no-change", "astral-rebuild", "downgrade", "bad-checksum", "bad-metadata", "unexpected-file", "failed-check", "rejected-push", "concurrent-main", *("missing-" + arch for arch in updater.PLATFORMS)):
    scenario(case)
print("CI update passed: numeric patches, atomic inputs, real Git push, no-change/retry and rejected/concurrent writes")
