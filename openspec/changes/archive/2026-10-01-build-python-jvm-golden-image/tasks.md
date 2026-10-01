# Tasks

## 1. Pin Build Inputs

- [x] 1.1 Replace the current Bzlmod declarations with compatible pinned `rules_oci`, `rules_python`, `rules_distroless`, and packaging dependencies; register only CPython 3.13.15 for `linux/amd64`, and verify `bazel mod graph` resolves with an updated lockfile.
- [x] 1.2 Declare `static-debian13` by immutable digest and configure the Debian 13 UsrMerge package resolver against a dated snapshot for `openjdk-21-jre-headless`; verify the resolved inputs contain no floating image tag or Debian mirror reference.

## 2. Build Runtime Layers

- [x] 2.1 Replace the invalid `pyva.bzl` sketch with the minimum valid targets needed to package the integrity-pinned rules_python runtime, its standard library/native files, and `/usr/bin/python{,3}` aliases; verify the Python layer builds and contains the selected interpreter paths.
- [x] 2.2 Build the OpenJDK 21 headless layer and its Debian shared-library closure, preserving the default-JVM symlink; verify the layer contains `java`, a valid `JAVA_HOME`, and `lib/server/libjvm.so`.
- [x] 2.3 Build the metadata layer with `/app`, empty `/etc/certs`, non-root ownership, and the required Python/JVM environment variables while leaving Java trust-store settings unset; verify the layer manifest records the expected paths, modes, UID/GID, and environment values.

## 3. Assemble and Exercise the Image

- [x] 3.1 Assemble the pinned base and runtime layers into a Python-entrypoint `oci_image` plus a Docker-loadable target; verify Bazel builds both artifacts and Docker loads the archive under a local tag.
- [x] 3.2 Add one host-side Docker smoke check and PEM fixture covering exact Python/Java versions, native Python imports, Python loading `libjvm.so`, PEM discovery, non-root execution, and absence of shell/package-manager executables; verify the smoke command passes end to end.
- [x] 3.3 Document the exact version update point and a minimal downstream Dockerfile that adds a venv/site-packages, code, POI JARs, and PEM files before running Python; verify the documented build and run commands work against the locally loaded image.
