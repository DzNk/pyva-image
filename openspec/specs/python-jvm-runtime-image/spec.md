# python-jvm-runtime-image Specification

## Purpose

Define a reproducible, Python-first Debian 13 distroless OCI base image that also supplies a JVM for in-process Java workloads such as Apache POI through JPype.

## Requirements

### Requirement: Exact CPython runtime selection
The build SHALL accept one explicitly pinned CPython `X.Y.Z` version and integrity-verified runtime artifact, and the produced image SHALL report that exact version from both `/usr/bin/python` and `/usr/bin/python3`.

#### Scenario: Build a selected Python patch release
- **WHEN** the image is built with CPython `3.13.15` selected
- **THEN** both Python executable paths report `3.13.15`

#### Scenario: Reject an unverifiable runtime
- **WHEN** the selected runtime artifact is unavailable or fails its integrity check
- **THEN** the build fails without producing a publishable image

### Requirement: Complete Python runtime
The image SHALL contain the CPython standard library, runtime-facing native extension modules, and the shared libraries required to use them without installing operating-system packages at runtime.

#### Scenario: Import representative native modules
- **WHEN** Python imports `ssl`, `ctypes`, `sqlite3`, `bz2`, `lzma`, `uuid`, `readline`, and `multiprocessing`
- **THEN** every import succeeds in the running image

#### Scenario: Use Python as the primary process
- **WHEN** a consumer supplies a Python script as the container command
- **THEN** the configured entrypoint executes that script with `/usr/bin/python3`

### Requirement: Embedded Java runtime for JPype
The image SHALL include a headless Java 21 runtime, expose a valid `JAVA_HOME`, make `java` available on `PATH`, and provide a loadable server JVM shared library for in-process use by Python.

#### Scenario: Inspect the Java runtime
- **WHEN** a process executes `java -version`
- **THEN** the command succeeds and reports Java major version 21

#### Scenario: Load the JVM from Python
- **WHEN** Python resolves the server JVM library beneath `JAVA_HOME` and loads it through `ctypes`
- **THEN** the library and all of its required shared-library dependencies load successfully

### Requirement: Python PEM certificate contract
The image SHALL provide an initially empty `/etc/certs` directory reserved for consumer-supplied PEM certificates and SHALL expose it to Python/OpenSSL through `SSL_CERT_DIR`.

#### Scenario: Run without deployment certificates
- **WHEN** the unextended base image starts
- **THEN** `/etc/certs` exists, contains no preinstalled certificates, and `SSL_CERT_DIR` equals `/etc/certs`

#### Scenario: Add deployment certificates
- **WHEN** a downstream image copies readable PEM certificate files into `/etc/certs`
- **THEN** Python code, including an installed system-trust reader such as Wassima, can enumerate and consume those PEM certificates

### Requirement: No Java trust-store coupling
The image SHALL NOT generate a Java keystore from `/etc/certs`, synchronize consumer PEM files into a Java trust store, or configure `/etc/certs` as the JVM trust store.

#### Scenario: Add Python trust certificates
- **WHEN** PEM certificates are added to `/etc/certs`
- **THEN** the Java trust-store configuration remains unchanged

### Requirement: Distroless runtime boundary
The runtime image SHALL be based on Debian 13 userspace, target `linux/amd64`, run as a non-root user by default, and contain neither a shell nor an operating-system package manager.

#### Scenario: Inspect prohibited runtime tools
- **WHEN** the final image filesystem is inspected
- **THEN** `/bin/sh`, `apt`, `apt-get`, and `dpkg` executables are absent

#### Scenario: Inspect the default identity
- **WHEN** the image starts without a user override
- **THEN** its primary process runs as a non-root UID

### Requirement: Docker-compatible delivery
The build SHALL produce a standards-compliant OCI image and a Docker-loadable archive that downstream Dockerfiles can extend with code, Python packages, JARs, and PEM certificates.

#### Scenario: Extend and run the image
- **WHEN** a consumer loads the archive, uses the resulting image in a Docker `FROM` instruction, copies an application into `/app`, and starts a Python script
- **THEN** the script runs with the bundled Python runtime and can discover the bundled JVM

### Requirement: Reproducible runtime inputs
The Debian 13 base, Debian package set, CPython artifact, JVM major version, and Bazel rules SHALL be version- or digest-pinned so an unchanged source revision resolves the same runtime inputs.

#### Scenario: Rebuild without dependency changes
- **WHEN** the image is rebuilt from unchanged source and lock data
- **THEN** no runtime dependency is resolved through a floating `latest` reference
