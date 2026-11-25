# Spec Delta

## MODIFIED Requirements

### Requirement: Supported Python minor builds
The build SHALL expose Python `3.13` and `3.14` runtimes with Java `21` and `25` on both `linux/amd64` and `linux/arm64`. A variant SHALL be selected by Python minor, Java major and architecture without supplying a patch, release date, URL or checksum. Existing selectors that omit the Java major SHALL select Java 21.

#### Scenario: Build every supported Python line
- **WHEN** the complete runtime image set is built
- **THEN** it contains eight platform images and four two-platform OCI indexes, one per Python and Java pair

#### Scenario: Keep both Java variants loaded
- **WHEN** a maintainer loads the same Python minor and architecture with both Java selections
- **THEN** the Java 21 variant retains its local tags and the Java 25 variant is separately addressable through its Java-qualified tags

### Requirement: amd64 and arm64 image variants
Every supported Python and Java pair SHALL provide a `linux/amd64` image using the `x86_64-unknown-linux-gnu` interpreter and a `linux/arm64` image using the `aarch64-unknown-linux-gnu` interpreter. All variants of a Python minor SHALL use the same exact CPython patch.

#### Scenario: Inspect each built variant
- **WHEN** the complete matrix of built images is inspected
- **THEN** each Python and Java pair has exactly one amd64 and one arm64 image with matching Python patch and Java release identity

### Requirement: Stripped runtime compatibility
All eight stripped image variants SHALL retain the exact saved Python patch identity, standard-library native imports and working JPype/POI integration with the selected Java major. Each architecture's stripped Python layer SHALL be smaller than an unstripped baseline for the same patch and packaging configuration, verified by measuring both layer sizes.

#### Scenario: Verify each stripped image
- **WHEN** runtime smoke and POI checks run against any supported Python, Java and platform combination
- **THEN** the checks pass, the runtime versions match OCI metadata, and the Python layer is smaller than its equivalent unstripped baseline
