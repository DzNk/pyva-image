# Maintaining pyva-runtime

## Inputs and refresh

Bazel uses the version in `.bazelversion`. `MODULE.bazel` pins a Distroless Debian
13 OCI index and the Debian snapshot `20250901T000000Z` for both amd64 and arm64.
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
    docker run --rm --platform "linux/$arch" "pyva-poi-smoke:$minor-$arch"
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
matching Python minor/platform builder and copy its site-packages; supply Java
JARs separately. For example:

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

Both base and POI runs must pass and match the candidate manifests. Before upload,
a confirmed absent immutable tag permits publishing; identical index content
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
bash test_release.sh
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
