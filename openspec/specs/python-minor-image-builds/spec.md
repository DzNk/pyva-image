# python-minor-image-builds Specification

## Purpose

Define version-selectable Python/JVM image builds that resolve the latest available stable Astral patch release for each supported CPython minor line on x86_64.

## Requirements

### Requirement: Supported Python minor builds
The build SHALL expose separate runtime image variants for Python `3.13` and `3.14`, and each variant SHALL be selected by its `major.minor` value without requiring callers to provide a patch, Astral release date, download URL, or checksum.

#### Scenario: Build every supported Python line
- **WHEN** the complete runtime image set is built
- **THEN** it contains one Python `3.13` image and one Python `3.14` image

### Requirement: Latest stable Astral patch
The version resolver SHALL select the highest stable patch release for each supported minor solely from the explicitly selected latest Astral `python-build-standalone` release metadata and SHALL save its matching GIL-enabled `x86_64-unknown-linux-gnu` install-only archive URL and SHA-256 checksum. Generated Bazel inputs SHALL preserve the exact saved version, URL and checksum until the resolver is deliberately run again; built-in catalogs SHALL NOT substitute a different version or artifact.

#### Scenario: Resolve a minor-only version
- **WHEN** Astral publishes a latest release containing stable `3.14` assets and the resolver runs
- **THEN** its interpreter input is the highest stable `3.14.x` asset for `x86_64-unknown-linux-gnu` in that release

#### Scenario: Rebuild without a catalog update
- **WHEN** a supported variant is rebuilt from the same generated Bazel inputs and dependency lock
- **THEN** it uses the same resolved interpreter artifacts

#### Scenario: Ignore newer built-in catalog versions
- **WHEN** the build dependency contains a newer Python patch than the saved Astral selection
- **THEN** the supported variant still uses the exact saved Astral patch without a new network lookup

#### Scenario: Override a conflicting artifact
- **WHEN** the built-in catalog contains the same Python patch and platform but a different archive URL or checksum
- **THEN** the build uses the saved Astral URL and checksum

#### Scenario: Reject incomplete saved input
- **WHEN** a supported minor's selected record is missing, malformed or fails integrity verification
- **THEN** the update or build fails without silently substituting built-in runtime data

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

### Requirement: Stripped Python runtime artifacts
Each supported runtime image SHALL use the stable GIL-enabled `x86_64-unknown-linux-gnu` `install_only_stripped` artifact for its saved Astral-selected patch, verified against the tagged release checksum. Updating that selection SHALL fail rather than silently substitute an unstripped archive, a prerelease, a free-threaded build or another platform.

#### Scenario: Update both stripped variants
- **WHEN** the selected Astral release supplies matching stripped archives for Python `3.13` and `3.14`
- **THEN** each saved runtime input identifies its stripped immutable URL and checksum

#### Scenario: Missing stripped artifact
- **WHEN** a supported minor has no matching stripped archive in the selected release
- **THEN** the update fails and leaves the previous saved runtime input unchanged

### Requirement: Stripped runtime compatibility
Both stripped image variants SHALL retain the exact saved Python patch identity, standard-library native imports and working Java 21/JPype/POI integration. The before-and-after Python layer size SHALL be measured for the same patch and packaging configuration.

#### Scenario: Verify each stripped image
- **WHEN** the runtime smoke and POI checks run against either stripped variant
- **THEN** the checks pass, the runtime version matches OCI metadata, and the Python layer is smaller than its equivalent unstripped baseline
