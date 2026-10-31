# Maintaining pyva-runtime

## Inputs and refresh

Bazel uses the version in `.bazelversion`. `MODULE.bazel` pins a Distroless Debian
13 OCI index and the Debian snapshot `20250901T000000Z` for both amd64 and arm64.
Build tools use the catalog Python 3.12 toolchain on the build host; image
interpreters remain the explicitly pinned Linux Python 3.13/3.14 artifacts.
The generated Python fragment pins one stable patch per minor, four immutable
Astral URLs and SHA-256 checksums. Ordinary builds never resolve `latest`.

```sh
python3 update_python_manifest.py
bazel mod tidy
bazel mod deps
python3 test_python_manifest.py
python3 test_python_manifest.py --bazel
```

The updater selects the highest stable patch for each minor, then requires both
GNU/GIL-enabled `install_only_stripped` archives. Missing either architecture
fails atomically without choosing an older patch. Commit the fragment and lock
changes together. Native rules_python overrides prevent catalog substitution.
The stripped inputs omit native debug symbols; Python tracebacks still work.
There is no local strip step. Restore the updater and fragment together to roll
back the policy, and publish under a new commit-derived tag.

## Build and execute

There are four explicit image/load targets and two native OCI index targets.
The index targets `//:pyva_runtime_3_13` and `//:pyva_runtime_3_14` each contain
both platforms. Debian Java closures and `JAVA_HOME` use the selected architecture.

```sh
bazel build //:pyva_runtime_3_13 //:pyva_runtime_3_14
for minor in 3_13 3_14; do
  for arch in amd64 arm64; do
    target="pyva_runtime_${minor}_${arch}_load"
    bazel build "//:${target}" --output_groups=tarball
    docker load --input "bazel-bin/${target}/tarball.tar"
  done
done
```

Architecture tags are `pyva-runtime:3.13-amd64`, `:3.13-arm64`, `:3.14-amd64`,
and `:3.14-arm64`. Legacy `bazel run //:pyva_runtime_3_13_load` and
`//:pyva_runtime_3_14_load` still load amd64, with `:3.13`/`:3.14` and exact
`X.Y.Z-java21-debian13` local aliases. Their tarball paths remain available.
ARM loaders never replace these aliases.

```sh
for minor in 3.13 3.14; do
  for arch in amd64 arm64; do
    bash smoke_test.sh "$minor" --arch "$arch"
    docker build --platform "linux/$arch" --file Dockerfile.poi-smoke \
      --build-arg "PYTHON_VERSION=$minor" \
      --build-arg "RUNTIME_IMAGE=pyva-runtime:$minor-$arch" \
      --tag "pyva-poi-smoke:$minor-$arch" .
    docker run --rm --platform "linux/$arch" --network none "pyva-poi-smoke:$minor-$arch"
  done
done
```

`bash smoke_test.sh 3.13` retains its amd64 default. An optional final image
reference checks an already loaded/pulled image. Both platforms must execute:
use a native runner or existing Docker emulation. Docker must support
`docker image inspect --platform` (API 1.49+) to inspect the requested platform
in a multi-platform image store. Scripts do not install binfmt
or skip ARM failures. The POI check installs target-platform JPype1 1.7.1 and
Apache POI 5.4.1 in builder stages, writes XLSX and checks its ZIP structure.

## Downstream dependencies and certificates

The runtime has no shell or package manager. Install Python dependencies in a
matching Python minor/platform builder with a compatible GIL/ABI and Debian/glibc
environment; supply required shared libraries and Java JARs separately. The base
contains no pip, ensurepip or setuptools, including pip's vendored msgpack and
pkg_resources. Install dependencies only in the builder. For example:

```Dockerfile
FROM python:3.13-slim AS deps
COPY requirements.txt /
RUN python -m pip install --target /python -r /requirements.txt
FROM pyva-runtime:3.13-amd64
USER 0
COPY --from=deps /python /opt/python
COPY --chown=65532:65532 app/ /app/
COPY poi-jars/ /app/poi/
COPY certs/ /etc/certs/
USER 65532:65532
ENV PYTHONPATH=/opt/python
CMD ["/app/main.py"]
```

Copy the installed application packages, their native extensions, package data
and `.dist-info` metadata; `importlib.metadata` and entry points need that metadata.
Copying the builder's entire system site-packages can reintroduce installation
tools. Files such as `cffi/setuptools_ext.py` belong to their application package
and are not removed; explicitly required standalone msgpack remains supported.
If application code or legacy entry points need setuptools/pkg_resources at
runtime, explicitly install a compatible provider in the builder and copy it too.
Check absolute shebang paths for copied console scripts; the example invokes the
application through the runtime's `/usr/bin/python3` entrypoint.

`python -m pip`, `python -m ensurepip` and automatic pip bootstrapping with
`python -m venv` are unsupported. The `venv` module remains available with
`--without-pip`. Check application startup and migration/initContainer commands
before changing the consumer's image digest.

Use a matching 3.14 builder/runtime for Python 3.14; select the matching platform
and local tag for ARM64. Defaults: `/usr/bin/python3`, `/app`, UID/GID 65532.
`JAVA_HOME=/usr/lib/jvm/java-21-openjdk-<arch>` and its `lib/server` is in
`LD_LIBRARY_PATH`. `/etc/certs` starts empty, with `SSL_CERT_DIR=/etc/certs`.
Copy your public PEM files there and configure Wassima or your application to
read them. The image does not generate/convert a Java truststore; configure
Java truststores separately when required. Never copy private keys into images.

## Release

Credentials stay in Docker's external credential store. Run from a clean source
commit, including eligible untracked files. The immutable tag is
`X.Y.Z-java21-debian13-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>`; the timestamp is the
Git **committer** time converted to UTC. Rebuild time and timezone do not affect
the tag or image bytes. The image version label remains `X.Y.Z-java21-debian13`.

```sh
docker login
bash release.sh 3.13 docker.io/<namespace>/pyva-runtime
bash release.sh 3.14 index.docker.io/<namespace>/pyva-runtime
bash release.sh --channel 3.13 docker.io/<namespace>/pyva-runtime
```

The two Docker Hub host aliases normalize to `index.docker.io`. Supply exactly
two lowercase path components, without schemes, tags, digests or whitespace.
Other registries are rejected before any build/upload. Components begin/end in
letters/digits; separators are one dot, one/two underscores or hyphens.

Both base and POI runs must pass and match the candidate manifests. Local OCI
inspection checks every layer blob for bundled Python installation tools; hiding
them with a later whiteout is rejected. Before upload, a confirmed absent
immutable tag permits publishing; identical index content
permits a verified retry. Different content, authorization, transport and unknown
errors stop the release without overwriting. After upload, the index and both
child digests must match, and both explicit platform pulls/runs must pass.

Optional `--channel` updates only `3.13-java21-debian13` or `3.14-java21-debian13`,
after all immutable checks, by copying the verified registry index **by digest**
and checking equality. Default releases leave channels alone; no global `latest`.
The preflight assumes one publisher per repository/tag. Serialize concurrent
publishers; Docker Hub offers no compare-and-set tag update.

```sh
docker pull --platform linux/arm64 <repository>:<dated-immutable-tag>
docker pull --platform linux/amd64 <repository>@sha256:<verified-index-digest>
# Roll a channel back to an already verified release:
docker buildx imagetools create --tag <repository>:3.13-java21-debian13 \
  <repository>@sha256:<previous-verified-index-digest>
docker buildx imagetools inspect <repository>:3.13-java21-debian13
```

Consumers can use `FROM <repository>:<dated-immutable-tag>` or the index digest.
Never delete or overwrite an immutable release tag. Restoring saved inputs still
requires a new reviewed source commit and therefore a new dated release tag.

## GitHub Actions automation

The `Python runtime` workflow in `.github/workflows/ci.yml` checks pull requests
to `main`, publishes pushes to `main`, and checks Astral daily at **04:23 UTC**.
Use **Actions → Python runtime → Run workflow → main** to start it immediately.
Other branches/tags cannot refresh inputs, authenticate to Docker Hub or publish.
PRs, including forks, run regressions and both Python minors on amd64/arm64
without repository writes or publishing credentials.

One-time setup for a public GitHub repository and public Docker Hub repository:

1. Set the default branch to `main` and enable GitHub Actions. Standard
   `ubuntu-24.04` runners are free for public repositories. Jobs skip private
   repositories before allocating runners; no Actions artifact/cache uploads
   or paid runners/services are used.
2. In **Settings → Secrets and variables → Actions → Variables**, add
   `DOCKERHUB_REPOSITORY` (`docker.io/<namespace>/pyva-runtime`) and
   `DOCKERHUB_USERNAME` (the Docker ID owning the token, which may differ from
   the destination namespace).
3. In the **Secrets** tab, add `DOCKERHUB_TOKEN`, a Docker personal access token
   with **Read & Write** access to the destination. Docker Personal supports
   PATs. Create it in Docker **Account settings → Personal access tokens**;
   copy it directly into the GitHub secret. Rotate the secret when the token
   expires. Delete permission is unnecessary.
4. Allow the workflow's preparation job to request `contents: write`, and ensure
   branch rules permit that bot's ordinary push to `main`. An unprotected
   personal repository needs no separate GitHub PAT or SSH key in Actions.
   Keep default workflow permissions restricted: only preparation requests
   write access. The workflow does not bypass branch protection or enable PR
   approvals; if rules require every change to use a PR, configure an allowed
   automation identity before enabling automatic updates.

Scheduled/manual runs use `update_python_manifest.py` and `bazel mod tidy` /
`bazel mod deps` to prepare stable GIL-enabled GNU `install_only_stripped`
artifacts for Python 3.13/3.14, with both architectures required. A new Astral
artifact release at the same Python patch also counts as an update. A missing
artifact, malformed checksum or Python patch downgrade fails without recording
partial inputs. A CPython announcement alone is insufficient: the corresponding
complete Astral release must be available. Java, Debian, Bazel, rules and the
supported minor list are not automatically upgraded.

Preparation commits only `python_runtimes.MODULE.bazel` and its required
`MODULE.bazel.lock`, after checks, directly to `main` without a PR or manual
merge. Unchanged inputs create no empty commit. A normal push rejected by branch
rules or a concurrent update stops the run; it never force-pushes. A push made
with `GITHUB_TOKEN` does not trigger another push workflow, so the **same run**
passes its saved commit SHA to subsequent checks and publication jobs. All
release jobs use that exact clean checkout. Main push events use committed
inputs without refreshing Python. Trusted runs select current `main` after
acquiring the shared publication group, so a queued older event does not select
an obsolete event SHA.

After regressions, each minor calls `release.sh --channel`, including base and
JPype/POI execution on both platforms and remote digest/pull checks. Each verified
index gets its existing immutable commit-derived tag and its
`3.13-java21-debian13` or `3.14-java21-debian13` channel. No global `latest` is
created. One minor can succeed while the other fails; the overall workflow then
fails and the failed minor's channel is not advanced. Publication is not a
two-minor transaction.

Every successful scheduled/manual preparation proceeds to publication even
without new inputs. This intentionally repeats builds/checks daily, reuses
matching immutable content and recovers transient or partial publication failures
at the next scheduled run, without another commit or operator approval. Manual
dispatch offers an earlier retry. A different digest at an immutable tag or an
uncertain registry inspection error stops publication; never delete or overwrite
the tag to bypass that error.

Schedule, push and manual runs share one concurrency group from source selection
through publication, and do not cancel an active publisher. PR groups are
independent. This protects only this repository's CI: local/external publishers
must not overlap it. Pending runs can be replaced; the group is not a FIFO queue.

GitHub schedules run from the default branch, can be delayed or dropped under
load, and public repositories can have schedules disabled after 60 days without
repository activity. Re-enable the workflow in Actions and dispatch it on `main`
when recovering; this schedule is not a delivery SLA. See GitHub's
[schedule rules](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)
and [token trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

Before intentionally rolling source or a channel back, **disable the workflow**
in Actions. Otherwise its next run selects latest Astral again and refreshes the
channels. Use the verified digest rollback commands above; preserve immutable
tags. Re-enable automation when ready to follow upstream again.

For the first hosted run, record its URL, selected/bot commit SHA, both immutable
tags and index digests, and both channel digests from the logs. Confirm there is
no approval gate, both platforms execute, and a repeat of the unchanged source
reuses the same identity. Use the offline update fixtures for rejected pushes and
failure recovery; do not claim a hosted scenario passed without its actual run.

## Source review

`.gitignore` excludes Bazel symlinks, Python caches/venvs, `.agents/skills/`, local
agent settings, credential directories, private `*.key`, `.env`, and consumer
`certs/`. Keep `.bazelversion`, module/lock/generated fragment, sources/tests and
full `openspec/` history. `.env.example` and public PEM fixtures are eligible;
never include real secrets or use `git add -f`. Ignores do not untrack files.
`.dockerignore` permits only the POI Dockerfile, POM and smoke script. Update it
when that Dockerfile needs new local COPY inputs.

```sh
bash test_repository.sh
python3 test_python_manifest.py
python3 test_python_manifest.py --bazel
python3 test_image_manifest.py
bash test_release.sh
python3 test_ci_workflow.py
python3 test_ci_update.py
actionlint .github/workflows/ci.yml
bash -n release.sh smoke_test.sh test_release.sh
git status --short
git ls-files --cached --others --exclude-standard
git diff --cached --stat
git diff --cached
```

Review candidate contents for credentials and generated output before staging;
ignore tests are not a secret scan. Git remote/SSH setup stays external. Build
reproducibility and publication evidence lives in the active change's
`validation.md`. Do not push source without the user's request.
