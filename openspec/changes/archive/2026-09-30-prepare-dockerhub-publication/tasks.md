# Tasks

## 1. Publishable OCI Target

- [x] 1.1 Add deterministic OCI labels for the Python 3.13.15, Java 21, Debian 13 runtime to `pyva_runtime`; build the image and inspect its config to verify the labels are present while entrypoint, environment, UID/GID, architecture, and layer digests remain otherwise unchanged.
- [x] 1.2 Add an `oci_push` target with no embedded repository and the immutable tag `3.13.15-java21-debian13`; verify Bazel analyzes the target and invoking it without `--repository` exits before any upload.
- [x] 1.3 Document the immutable and opt-in channel tag policy beside the version update instructions; verify every documented tag matches the pinned CPython/JVM/Debian versions in `MODULE.bazel` and `BUILD.bazel`.

## 2. Gated Docker Hub Release

- [x] 2.1 Parameterize the base smoke check so it can test either the locally built image or a supplied image reference without rebuilding it; verify the existing local smoke command and a second local tag both pass the same Python, JVM, certificate, non-root, and distroless assertions.
- [x] 2.2 Add one minimal release entrypoint that validates a fully qualified `index.docker.io/<namespace>/<repository>` destination, runs the base and POI smoke gates, invokes the push target with only the immutable tag by default, optionally adds `3.13-java21-debian13`, pulls the immutable tag, verifies `linux/amd64`, reruns the runtime assertions, and reports the repository digest; verify syntax and invalid/missing-input paths perform no upload.
- [x] 2.3 Document Docker Hub login via external credential storage, release commands with and without the moving channel, immutable pull and `FROM` examples, amd64-only support, expected digest output, and channel rollback; verify the commands use no inline credentials or tracked account name.
- [x] 2.4 With a publisher-supplied Docker Hub staging repository and credentials, run the release entrypoint without the channel option, confirm both smoke gates pass, pull `3.13.15-java21-debian13`, confirm the remote image passes the runtime checks and reports `linux/amd64`, and record the returned digest without committing credentials.
