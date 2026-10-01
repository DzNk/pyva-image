# Spec Delta

## Purpose

Define version-selectable Python/JVM image builds that resolve the latest available stable Astral patch release for each supported CPython minor line on x86_64.

## ADDED Requirements

### Requirement: Supported Python minor builds
The build SHALL expose separate runtime image variants for Python `3.13` and `3.14`, and each variant SHALL be selected by its `major.minor` value without requiring callers to provide a patch, Astral release date, download URL, or checksum.

#### Scenario: Build every supported Python line
- **WHEN** the complete runtime image set is built
- **THEN** it contains one Python `3.13` image and one Python `3.14` image

### Requirement: Latest stable Astral patch
The version resolver SHALL select the highest stable patch release for each supported minor from Astral's latest `python-build-standalone` release metadata and SHALL identify its matching `x86_64-unknown-linux-gnu` install-only archive and SHA-256 checksum. The generated Bazel inputs SHALL preserve that selection until the resolver is deliberately run again.

#### Scenario: Resolve a minor-only version
- **WHEN** Astral publishes a latest release containing stable `3.14` assets and the resolver runs
- **THEN** its interpreter input is the highest stable `3.14.x` asset for `x86_64-unknown-linux-gnu` in that release

#### Scenario: Rebuild without a catalog update
- **WHEN** a supported variant is rebuilt from the same generated Bazel inputs and dependency lock
- **THEN** it uses the same resolved interpreter artifacts

### Requirement: x86_64-only image variants
Every supported Python image variant SHALL use the `x86_64-unknown-linux-gnu` interpreter build and SHALL produce a `linux/amd64` OCI image.

#### Scenario: Inspect each built variant
- **WHEN** the platform metadata of the `3.13` and `3.14` images is inspected
- **THEN** each image reports `linux/amd64`

### Requirement: Resolved Python version identity
Each image SHALL run the resolved `X.Y.Z` interpreter and SHALL expose that exact version in its OCI metadata and immutable release identity.

#### Scenario: Compare runtime and metadata versions
- **WHEN** a built image reports its Python version and its OCI metadata is inspected
- **THEN** both identify the same resolved `X.Y.Z` release
