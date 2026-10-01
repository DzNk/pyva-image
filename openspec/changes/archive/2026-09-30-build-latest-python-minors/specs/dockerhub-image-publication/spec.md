# Spec Delta

## MODIFIED Requirements

### Requirement: Versioned release tags
For each supported Python `X.Y` image variant, the release flow SHALL publish the immutable tag `X.Y.Z-java21-debian13` for its resolved interpreter and SHALL allow the publisher to explicitly add the moving channel tag `X.Y-java21-debian13`; no global `latest` tag or other floating tag SHALL be published implicitly.

#### Scenario: Publish an immutable runtime tag
- **WHEN** a resolved Python `3.13.x` or `3.14.x` image is released
- **THEN** Docker Hub exposes its `X.Y.Z-java21-debian13` tag

#### Scenario: Publish a selected minor channel
- **WHEN** the publisher requests the moving channel for a supported Python minor
- **THEN** Docker Hub updates only that minor's `X.Y-java21-debian13` tag to the verified immutable image

#### Scenario: Omit an unrequested channel update
- **WHEN** the publisher does not request a moving channel tag
- **THEN** publication leaves all minor channel tags unchanged

## ADDED Requirements

### Requirement: Python minor release selection
The publication flow SHALL require the publisher to select a supported Python minor and SHALL publish and verify the matching built image without changing the other minor's release tags.

#### Scenario: Release a supported Python variant
- **WHEN** the publisher selects `3.14`
- **THEN** the flow validates, publishes, pulls, and verifies the Python `3.14` image variant

#### Scenario: Reject an unsupported Python variant
- **WHEN** the publisher supplies a Python minor other than `3.13` or `3.14`
- **THEN** the flow fails before uploading any image content
