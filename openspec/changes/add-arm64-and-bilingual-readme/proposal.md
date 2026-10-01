# Proposal

## Why

The runtime only builds and verifies amd64, preventing equivalent use on ARM64 machines. README mixes consumer information with extensive maintainer procedures; visitors need a short Russian-first, bilingual explanation of the Python-to-Java use case.

## What Changes

- Build Python 3.13 and 3.14 for both `linux/amd64` and `linux/arm64`, using matching pinned CPython, Debian JRE and distroless inputs.
- **BREAKING:** Replace undated immutable publication tags with `X.Y.Z-java21-debian13-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>`, using the source Git commit's UTC committer time and full SHA. Publish each Python minor as one OCI image index so Docker chooses the architecture automatically; preserve existing immutable tags rather than changing their artifacts. Keep opt-in minor channels, explicit per-architecture local archives and existing amd64 load commands.
- Require runtime and JPype/Apache POI execution checks on both architectures before releasing either; verify both platforms after pulling a release.
- Audit and correct immutable-tag collision handling, index digest reporting and the order of channel updates. During implementation, publish fresh verified 3.13 and 3.14 indexes to the existing Docker Hub repository and record their remote index/platform digests; retain previous immutable tags.
- Replace README with a compact Russian section followed by English, visible Python/Java/JPype/Apache POI/Distroless keywords, supported versions/platforms and one shared minimal usage example. Describe POI as a use case, not a bundled dependency. State in both languages that consumer PEM certificates belong in `/etc/certs` and that the image sets `SSL_CERT_DIR=/etc/certs`; include the certificate COPY in the shared example.
- Move build, update, test, release, certificate and repository-maintenance instructions to `CONTRIBUTING.md`, linked from README.

## Capabilities

### New Capabilities

None; reuse existing capabilities.

### Modified Capabilities

- `python-jvm-runtime-image`: support both platforms with matching JVM paths and architecture-specific Docker-loadable archives.
- `python-minor-image-builds`: select one latest stable patch per minor, save stripped artifacts for both architectures, and build four variants without catalog substitution.
- `dockerhub-image-publication`: introduce dated reproducible immutable tags with overwrite protection, publish a two-platform index, validate both platforms before upload and after pull, advance requested channels only after immutable verification, and split concise bilingual consumption docs from maintainer instructions.

## Impact

Changes affect `MODULE.bazel`, its lockfile, `python_runtimes.MODULE.bazel`, `update_python_manifest.py`, `BUILD.bazel`, `runtime_image.bzl`, `smoke_test.sh`, `release.sh`, existing regression tests, README and new `CONTRIBUTING.md`. Reuse installed Bazel rules, Python stdlib and Docker; no new build framework, CI or bundled application libraries. Tests require Docker capable of executing both architectures, natively or through already configured emulation. The proposal workflow performs no uploads or Git mutations. Later implementation includes a reviewed local release commit and a clean checkout of that commit, required for honest commit-derived release identity, followed by the requested verified republication. Git push and host emulation installation are outside this change. The Docker Hub destination stays a runtime input from the session; account names and credentials are not written into project files. Existing amd64-only spec clauses and undated release identity are deliberately superseded by the deltas.
