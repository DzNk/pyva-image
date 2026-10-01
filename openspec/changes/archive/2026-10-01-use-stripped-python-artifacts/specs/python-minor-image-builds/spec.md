# Spec Delta

## ADDED Requirements

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
