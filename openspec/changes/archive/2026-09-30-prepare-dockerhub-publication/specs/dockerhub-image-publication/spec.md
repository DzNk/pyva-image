# Spec Delta

## Purpose

Define a reproducible and credential-safe release contract for publishing the verified Python/JVM runtime image to a caller-selected Docker Hub repository.

## ADDED Requirements

### Requirement: Caller-selected Docker Hub destination
The publication flow SHALL accept a fully qualified Docker Hub repository at release time and SHALL NOT store a Docker Hub account name, access token, or password in tracked project files.

#### Scenario: Publish to a selected namespace
- **WHEN** an authenticated publisher supplies `docker.io/example/pyva-runtime`
- **THEN** the release is pushed to that repository without modifying project source files

#### Scenario: Reject a missing destination
- **WHEN** publication is requested without a Docker Hub repository
- **THEN** the flow fails before uploading any image content

### Requirement: Versioned release tags
Each release SHALL publish the immutable tag `3.13.15-java21-debian13` and SHALL allow the publisher to explicitly add the moving channel tag `3.13-java21-debian13`; no floating tag SHALL be published implicitly.

#### Scenario: Publish an immutable runtime tag
- **WHEN** the current CPython 3.13.15, Java 21, Debian 13 image is released
- **THEN** Docker Hub exposes the tag `3.13.15-java21-debian13`

#### Scenario: Omit an unrequested channel update
- **WHEN** the publisher does not request the moving channel tag
- **THEN** publication leaves `3.13-java21-debian13` unchanged

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
