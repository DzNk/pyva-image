# Spec Delta

## MODIFIED Requirements

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
