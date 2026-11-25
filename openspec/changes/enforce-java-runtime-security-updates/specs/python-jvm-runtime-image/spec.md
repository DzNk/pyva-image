# Spec Delta

## MODIFIED Requirements

### Requirement: Embedded Java runtime for JPype
Each image SHALL include the selected headless Java 21 or 25 runtime matching its target architecture, expose a valid `JAVA_HOME`, make `java` available on `PATH`, and provide a loadable server JVM shared library for in-process use by Python on both `linux/amd64` and `linux/arm64`.

#### Scenario: Inspect the Java runtime
- **WHEN** a process executes `java -version` in either platform image
- **THEN** the command succeeds and reports the selected Java major

#### Scenario: Load the JVM from Python
- **WHEN** Python resolves the server JVM library beneath `JAVA_HOME` and loads it through `ctypes` on either platform
- **THEN** the library and all of its required shared-library dependencies load successfully

### Requirement: Reproducible runtime inputs
The Debian 13 base, Debian system packages, CPython artifact, Eclipse Temurin JRE, and Bazel rules SHALL be version- or digest-pinned so an unchanged source revision resolves the same runtime inputs. Each Java major SHALL use one Temurin release and build across both Python minors and both architectures, with an architecture-specific URL and verified SHA-256.

#### Scenario: Rebuild without dependency changes
- **WHEN** the image is rebuilt from unchanged source and lock data
- **THEN** the build uses the saved Java archive and SHA-256 for the selected platform, and no runtime dependency is resolved through a floating `latest` reference

#### Scenario: Build the CVE-2026-114938 remediation
- **WHEN** either supported Python minor is built for amd64 or arm64 from the remediation inputs
- **THEN** Java 21 uses `21.0.13.1+2` or a newer pinned compliant release, Java 25 uses `25.0.5.1+2` or a newer pinned compliant release, and the JVM reports the selected version and build

#### Scenario: Preserve runtime paths after the switch to archives
- **WHEN** a consumer discovers Java through `JAVA_HOME` or `/usr/bin/java` in either platform image
- **THEN** both paths resolve to the bundled Temurin runtime under the selected major's architecture-specific Java home. Java 21 retains its existing path. The server JVM and its required system libraries load from the image

#### Scenario: Exercise the bundled runtime on both platforms
- **WHEN** either Python variant starts the JVM through JPype on amd64 or arm64
- **THEN** Java loads its default truststore and Apache POI writes a readable workbook without network access
