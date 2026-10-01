# Spec Delta

## MODIFIED Requirements

### Requirement: Embedded Java runtime for JPype
The image SHALL include a headless Java 21 runtime matching its target architecture, expose a valid `JAVA_HOME`, make `java` available on `PATH`, and provide a loadable server JVM shared library for in-process use by Python on both `linux/amd64` and `linux/arm64`.

#### Scenario: Inspect the Java runtime
- **WHEN** a process executes `java -version` in either platform image
- **THEN** the command succeeds and reports Java major version 21

#### Scenario: Load the JVM from Python
- **WHEN** Python resolves the server JVM library beneath `JAVA_HOME` and loads it through `ctypes` on either platform
- **THEN** the library and all of its required shared-library dependencies load successfully

### Requirement: Distroless runtime boundary
The runtime image SHALL be based on Debian 13 userspace, support `linux/amd64` and `linux/arm64`, run as a non-root user by default, and contain neither a shell nor an operating-system package manager. Each platform image SHALL contain matching-architecture CPython, JVM and native shared libraries.

#### Scenario: Inspect prohibited runtime tools
- **WHEN** either final platform image filesystem is inspected
- **THEN** `/bin/sh`, `apt`, `apt-get`, and `dpkg` executables are absent

#### Scenario: Inspect the default identity
- **WHEN** either platform image starts without a user override
- **THEN** its primary process runs as a non-root UID

#### Scenario: Inspect platform consistency
- **WHEN** an amd64 or arm64 image is executed on a compatible runner
- **THEN** its OCI platform and reported machine architecture agree and both Python and Java execute successfully

### Requirement: Docker-compatible delivery
The build SHALL produce standards-compliant OCI images for both platforms and a separate Docker-loadable archive for each, which downstream Dockerfiles can extend with code, Python packages, JARs, and PEM certificates. Existing amd64 archive/load commands SHALL remain usable.

#### Scenario: Extend and run the image
- **WHEN** a consumer loads either architecture's archive, uses the resulting image in a Docker `FROM` instruction, copies an application into `/app`, and starts a Python script on a compatible runner
- **THEN** the script runs with the bundled Python runtime and can discover the bundled JVM

#### Scenario: Use an existing amd64 load command
- **WHEN** a consumer invokes an existing Python-minor load command without selecting an architecture
- **THEN** it still loads that minor's amd64 image under its existing local tags
