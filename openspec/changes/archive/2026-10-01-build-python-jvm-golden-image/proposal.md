# Proposal

## Why

The stock Debian 13 distroless Python image follows Debian's Python patch level, while the Java image is Java-first and brings a Java-oriented trust-store model. We need one Python-first, reproducible OCI base image with an explicitly pinned CPython runtime and a JVM suitable for Apache POI through JPype, without combining two finished distroless images.

## What Changes

- Replace the current non-functional image macro with a Bazel-built Debian 13 distroless runtime image.
- Make the exact CPython patch release a single pinned build input and include the complete standard library, native extension modules, and their runtime libraries.
- Include a headless Java runtime at version 21 (satisfying the Java 17+ requirement) and expose stable JVM discovery settings for JPype while keeping Python as the image entrypoint.
- Provide an empty `/etc/certs` contract for consumer-supplied PEM certificates and configure Python/OpenSSL discovery for that directory; do not create or synchronize a Java trust store.
- Produce an OCI image plus a Docker-loadable archive so downstream Dockerfiles can add application code, Python packages, JARs, and certificates before registry publication.
- Add smoke checks for the pinned Python version, representative native Python modules, Java availability, JVM shared-library loading from Python, certificate-directory behavior, and absence of a shell/package manager.

## Capabilities

### New Capabilities

- `python-jvm-runtime-image`: Defines the build, runtime, configuration, certificate, and verification contract of the Python-first Debian 13 distroless OCI image.

### Modified Capabilities

None.

## Impact

- Reworks `MODULE.bazel`, `BUILD.bazel`, and `pyva.bzl` around valid `rules_oci`, `rules_python`, and `rules_distroless` APIs.
- Adds pinned upstream runtime inputs and small image-layer/test fixtures needed for reproducible assembly.
- Establishes `/usr/bin/python3` as the primary executable, Java 21 as an embedded supporting runtime, `/etc/certs` as the PEM injection point, and `linux/amd64` as the initial target platform.
- Downstream applications remain responsible for adding pip packages, JPype, Apache POI JARs, application code, and deployment-specific PEM certificates.
