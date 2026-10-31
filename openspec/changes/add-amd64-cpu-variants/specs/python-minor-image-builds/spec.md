# Spec Delta

## MODIFIED Requirements

### Requirement: Supported Python minor builds
The build SHALL expose separate runtime image variants for Python `3.13` and `3.14` for baseline `linux/amd64`, `linux/arm64`, `amd64-v2` and `amd64-v3`. Each variant SHALL be selected by its `major.minor` value and architecture/CPU selection without requiring callers to provide a patch, Astral release date, download URL, or checksum.

#### Scenario: Build every supported Python line
- **WHEN** the complete runtime image set is built
- **THEN** it contains eight images, covering both Python minors with baseline amd64, amd64-v2, amd64-v3 and arm64

### Requirement: Latest stable Astral patch
The version resolver SHALL select the highest stable patch release for each supported minor solely from the explicitly selected latest Astral `python-build-standalone` release metadata and SHALL save matching GIL-enabled `x86_64-unknown-linux-gnu`, `x86_64_v2-unknown-linux-gnu`, `x86_64_v3-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` install-only archive URLs and SHA-256 checksums for that same patch. Generated Bazel inputs SHALL preserve the exact saved versions, URLs and checksums until the resolver is deliberately run again; built-in catalogs SHALL NOT substitute a different version or artifact. Missing any required architecture/CPU artifact for the highest patch SHALL fail the update without selecting an older patch or changing the previous saved inputs.

#### Scenario: Resolve a minor-only version
- **WHEN** Astral publishes a latest release containing stable `3.14` assets and the resolver runs
- **THEN** it selects the highest stable `3.14.x` and saves all four architecture/CPU artifacts for that patch

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
- **WHEN** a supported minor's selected architecture/CPU record is missing, malformed or fails integrity verification
- **THEN** the update or build fails without silently substituting built-in runtime data

#### Scenario: Reject a highest patch missing one platform
- **WHEN** the highest stable patch in the selected release lacks a required artifact for one architecture/CPU selection but an older patch has all four
- **THEN** the update fails and leaves all previously saved inputs unchanged

### Requirement: amd64 and arm64 image variants
Every supported Python minor SHALL provide a baseline `linux/amd64` image using the `x86_64-unknown-linux-gnu` interpreter and a `linux/arm64` image using the `aarch64-unknown-linux-gnu` interpreter. Baseline and optimized variants of a minor SHALL use the same exact CPython patch.

#### Scenario: Inspect each built variant
- **WHEN** platform metadata of the four baseline images is inspected
- **THEN** each minor has exactly one baseline amd64 and one arm64 image with matching Python patch identity

### Requirement: Stripped Python runtime artifacts
Each supported runtime image SHALL use the stable GIL-enabled `install_only_stripped` artifact for its saved Astral-selected patch and target GNU Linux architecture/CPU selection, verified against the tagged release checksum. Updating that selection SHALL fail rather than silently substitute an unstripped archive, a prerelease, a free-threaded build, another platform or a baseline interpreter substituted for v2/v3.

#### Scenario: Update both stripped variants
- **WHEN** the selected Astral release supplies matching stripped archives for all four architecture/CPU selections of Python `3.13` and `3.14`
- **THEN** all eight saved runtime inputs identify their stripped immutable URLs and checksums

#### Scenario: Missing stripped artifact
- **WHEN** a supported minor's selected patch has no matching stripped archive for any required architecture/CPU selection in the selected release
- **THEN** the update fails and leaves the previous saved runtime input unchanged

### Requirement: Stripped runtime compatibility
All eight stripped image variants SHALL retain the exact saved Python patch identity, standard-library native imports and working Java 21/JPype/POI integration. Each architecture/CPU selection's stripped Python layer SHALL be smaller than an unstripped baseline for the same patch, CPU selection and packaging configuration, verified by measuring both layer sizes.

#### Scenario: Verify each stripped image
- **WHEN** runtime smoke and POI checks run against any supported minor/platform/CPU variant
- **THEN** the checks pass on a CPU compatible with the selected variant, the runtime version matches OCI metadata, and its Python layer is smaller than its equivalent unstripped baseline

## ADDED Requirements

### Requirement: Explicit optimized CPU selection
The build SHALL expose amd64-v2 and amd64-v3 CPython only through explicit variant selection, preserving existing baseline build/load aliases and build-host interpreter selection. Each optimized image SHALL use its matching saved Astral artifact, retain `linux/amd64` architecture, and expose `io.pyva.cpu.variant` as `v2` or `v3`. CPU-specific loaders SHALL NOT overwrite baseline local aliases.

#### Scenario: Build an optimized runtime
- **WHEN** a caller explicitly selects Python 3.14 with amd64-v3
- **THEN** the image contains the saved x86_64_v3 interpreter for that patch, reports the v3 CPU requirement, and retains the amd64 Java/library paths

#### Scenario: Preserve existing defaults
- **WHEN** a caller uses an existing build/load command without CPU selection or runs a host build tool
- **THEN** the same baseline target or configured host interpreter is selected, without automatic use of v2/v3

#### Scenario: Reject a substituted baseline runtime
- **WHEN** an optimized candidate uses the baseline archive or its CPU metadata disagrees with the selected variant
- **THEN** validation rejects the candidate rather than treating a baseline image as an optimized release

### Requirement: CPU-compatible runtime validation
Each optimized image SHALL pass the existing runtime, native-library, Java, JPype/POI, non-root, certificate and installer-exclusion contracts on a CPU supporting its advertised x86-64 level. Validation SHALL record the runner's required CPU capabilities and SHALL fail if it cannot execute the selected variant; unsupported execution SHALL NOT become a skipped success.

#### Scenario: Validate optimized images
- **WHEN** amd64-v2 or amd64-v3 is validated on a compatible runner
- **THEN** its exact saved Python version, native imports, JVM loading and POI execution pass with the existing runtime filesystem and certificate assertions

#### Scenario: Reject an incompatible validation host
- **WHEN** the runner lacks required capabilities for the selected CPU level
- **THEN** validation fails clearly before publication rather than substituting baseline or skipping execution
