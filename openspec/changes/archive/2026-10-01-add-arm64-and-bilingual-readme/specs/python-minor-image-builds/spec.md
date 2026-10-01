# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: x86_64-only image variants`
- TO: `### Requirement: amd64 and arm64 image variants`

## MODIFIED Requirements

### Requirement: Supported Python minor builds
The build SHALL expose separate runtime image variants for Python `3.13` and `3.14` on both `linux/amd64` and `linux/arm64`. Each variant SHALL be selected by its `major.minor` value and architecture without requiring callers to provide a patch, Astral release date, download URL, or checksum.

#### Scenario: Build every supported Python line
- **WHEN** the complete runtime image set is built
- **THEN** it contains four images, covering both Python minors on both platforms

### Requirement: Latest stable Astral patch
The version resolver SHALL select the highest stable patch release for each supported minor solely from the explicitly selected latest Astral `python-build-standalone` release metadata and SHALL save matching GIL-enabled `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` install-only archive URLs and SHA-256 checksums for that same patch. Generated Bazel inputs SHALL preserve the exact saved versions, URLs and checksums until the resolver is deliberately run again; built-in catalogs SHALL NOT substitute a different version or artifact. Missing either architecture's required artifact for the highest patch SHALL fail the update without selecting an older patch or changing the previous saved inputs.

#### Scenario: Resolve a minor-only version
- **WHEN** Astral publishes a latest release containing stable `3.14` assets and the resolver runs
- **THEN** it selects the highest stable `3.14.x` and saves both architecture artifacts for that patch

#### Scenario: Rebuild without a catalog update
- **WHEN** a supported variant is rebuilt from the same generated Bazel inputs and dependency lock
- **THEN** it uses the same resolved interpreter artifacts

#### Scenario: Ignore newer built-in catalog versions
- **WHEN** the build dependency contains a newer Python patch than the saved Astral selection
- **THEN** every supported platform variant still uses the exact saved Astral patch without a new network lookup

#### Scenario: Override a conflicting artifact
- **WHEN** the built-in catalog contains the same Python patch and platform but a different archive URL or checksum
- **THEN** the build uses the saved Astral URL and checksum for that platform

#### Scenario: Reject incomplete saved input
- **WHEN** a supported minor's selected architecture record is missing, malformed or fails integrity verification
- **THEN** the update or build fails without silently substituting built-in runtime data

#### Scenario: Reject a highest patch missing one platform
- **WHEN** the highest stable patch in the selected release lacks a required artifact for one architecture but an older patch has both
- **THEN** the update fails and leaves all previously saved inputs unchanged

### Requirement: amd64 and arm64 image variants
Every supported Python minor SHALL provide a `linux/amd64` image using the `x86_64-unknown-linux-gnu` interpreter and a `linux/arm64` image using the `aarch64-unknown-linux-gnu` interpreter. Both architectures of a minor SHALL use the same exact CPython patch.

#### Scenario: Inspect each built variant
- **WHEN** platform metadata of the four built images is inspected
- **THEN** each minor has exactly one amd64 and one arm64 image with matching Python patch identity

### Requirement: Stripped Python runtime artifacts
Each supported runtime image SHALL use the stable GIL-enabled `install_only_stripped` artifact for its saved Astral-selected patch and target GNU Linux architecture, verified against the tagged release checksum. Updating that selection SHALL fail rather than silently substitute an unstripped archive, a prerelease, a free-threaded build or another platform.

#### Scenario: Update both stripped variants
- **WHEN** the selected Astral release supplies matching stripped archives for both architectures of Python `3.13` and `3.14`
- **THEN** all four saved runtime inputs identify their stripped immutable URLs and checksums

#### Scenario: Missing stripped artifact
- **WHEN** a supported minor's selected patch has no matching stripped archive on either architecture in the selected release
- **THEN** the update fails and leaves the previous saved runtime input unchanged

### Requirement: Stripped runtime compatibility
All four stripped image variants SHALL retain the exact saved Python patch identity, standard-library native imports and working Java 21/JPype/POI integration. Each architecture's stripped Python layer SHALL be smaller than an unstripped baseline for the same patch and packaging configuration, verified by measuring both layer sizes.

#### Scenario: Verify each stripped image
- **WHEN** runtime smoke and POI checks run against any supported minor/platform variant
- **THEN** the checks pass, the runtime version matches OCI metadata, and its Python layer is smaller than its equivalent unstripped baseline
