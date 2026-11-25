# Spec Delta

## ADDED Requirements

### Requirement: Minimum Java runtime for publication
The release flow SHALL execute the bundled JVM on each exact candidate platform image before upload and on each pulled platform during verification. The runtime SHALL match the selected pinned stable Temurin version and build. The minimum SHALL be `21.0.13.1` for Java 21 and `25.0.5.1` for Java 25. The check SHALL report the platform, detected version and required minimum.

#### Scenario: Accept the patched runtime
- **WHEN** both platforms report the selected pinned stable Temurin version and build at or above its major's floor
- **THEN** the Java gate passes and the other publication checks still apply

#### Scenario: Reject an older or unverifiable JVM before upload
- **WHEN** either candidate reports `21.0.13` or `25.0.5` with any build number, an older patch, a prerelease, a different major, an unparseable version, or cannot execute Java
- **THEN** the release fails before any upload or tag update and its error reports the failed platform, required minimum, available version details, and CVE-2026-114938 reference

#### Scenario: Reject a runtime version or vendor mismatch
- **WHEN** either candidate meets the minimum but reports a version, build or vendor different from the pinned Temurin release
- **THEN** the release fails before any upload or tag update

#### Scenario: Fail verification of a pulled release
- **WHEN** either pulled platform image fails the Java gate or reports a different version than its validated candidate
- **THEN** the release reports failure and leaves all channel tags unchanged

### Requirement: Publish the runtime matrix from GitHub Actions
The release workflow SHALL build, validate and publish the four Python and Java OCI indexes from a commit on the original repository's default branch. It SHALL run on relevant default-branch pushes and by manual dispatch, then report immutable tags and verified digests for all four pairs.

#### Scenario: Publish all four pairs
- **WHEN** a release workflow succeeds
- **THEN** Docker Hub has separate immutable indexes for Python 3.13 and 3.14 each with Java 21 and 25. Each index contains both verified platforms and the workflow summary identifies its digest

#### Scenario: Retry an incomplete release
- **WHEN** a pair fails validation or publication after another pair has succeeded
- **THEN** the workflow fails and a retry of the same source commit verifies any matching immutable indexes and completes the missing pairs

#### Scenario: Guard registry writes
- **WHEN** release is invoked in a fork or for a non-default branch
- **THEN** the workflow performs no Docker Hub writes

## MODIFIED Requirements

### Requirement: Versioned release tags
Each Python and Java pair SHALL have a two-platform OCI index under `X.Y.Z-java<J>-debian13-YYYYMMDDTHHMMSSZ-g<SHA>`. Both platforms SHALL share the Python patch and Java release. The timestamp SHALL be the source commit's UTC committer time and the SHA SHALL be its full hexadecimal ID. Legacy Java 21 immutable tags SHALL be preserved. The optional channel `X.Y-java<J>-debian13` SHALL point to the verified index for that pair.

#### Scenario: Publish an immutable runtime tag
- **WHEN** a resolved Python `3.13.x` or `3.14.x` image set is released with Java `21` or `25`
- **THEN** Docker Hub exposes its dated, commit-qualified immutable tag as an index with both platform manifests

#### Scenario: Publish a selected minor channel
- **WHEN** the publisher requests the moving channel for a supported Python and Java pair
- **THEN** Docker Hub updates only that pair's `X.Y-java<J>-debian13` tag after both immutable-platform pull checks pass and verifies that it resolves to the same index digest

#### Scenario: Omit an unrequested channel update
- **WHEN** the publisher does not request a moving channel tag
- **THEN** publication leaves all channel tags unchanged and creates no implicit floating tags, including `latest`

#### Scenario: Select the platform automatically
- **WHEN** a consumer uses the shared tag on an amd64 or arm64 Docker host
- **THEN** Docker selects the corresponding platform image without requiring an architecture suffix in the tag

#### Scenario: Repeat a release from unchanged source
- **WHEN** the same clean source commit and saved runtime inputs are built and released again at another wall-clock time
- **THEN** the immutable tag and OCI index digest remain the same

#### Scenario: Change the runtime packaging without a Python patch change
- **WHEN** a new source commit changes runtime packaging while retaining the selected Python patch
- **THEN** it receives a different immutable tag instead of replacing the artifact at the previous tag

#### Scenario: Refuse an uncommitted release
- **WHEN** a release is invoked from a checkout with tracked changes or eligible untracked files
- **THEN** it fails before image upload or tag changes rather than attributing those files to the clean Git commit

#### Scenario: Preserve channels on immutable verification failure
- **WHEN** either published platform fails its pull verification
- **THEN** all channel tags remain unchanged and the release command reports failure

### Requirement: Python minor release selection
The publication flow SHALL require the publisher to select a supported Python minor and SHALL accept an optional selection of Java 21 or 25. Omission of the Java major SHALL select Java 21. It SHALL publish and verify the matching built image and preserve the other pairs' tags.

#### Scenario: Release a supported Python variant
- **WHEN** the publisher selects `3.14`
- **THEN** the flow validates, publishes, pulls, and verifies the Python `3.14` image variant with Java 21

#### Scenario: Reject an unsupported Python variant
- **WHEN** the publisher supplies a Python minor other than `3.13` or `3.14`
- **THEN** the flow fails before uploading any image content

#### Scenario: Release a different Java major
- **WHEN** the publisher selects Python `3.14` and Java `25`
- **THEN** the flow validates, publishes, pulls and verifies the Python `3.14` and Java `25` image pair

#### Scenario: Reject an unsupported Java major
- **WHEN** the publisher supplies a Java major other than `21` or `25`
- **THEN** the flow fails before uploading any image content
