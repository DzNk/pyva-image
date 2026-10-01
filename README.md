# Python + JVM distroless runtime

`pyva-runtime` is an amd64 OCI base image for Python applications that start a
JVM through JPype. It uses `static-debian13` as its immutable base, Astral's
python-build-standalone CPython, and Debian 13 OpenJDK 21 JRE. Choose `3.13`
or `3.14`; each uses the latest stable patch saved by the Astral updater.
Both variants are `linux/amd64` (x86_64).

Build a Docker-loadable tarball:

```sh
bazel build //:pyva_runtime_3_13_load //:pyva_runtime_3_14_load --output_groups=tarball
docker load --input bazel-bin/pyva_runtime_3_13_load/tarball.tar
docker load --input bazel-bin/pyva_runtime_3_14_load/tarball.tar
```

Or load one directly with `bazel run //:pyva_runtime_3_13_load` or
`bazel run //:pyva_runtime_3_14_load`. Local tags are `pyva-runtime:3.13` and
`pyva-runtime:3.14`, plus their exact `X.Y.Z-java21-debian13` tags.

The runtime defaults to `/usr/bin/python3`, `/app`, and UID/GID `65532`.
`JAVA_HOME` is `/usr/lib/jvm/java-21-openjdk-amd64`; `java` and
`lib/server/libjvm.so` are present for JPype. No Java truststore configuration
is added.

`/etc/certs` is intentionally empty in this layer. Copy only your PEM files
there and configure Wassima (or your application) to read that directory. The
image sets `SSL_CERT_DIR=/etc/certs`; it does not generate or convert Java
certificate stores.

Because the final image has no shell or package manager, install dependencies
in a builder stage and copy them in:

```Dockerfile
FROM python:3.13-slim AS deps
COPY requirements.txt /
RUN python -m venv /opt/venv \
 && /opt/venv/bin/python -m pip install -r /requirements.txt

FROM pyva-runtime:3.13
USER 0
COPY --from=deps /opt/venv/lib/python3.13/site-packages /opt/python
COPY --chown=65532:65532 app/ /app/
COPY --chown=65532:65532 poi-jars/ /app/poi/
COPY certs/ /etc/certs/
USER 65532:65532
ENV PYTHONPATH=/opt/python
CMD ["/app/main.py"]
```

Use a matching `python:3.14-slim` builder and `python3.14/site-packages` path
when building on `pyva-runtime:3.14`.

## Refresh Python patches

The updater reads Astral's latest release pointer and its `SHA256SUMS`, keeping
the highest stable patch for each of `3.13` and `3.14`, then requiring its
GIL-enabled x86_64 GNU `install_only_stripped` archive:

```sh
python3 update_python_manifest.py
bazel mod tidy
python3 test_python_manifest.py
python3 test_python_manifest.py --bazel
```

Commit `python_runtimes.MODULE.bazel` and any lockfile changes together. This
generated fragment pins each minor's exact patch, immutable URL and checksum
using native rules_python overrides. Ordinary builds do not look up `latest`,
and dependency catalog updates cannot replace the saved interpreter. The same
resolved version generates OCI metadata and release tags; no patch version
needs editing by hand. The current selection is `3.13.15` and `3.14.7`.
The default parser check needs no network; `--bazel` also checks catalog
isolation against the installed rules_python dependency without downloading
interpreter archives.

The upstream stripped archives omit native debug symbols, reducing image size
at the cost of native debugging detail; Python tracebacks still work. If the
latest stable patch has no matching stripped archive, the updater fails without
changing the saved input or choosing an older patch. There is no local strip
step. To roll back this policy, restore the updater and generated input together.
Do not publish a changed image digest over an existing immutable patch tag;
any future publication needs an unpublished patch or a separate repository.

Run the end-to-end checks with Docker available (each builds and loads its
selected image):

```sh
bash smoke_test.sh 3.13
bash smoke_test.sh 3.14
```

## Apache POI integration check

This optional downstream check installs pinned `JPype1` and Apache POI 5.4.1
in builder stages. It starts the JVM from Python, writes a workbook, and
validates the resulting XLSX ZIP structure:

```sh
docker build --platform linux/amd64 --file Dockerfile.poi-smoke --build-arg PYTHON_VERSION=3.13 --tag pyva-poi-smoke:3.13 .
docker run --rm pyva-poi-smoke:3.13
docker build --platform linux/amd64 --file Dockerfile.poi-smoke --build-arg PYTHON_VERSION=3.14 --tag pyva-poi-smoke:3.14 .
docker run --rm pyva-poi-smoke:3.14
```

## Docker Hub release

The immutable release tag is `X.Y.Z-java21-debian13`, derived from the selected
runtime (currently `3.13.15-java21-debian13` or `3.14.7-java21-debian13`). Moving
`3.13-java21-debian13` and `3.14-java21-debian13` channels are updated only when
explicitly requested; a global `latest` is never published. Docker Hub
credentials remain in Docker's local credential store:

```sh
docker login
bash release.sh 3.13 docker.io/<namespace>/pyva-runtime
bash release.sh 3.14 index.docker.io/<namespace>/pyva-runtime
bash release.sh --channel 3.13 index.docker.io/<namespace>/pyva-runtime
bash release.sh --channel 3.14 index.docker.io/<namespace>/pyva-runtime
```

Both `docker.io/<namespace>/<repository>` and
`index.docker.io/<namespace>/<repository>` are accepted. All release operations
and success output use the canonical `index.docker.io` form. Supply exactly two
lowercase path components; URL schemes, tags, digests, whitespace, extra path
components and other registries are rejected before any build or upload.
Components start and end with lowercase letters or digits; separators may be
one dot, one or two underscores, or one or more hyphens.

Check argument validation and release flow without Docker, Bazel or network:

```sh
bash test_release.sh
```

The release command runs the base and POI checks before uploading, then pulls
and verifies the immutable `linux/amd64` tag and prints its repository digest.
Consumers should pin the immutable tag:

```sh
docker pull <namespace>/pyva-runtime:3.13.15-java21-debian13
docker pull <namespace>/pyva-runtime:3.14.7-java21-debian13
```

```Dockerfile
FROM <namespace>/pyva-runtime:3.13.15-java21-debian13
```

Or use `FROM <namespace>/pyva-runtime:3.14.7-java21-debian13` for Python 3.14.
For a stronger pin, use the repository digest printed by the release command.

If a channel release must be corrected, restore the last verified
`python_runtimes.MODULE.bazel` and matching dependency lock
and rerun `release.sh --channel 3.13 ...` or `release.sh --channel 3.14 ...` for
that variant. Do not delete or overwrite an immutable release tag.
A successful release ends with output like
`Published index.docker.io/<namespace>/pyva-runtime:3.13.15-java21-debian13 (index.docker.io/<namespace>/pyva-runtime@sha256:...)`.

## Before publishing the source repository

`.gitignore` excludes Bazel output symlinks, Python caches/virtual environments,
installed `.agents/skills/`, local agent settings, credential directories,
private `*.key` files, `.env` files and consumer `certs/`. Keep `.bazelversion`,
`MODULE.bazel.lock`, `python_runtimes.MODULE.bazel`, sources/tests and the full
`openspec/` history in Git. `.env.example` and public PEM fixtures are not
blanket-ignored. Never put real secrets in an example file or use `git add -f`
to bypass these exclusions. Ignore rules do not remove already tracked files.

`.dockerignore` admits only `Dockerfile.poi-smoke`, `poi-smoke-pom.xml` and
`poi_smoke.py`; Git metadata, build output and local credentials stay outside
the Docker context. Update this allowlist when adding new local `COPY` inputs
to the POI Dockerfile.

Run the offline checks and review all tracked and eligible untracked paths:

```sh
bash test_repository.sh
python3 test_python_manifest.py
bash test_release.sh
git status --short
git ls-files --cached --others --exclude-standard
```

Inspect candidate contents for credentials or unexpected files before staging.
After you stage the reviewed files yourself, use `git diff --cached --stat`
and `git diff --cached` to review the exact commit. Ignore tests are not an
exhaustive secret scan. Commit and push only after this review; Git remotes and
SSH/credential setup remain yours to manage.
