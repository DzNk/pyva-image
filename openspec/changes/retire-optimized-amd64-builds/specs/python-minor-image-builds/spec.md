# Spec Delta

## MODIFIED Requirements

### Requirement: Supported Python minor builds
The build SHALL expose Python `3.13` and `3.14` with Java `21` and `25` for baseline `linux/amd64` and `linux/arm64`. A caller SHALL select Python by minor, Java by major, and the platform by architecture. Omission of the Java major SHALL continue to select Java 21. Build and load targets SHALL cover only these platform selections.

#### Scenario: Build every supported Python line
- **WHEN** the complete runtime image set is built
- **THEN** it contains eight platform images and four two-platform OCI indexes, one index per Python and Java pair

#### Scenario: Keep both Java variants loaded
- **WHEN** both Java majors of the same Python minor and architecture are loaded
- **THEN** the existing Java 21 aliases and the separate Java 25 aliases resolve to their respective images

### Requirement: Latest stable Astral patch
The resolver SHALL use the selected latest Astral release metadata and select the highest stable patch for each supported minor from its supported platform records. It SHALL require and save the GIL-enabled `install_only_stripped` archive URLs and SHA-256 checksums for baseline `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` for that patch. Generated Bazel inputs SHALL preserve the exact selection. A missing required artifact SHALL fail the update without choosing an older patch or changing the previous pins.

#### Scenario: Resolve a minor-only version
- **WHEN** the selected Astral release contains complete baseline archives for the highest stable patch of a supported minor
- **THEN** it saves the two baseline archive URLs and checksums for that patch, regardless of availability of CPU-specific artifacts

#### Scenario: Ignore optimized artifacts for a newer patch
- **WHEN** a newer patch appears only in optimized x86-64 archives
- **THEN** it does not participate in supported baseline patch selection

#### Scenario: Rebuild without a catalog update
- **WHEN** a supported variant is rebuilt from the same saved inputs and dependency lock
- **THEN** it uses the same resolved interpreter artifacts

#### Scenario: Ignore newer built-in catalog versions
- **WHEN** the build dependency contains a newer Python patch than the saved Astral selection
- **THEN** every supported platform variant uses the exact saved patch without a new version lookup

#### Scenario: Override a conflicting artifact
- **WHEN** the built-in catalog contains the same Python patch and platform with a different URL or checksum
- **THEN** the build uses the saved Astral URL and checksum

#### Scenario: Reject incomplete saved input
- **WHEN** a selected baseline record is missing, malformed or fails integrity verification
- **THEN** the update or build fails before substituting built-in runtime data

#### Scenario: Reject a highest patch missing one platform
- **WHEN** the highest stable patch has a baseline record for only one required architecture and an older patch has both
- **THEN** the update fails and preserves the previous pins

### Requirement: amd64 and arm64 image variants
Each supported Python and Java pair SHALL provide one `linux/amd64` image using the `x86_64-unknown-linux-gnu` interpreter and one `linux/arm64` image using the `aarch64-unknown-linux-gnu` interpreter. Every image for a Python minor SHALL use its exact saved CPython patch.

#### Scenario: Inspect each built variant
- **WHEN** the complete matrix is inspected
- **THEN** each pair contains exactly one image per supported architecture with matching Python and Java versions

### Requirement: Stripped Python runtime artifacts
Each Linux runtime SHALL use the checksum-verified, stable GIL-enabled `install_only_stripped` archive for its saved Astral patch and architecture. Updating SHALL fail before substituting an unstripped, prerelease, free-threaded, optimized CPU or other-platform archive.

#### Scenario: Update both stripped variants
- **WHEN** the selected release supplies stripped baseline archives for both architectures of Python 3.13 and 3.14
- **THEN** all four saved inputs record their immutable URLs and SHA-256 checksums

#### Scenario: Missing stripped artifact
- **WHEN** a selected patch lacks a required stripped baseline archive
- **THEN** the update fails and preserves the previous pins

## REMOVED Requirements

### Requirement: Explicit optimized CPU selection
**Reason** — `amd64-v2` and `amd64-v3` builds are retired.
**Migration** — Select baseline `amd64` or the multi-platform family tag.

### Requirement: CPU-compatible runtime validation
**Reason** — All active `amd64` images use the baseline interpreter.
**Migration** — Use the runtime and POI checks on both supported architectures.
