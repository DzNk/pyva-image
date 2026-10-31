"""Prepare a committed Python update; the workflow authenticates and pushes it."""

import ast
import json
import re
import subprocess

import update_python_manifest as updater


def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE).stdout


def versions(fragment):
    mapping = ast.literal_eval(re.search(r"minor_mapping = (\{.*?\})", fragment, re.S).group(1))
    if set(mapping) != set(updater.MINORS):
        raise ValueError("unexpected saved Python minors")
    for minor, version in mapping.items():
        if not re.fullmatch(re.escape(minor) + r"\.[0-9]+", version):
            raise ValueError("invalid saved Python patch")
    return {minor: tuple(map(int, version.split("."))) for minor, version in mapping.items()}


def main():
    if run("git", "status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Python update requires a clean checkout")
    previous = versions(updater.OUTPUT.read_text())
    tag = json.loads(updater.download(updater.LATEST))["tag"]
    checksums = updater.download(f"{updater.RELEASES}/{tag}/SHA256SUMS")
    candidate = updater.render(updater.manifest(tag, checksums))
    if any(version < previous[minor] for minor, version in versions(candidate).items()):
        raise ValueError("refusing a Python patch downgrade")
    updater.refresh(tag, checksums, updater.OUTPUT)
    run("bazel", "mod", "tidy")
    run("bazel", "mod", "deps")
    changed = set(run("git", "diff", "--name-only", "-z", "HEAD").split("\0")) - {""}
    untracked = run("git", "ls-files", "--others", "--exclude-standard", "-z")
    allowed = {"python_runtimes.MODULE.bazel", "MODULE.bazel.lock"}
    if changed - allowed or untracked:
        raise ValueError("unexpected files changed during Python update")
    for command in (
        ("bash", "test_repository.sh"),
        ("python3", "test_python_manifest.py"),
        ("python3", "test_python_manifest.py", "--bazel"),
        ("python3", "test_image_manifest.py"),
        ("bash", "test_release.sh"),
    ):
        print(run(*command), end="")
    if changed:
        run("git", "add", "--", "python_runtimes.MODULE.bazel", "MODULE.bazel.lock")
        run("git", "-c", "user.name=github-actions[bot]", "-c",
            "user.email=41898282+github-actions[bot]@users.noreply.github.com",
            "commit", "-m", "chore: refresh pinned Python runtimes")
    if run("git", "status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Python preparation left a dirty checkout")
    print("Prepared source:", run("git", "rev-parse", "HEAD").strip())


if __name__ == "__main__":
    main()
