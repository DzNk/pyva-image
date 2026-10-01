# Proposal

## Why

The runtime image builds and passes Python/JVM/Apache POI integration checks, but publication still depends on ad-hoc Docker tagging and pushing. A reproducible Docker Hub release path is needed so consumers can pull a documented, versioned image without embedding registry credentials or an account name in the source tree.

## What Changes

- Add a `rules_oci` push target for the existing `pyva_runtime` image, with the Docker Hub repository supplied at release time.
- Define a stable tag policy with an immutable runtime tag (`3.13.15-java21-debian13`) and an explicitly published moving channel tag (`3.13-java21-debian13`).
- Add standard OCI image metadata suitable for Docker Hub discovery and inspection without changing the runtime filesystem or entrypoint.
- Add a release verification flow that runs the existing runtime and Apache POI smoke checks before pushing, then pulls the immutable tag and verifies it after publication.
- Document Docker Hub authentication, repository naming, tag selection, push, pull, and downstream `FROM` usage. Credentials remain outside the repository.
- Keep publication limited to the currently supported `linux/amd64` image; multi-architecture manifests and hosted CI automation are not part of this change.

## Capabilities

### New Capabilities

- `dockerhub-image-publication`: Defines Docker Hub release metadata, tag behavior, authentication boundaries, pre-push gates, and post-push verification for the runtime image.

### Modified Capabilities

None.

## Impact

The root Bazel build gains publication metadata and a registry push target. Release documentation and smoke commands are extended, while the existing OCI layers, Python/JVM runtime contract, non-root identity, and Docker-loadable archive remain unchanged. Docker Hub is the only external system affected; the publisher supplies the repository name and credentials at invocation time.
