"""Offline workflow policy checks; actionlint separately checks YAML and types."""

import json
import os
import pathlib
import re
import subprocess
import textwrap
from types import SimpleNamespace


WORKFLOW = pathlib.Path(__file__).with_name(".github") / "workflows/ci.yml"


def step(text, name):
    return re.search(
        r"(?ms)^      - name: " + re.escape(name) + r"\n(.*?)(?=^      - |^  \w|\Z)", text
    ).group(1)


def shell(text, name):
    return textwrap.dedent(step(text, name).split("        run: |\n", 1)[1])


def guard(expression, event, ref="refs/heads/main", private=False, **needs):
    github = SimpleNamespace(
        event_name=event, ref=ref,
        event=SimpleNamespace(repository=SimpleNamespace(private=private)),
    )
    expression = expression.replace("${{", "").replace("}}", "").strip()
    expression = expression.replace("&&", " and ").replace("||", " or ")
    expression = expression.replace("!cancelled()", "True").replace("false", "False")
    return eval(expression, {"__builtins__": {}}, {
        "github": github, "fromJSON": json.loads, "contains": lambda xs, x: x in xs,
        "needs": SimpleNamespace(**{k: SimpleNamespace(result=v) for k, v in needs.items()}),
    })


def check(text):
    jobs = dict(re.findall(r"(?ms)^  (\w+):\n(.*?)(?=^  \w+:|\Z)", text.split("jobs:\n", 1)[1]))
    assert set(jobs) == {"source", "refresh", "checks", "runtime"}
    assert "branches: [main]" in text and "cron: '23 4 * * *'" in text
    assert "workflow_dispatch:" in text and "permissions:\n  contents: read" in text
    assert "|| 'pyva-publication'" in text
    assert "cancel-in-progress: ${{ github.event_name == 'pull_request' }}" in text
    assert text.count("contents: write") == 1 and "contents: write" in jobs["refresh"]
    assert "needs: [source, refresh]" in jobs["checks"]
    assert "needs: checks" in jobs["runtime"]
    assert "needs.refresh.outputs.sha || needs.source.outputs.sha" in jobs["checks"]
    assert "needs.checks.outputs.sha" in jobs["runtime"]
    assert "github.event_name == 'pull_request' && github.sha || 'main'" in jobs["source"]
    assert "minor: ['3.13', '3.14']" in text and "fail-fast: false" in text
    assert "version: v29.8.2" in text and '"containerd-snapshotter":true' in text
    assert "platforms: arm64" in text and "cache-image: false" in text
    for action in re.findall(r"uses: (\S+)", text):
        assert re.fullmatch(r"[\w-]+/[\w-]+@[0-9a-f]{40}", action), action
        assert not any(x in action for x in ("actions/cache", "upload-artifact", "download-artifact"))
    assert text.count("persist-credentials: false") == text.count("uses: actions/checkout@")
    assert text.count("cache-save: false") == text.count("uses: bazel-contrib/setup-bazel@")
    assert "secrets." not in jobs["source"] + jobs["refresh"] + jobs["checks"]
    assert text.count("secrets.DOCKERHUB_TOKEN") == 1
    assert "if: *publish" in step(text, "Docker Hub login")
    assert "password: ${{ secrets.DOCKERHUB_TOKEN }}" in step(text, "Docker Hub login")
    assert "if: *publish" in step(text, "Publish verified images and channel")
    assert 'run: bash release.sh --channel "$MINOR" "$DOCKERHUB_REPOSITORY"' in text
    assert "if: ${{ github.event_name == 'pull_request' }}" in step(text, "Validate pull request images")
    assert "GH_TOKEN:" in step(text, "Save source before publishing")
    assert text.count("GH_TOKEN:") == 1 and "persist-credentials: true" not in text
    guards = {k: re.search(r"^    if: (.+)$", v, re.M).group(1) for k, v in jobs.items()}
    publish = re.search(r"if: &publish (.+)", text).group(1)
    for private in (False, True):
        for event in ("pull_request", "push", "schedule", "workflow_dispatch", "release"):
            for ref in ("refs/heads/main", "refs/heads/feature", "refs/tags/v1", "refs/pull/1/merge"):
                trusted = not private and ref == "refs/heads/main" and event in ("push", "schedule", "workflow_dispatch")
                assert guard(publish, event, ref, private) == trusted
                assert guard(guards["refresh"], event, ref, private) == (trusted and event != "push")
                assert guard(guards["source"], event, ref, private) == (not private and (event == "pull_request" or trusted))
    for result in ("success", "skipped", "failure", "cancelled"):
        assert guard(guards["checks"], "push", source="success", refresh=result) == (result in ("success", "skipped"))
        assert guard(guards["checks"], "push", source=result, refresh="skipped") == (result == "success")
        assert guard(guards["runtime"], "push", checks=result) == (result == "success")


if __name__ == "__main__":
    workflow = WORKFLOW.read_text()
    check(workflow)
    try:
        check(workflow.replace("        if: *publish\n", ""))
    except AssertionError:
        pass
    else:
        raise AssertionError("Missing publication guard was not detected")
    configuration = shell(workflow, "Check publication configuration")
    for destination, username in (("", "fixture"), ("docker.io/example/runtime", ""), ("docker.io/example/runtime", "fixture")):
        result = subprocess.run(["bash", "-e", "-c", configuration], capture_output=True, env={
            **os.environ, "DOCKERHUB_REPOSITORY": destination, "DOCKERHUB_USERNAME": username,
        })
        assert (result.returncode == 0) == bool(destination and username)
    print("Workflow policy passed: public/main guards, isolated credentials, frozen SHA and serialized publishers")
