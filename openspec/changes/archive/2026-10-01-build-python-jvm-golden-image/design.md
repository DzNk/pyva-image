# Design

## Context

The repository contains only a Bzlmod declaration, a single image target, and an invalid `pyva.bzl` sketch. The current macro uses unsupported Starlark/Python syntax, references undeclared repositories, and does not construct a base, Python layer, Java layer, certificate layout, or loadable artifact.

Google's Debian 13 Python image installs Debian's Python packages on its C/C++ runtime base; it therefore inherits Debian's patch cadence. The requested exact patch selection requires a separately pinned CPython distribution. The same upstream image also demonstrates why a C-runtime-capable root filesystem and a generated loader cache are needed for native Python modules.

## Goals / Non-Goals

**Goals:**

- Keep a single exact Python version/checksum declaration and make Python the image entrypoint.
- Assemble one root filesystem from a pinned Debian 13 distroless base plus runtime layers; do not merge completed Python and Java images.
- Keep filesystem paths and environment variables stable for downstream Dockerfiles and JPype.
- Leave one daemon-based smoke check that exercises the artifact as Docker will run it.

**Non-Goals:**

- Shipping pip, JPype, Apache POI, application JARs, or application code in the golden image.
- Building or compiling CPython from source.
- Supporting architectures other than `linux/amd64` in the first change.
- Managing Java CA certificates or making Java TLS trust the contents of `/etc/certs`.
- Providing a shell/debug variant or runtime package installation.

## Decisions

### Compose layers on a pinned Debian 13 static base

Pull `gcr.io/distroless/static-debian13` by digest with `rules_oci`, then add only the filesystem layers needed by CPython, the JVM, and image metadata. Use `rules_distroless` with Debian 13 UsrMerge enabled to resolve the headless Java package and its shared-library dependency closure from a pinned Debian snapshot.

This follows the requested static starting point while avoiding the fragile approach of copying files between two final distroless images. Starting from the published Python image was rejected because it fixes Python to the Debian package version. Starting from the Java image was rejected because it makes Java's layout and policy the base contract.

### Source CPython from the hermetic rules_python runtime

Register exactly one `rules_python` toolchain for CPython `3.13.15`, backed by an integrity-pinned python-build-standalone `install_only` artifact. Package the toolchain runtime files into an OCI layer under a stable prefix, with `/usr/bin/python` and `/usr/bin/python3` aliases.

Using the Debian `python3.13` packages was rejected because their patch release is controlled by Debian. Maintaining a custom CPython source build was rejected because it duplicates a maintained hermetic distribution and substantially increases build time and patching responsibility.

The image will not set `PYTHONHOME`; CPython will determine its prefix from its installed layout, which preserves venv behavior. It will set `LANG=C.UTF-8`, `PYTHONUNBUFFERED=1`, `PYTHONDONTWRITEBYTECODE=1`, and a `PATH` containing the Python and Java executable directories.

### Use Debian OpenJDK 21 headless as the supporting JVM

Install the pinned Debian 13 `openjdk-21-jre-headless` dependency closure and expose the distribution's stable default-JVM symlink as `JAVA_HOME`. Java 21 satisfies the requested Java 17+ floor and avoids adding a second independently sourced archive.

A custom `jlink` runtime was rejected for the first version because Apache POI and JPype compatibility is more valuable than shaving modules before measuring image size. A Java 17-only runtime was rejected because Debian 13's native LTS runtime is Java 21.

### Keep PEM trust isolated from Java

Create `/etc/certs` as an empty, world-readable directory and set `SSL_CERT_DIR=/etc/certs`. The downstream contract permits only PEM certificate files there. The image will neither run `keytool` nor set `javax.net.ssl.trustStore`; any default `cacerts` shipped as part of OpenJDK is left untouched.

The smoke fixture will add a PEM certificate in a derived image and verify Python-side discovery. Runtime certificate conversion was rejected because a distroless image has no startup shell and because the user explicitly does not need Java TLS trust management.

### Publish one OCI target and one Docker load target

The primary Bazel target will be an `oci_image`. An `oci_tarball`/load target will give Docker a local tag for downstream `FROM` usage. Registry authentication, repository naming, and push policy remain deployment concerns; the loaded image can use normal `docker tag` and `docker push` commands.

### Verify the actual container boundary

Add one host-side smoke script that builds/loads the image and uses explicit `docker run --entrypoint ...` calls. It will check exact Python and Java versions, representative native imports, `JAVA_HOME` plus `libjvm.so` loading, certificate variables/content, non-root execution, and the lack of shell/package-manager paths. This is smaller and more representative than a custom test framework.

## Risks / Trade-offs

- [python-build-standalone native libraries differ from Debian's Python build] → Exercise the native modules used by real workloads and document the exact distribution variant.
- [Debian OpenJDK dependencies increase image size] → Start with `openjdk-21-jre-headless`; consider `jlink` only after size measurement identifies it as worthwhile.
- [A moving Debian repository would break reproducibility] → Resolve packages from a dated snapshot and keep generated locks/checksums under source control.
- [The static base alone cannot run dynamic CPython or Java] → Include and test the complete shared-library closures in dedicated layers.
- [PEM directories have library-specific discovery rules] → Set `SSL_CERT_DIR` and test the supported Wassima-based access pattern with a real PEM fixture; do not promise transparent Java trust.
- [Docker-based smoke tests require a local daemon] → Keep image assembly independently buildable and make the single runtime smoke target explicit for CI environments with Docker.
- [Initial output is amd64-only] → Add an OCI index and per-architecture runtime/package selections only when an arm64 consumer is required.

## Migration Plan

1. Replace the current invalid macro and dependency declarations with the pinned layer assembly and image/load targets.
2. Build and run the smoke target locally against the Docker daemon.
3. Load the image under a temporary tag and validate one downstream Dockerfile containing the existing Python/JPype/POI workload.
4. Tag and push the validated image to the target registry.
5. Roll back by restoring the previous downstream base-image reference; registry tags for the new image must not overwrite the last known-good digest during validation.
