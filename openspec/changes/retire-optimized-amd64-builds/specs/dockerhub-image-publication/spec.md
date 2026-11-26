# Spec Delta

## ADDED Requirements

### Requirement: Retired amd64 publication variants
Actions SHALL publish exactly four runtime indexes from the selected source commit, one per Python and Java pair. Each SHALL contain baseline `linux/amd64` and `linux/arm64`. New releases SHALL neither create nor advance v2/v3 tags. Existing CPU-specific registry references SHALL be preserved.

#### Scenario: Publish the supported matrix
- **WHEN** a trusted main push, scheduled run or manual dispatch reaches publication
- **THEN** it attempts only the four Python and Java pairs and reports successful immutable references and digests

#### Scenario: Use a retired CPU selector
- **WHEN** a caller passes `--cpu` to the release or smoke script
- **THEN** the command rejects the option before building, pulling or publishing

#### Scenario: Consume a previous optimized release
- **WHEN** a consumer pulls an already published CPU-specific tag or digest after a baseline release
- **THEN** the existing reference still identifies the previous artifact

## MODIFIED Requirements

### Requirement: Verified publication gate
The release flow SHALL run the base runtime smoke check and Apache POI through JPype on both exact platform images before upload. It SHALL verify their resolved runtime versions, reject optimized candidates and stop if either platform cannot execute or fails validation. Metadata inspection alone SHALL NOT replace runtime execution.

#### Scenario: Successful release validation
- **WHEN** both baseline platform images pass runtime and POI execution with matching version identities
- **THEN** the flow permits publication of their shared index

#### Scenario: Failed release validation
- **WHEN** either runtime or POI check fails, version identities differ, or a candidate advertises a retired CPU variant
- **THEN** no release tag is uploaded or advanced

#### Scenario: No compatible runner
- **WHEN** either required architecture cannot execute
- **THEN** the release fails before upload

### Requirement: Post-publication pull verification
After uploading or reusing a release, the flow SHALL verify the immutable index for exactly `linux/amd64` and `linux/arm64` and compare the index and platform digests with the local candidate. It SHALL explicitly pull both platforms, check their metadata and execute the runtime assertions. Success output SHALL report the index digest only after both platforms and any requested channel are verified.

#### Scenario: Verify a published release
- **WHEN** Docker Hub accepts the immutable release tag
- **THEN** both pulled platforms pass runtime checks and the release reports the verified index digest

#### Scenario: Reject incomplete published content
- **WHEN** the remote tag lacks either platform, has an unexpected platform set, differs from the validated digests or fails either pull or execution check
- **THEN** publication stops without reporting success or advancing the channel

## REMOVED Requirements

### Requirement: Separate optimized CPU tags
**Reason** — Production of CPU-specific indexes ends.
**Migration** — Use the matching two-platform channel for updates or pin a historical CPU-specific reference.

### Requirement: Automated CPU variant coverage
**Reason** — The runtime publishing matrix covers the four supported Python and Java pairs.
**Migration** — Track the four two-platform results in the workflow summary.

### Requirement: Documented CPU selection
**Reason** — New build and release commands have no optimized CPU selection.
**Migration** — Follow the baseline build and release instructions for the same Python minor and Java major.
