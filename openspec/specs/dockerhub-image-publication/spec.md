# dockerhub-image-publication Specification

## Purpose

Define a reproducible and credential-safe release contract for publishing the verified Python/JVM runtime image to a caller-selected Docker Hub repository.

## Requirements

### Requirement: Caller-selected Docker Hub destination
The publication flow SHALL accept either `docker.io/<namespace>/<repository>` or `index.docker.io/<namespace>/<repository>` at release time, normalize both to one canonical Docker Hub destination before build or publication, and SHALL NOT store a Docker Hub account name, access token or password in tracked project files. Destinations SHALL include exactly one nonempty namespace and repository using valid lowercase Docker repository components, without a URL scheme, tag, digest, whitespace or additional path components. Other hosts SHALL be rejected before build or upload.

#### Scenario: Publish to a selected namespace
- **WHEN** an authenticated publisher supplies `docker.io/example/pyva-runtime`
- **THEN** the release is pushed to that repository without modifying project source files

#### Scenario: Reject a missing destination
- **WHEN** publication is requested without a Docker Hub repository
- **THEN** the flow fails before uploading any image content

#### Scenario: Accept the canonical host spelling
- **WHEN** the publisher supplies `index.docker.io/example/pyva-runtime`
- **THEN** push, pull, digest verification and success output use the same canonical destination as the `docker.io` alias

#### Scenario: Reject malformed or foreign destinations
- **WHEN** the destination uses a foreign host, URL scheme, missing path component, tag, digest, whitespace or additional path component
- **THEN** the flow rejects the input before building or uploading an image

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

### Requirement: OCI publication metadata
The published image SHALL expose OCI annotations describing its title, description, runtime version, source revision when supplied, and source repository when supplied, while preserving the existing entrypoint, environment, user, and filesystem layers.

#### Scenario: Inspect a published manifest
- **WHEN** a consumer inspects the immutable Docker Hub tag
- **THEN** the manifest reports the Python/JVM/Debian runtime identity and any supplied source provenance

### Requirement: Verified publication gate
The release flow SHALL run the base runtime smoke check and the Apache POI through JPype integration check before upload, and SHALL stop without pushing when either check fails.

#### Scenario: Successful release validation
- **WHEN** both smoke checks pass for the exact image selected for publication
- **THEN** the release flow permits that image to be pushed

#### Scenario: Failed release validation
- **WHEN** either smoke check fails
- **THEN** no release tag is uploaded or updated

### Requirement: Post-publication pull verification
After upload, the release flow SHALL pull the immutable tag from Docker Hub, verify that it targets `linux/amd64`, and run the base runtime smoke assertions against the pulled image.

#### Scenario: Verify a published release
- **WHEN** Docker Hub accepts the immutable release tag
- **THEN** the pulled image passes the runtime checks and its registry digest is reported to the publisher

### Requirement: Documented downstream consumption
The project SHALL document authentication, publication, pull, and `FROM` examples using the immutable tag, with credentials supplied through Docker-compatible external authentication.

#### Scenario: Follow the release documentation
- **WHEN** a publisher has a Docker Hub repository and valid external credentials
- **THEN** the documented commands publish and verify the image without placing credentials in the repository

### Requirement: Python minor release selection
The publication flow SHALL require the publisher to select a supported Python minor and SHALL publish and verify the matching built image without changing the other minor's release tags.

#### Scenario: Release a supported Python variant
- **WHEN** the publisher selects `3.14`
- **THEN** the flow validates, publishes, pulls, and verifies the Python `3.14` image variant

#### Scenario: Reject an unsupported Python variant
- **WHEN** the publisher supplies a Python minor other than `3.13` or `3.14`
- **THEN** the flow fails before uploading any image content
