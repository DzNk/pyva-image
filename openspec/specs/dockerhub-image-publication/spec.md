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
For each supported Python `X.Y` variant, the release flow SHALL publish one OCI image index containing exactly `linux/amd64` and `linux/arm64` under the immutable tag `X.Y.Z-java21-debian13-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>`. The Python patch SHALL be shared by both platforms; the timestamp SHALL be the release source Git commit's committer time formatted in UTC, and the SHA SHALL be that commit's full hexadecimal id. The release SHALL use a clean checkout of that commit and SHALL NOT derive identity from the current clock. The publisher SHALL be able to explicitly add the moving channel tag `X.Y-java21-debian13` pointing to the verified index only after both immutable-platform pull checks pass; no global `latest` tag or other floating tag SHALL be published implicitly. Existing undated immutable tags SHALL remain unchanged.

#### Scenario: Publish an immutable runtime tag
- **WHEN** a resolved Python `3.13.x` or `3.14.x` image set is released
- **THEN** Docker Hub exposes its dated, commit-qualified immutable tag as an index with both platform manifests

#### Scenario: Publish a selected minor channel
- **WHEN** the publisher requests the moving channel for a supported Python minor
- **THEN** Docker Hub updates only that minor's `X.Y-java21-debian13` tag after both immutable-platform pull checks pass and verifies that it resolves to the same index digest

#### Scenario: Omit an unrequested channel update
- **WHEN** the publisher does not request a moving channel tag
- **THEN** publication leaves all minor channel tags unchanged

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

### Requirement: OCI publication metadata
The published image SHALL expose OCI annotations describing its title, description, runtime version, source revision when supplied, and source repository when supplied, while preserving the existing entrypoint, environment, user, and filesystem layers.

#### Scenario: Inspect a published manifest
- **WHEN** a consumer inspects the immutable Docker Hub tag
- **THEN** the manifest reports the Python/JVM/Debian runtime identity and any supplied source provenance

### Requirement: Verified publication gate
The release flow SHALL run the base runtime smoke check and Apache POI through JPype integration check on both exact platform images selected for publication before upload. It SHALL verify that both images carry the same resolved Python version and SHALL stop without pushing when any check fails or a platform cannot be executed. Metadata inspection alone SHALL NOT replace runtime execution.

#### Scenario: Successful release validation
- **WHEN** runtime and POI execution checks pass for both platform images with matching Python identity
- **THEN** the release flow permits their shared index to be pushed

#### Scenario: Failed release validation
- **WHEN** either platform's runtime or POI check fails, or their version identities differ
- **THEN** no release tag is uploaded or updated

#### Scenario: No compatible runner
- **WHEN** the execution environment cannot run one of the required platforms
- **THEN** release fails before upload instead of skipping that platform's checks

### Requirement: Post-publication pull verification
After upload or reuse of an identical existing release, the release flow SHALL inspect the immutable index for exactly `linux/amd64` and `linux/arm64`, verify that its index and platform manifest digests match the validated local candidate, explicitly pull each platform, verify its platform metadata, and run the base runtime smoke assertions against both pulled images. Success output SHALL report the registry digest of the shared index and SHALL NOT be printed if either platform verification fails or a requested channel does not resolve to that index.

#### Scenario: Verify a published release
- **WHEN** Docker Hub accepts the immutable release tag
- **THEN** both pulled platform images pass runtime checks and the shared index digest is reported to the publisher

#### Scenario: Reject incomplete published content
- **WHEN** the remote tag lacks a required platform, has an unexpected platform set, differs from the validated candidate digests, or either pulled image fails runtime checks
- **THEN** the release command fails without reporting successful publication

### Requirement: Documented downstream consumption
The project SHALL provide a compact README with Russian first and English second, visible Python, Java, JPype, Apache POI and Distroless keywords, a brief Python-calls-Java use case, supported Python versions/platforms, non-root and no-shell notes, and one shared minimal `FROM` example. It SHALL state that consumers supply their own Python dependencies and JARs rather than implying that JPype or Apache POI are bundled. Both language sections SHALL explicitly identify `/etc/certs` as the consumer PEM certificate location and `SSL_CERT_DIR=/etc/certs` as the image default; the shared example SHALL include `COPY certs/ /etc/certs/`. Maintainer authentication, publication, pull, build, update, test and rollback procedures and detailed dependency/certificate examples SHALL live in `CONTRIBUTING.md`, linked from README, using immutable tags and external Docker-compatible authentication. README SHALL NOT contain maintainer internals or assert that an unspecified registry repository is already published.

#### Scenario: Read the repository landing page
- **WHEN** a Russian- or English-speaking consumer opens README
- **THEN** the corresponding short section explains the use case, supported runtimes and platforms, what they must add, and where to copy PEM certificates, with a minimal image-use example

#### Scenario: Follow the release documentation
- **WHEN** a publisher has a Docker Hub repository and valid external credentials
- **THEN** the linked maintainer document provides commands to publish and verify both architectures without placing credentials in the repository

### Requirement: Python minor release selection
The publication flow SHALL require the publisher to select a supported Python minor and SHALL publish and verify the matching built image without changing the other minor's release tags.

#### Scenario: Release a supported Python variant
- **WHEN** the publisher selects `3.14`
- **THEN** the flow validates, publishes, pulls, and verifies the Python `3.14` image variant

#### Scenario: Reject an unsupported Python variant
- **WHEN** the publisher supplies a Python minor other than `3.13` or `3.14`
- **THEN** the flow fails before uploading any image content

### Requirement: Immutable registry artifact protection
Before uploading or changing release tags, the release flow SHALL inspect the intended immutable tag and compare its registry digest with the validated local OCI index digest. A confirmed absent tag SHALL permit first publication; an identical existing digest SHALL permit idempotent verification without replacing content. A different existing digest SHALL fail without changing that tag or any channel. Authentication, network and inspection errors SHALL fail and SHALL NOT be treated as evidence that the tag is absent.

#### Scenario: Publish a new release identity
- **WHEN** all validation gates pass and the intended immutable tag is confirmed absent
- **THEN** the candidate index can be uploaded and assigned that new tag

#### Scenario: Retry an identical release
- **WHEN** the intended immutable tag already resolves to the candidate index digest
- **THEN** the release reuses it, performs both pull checks, and updates only an explicitly requested channel after verification

#### Scenario: Reject an immutable tag collision
- **WHEN** the intended immutable tag already resolves to another digest
- **THEN** release fails before any upload or tag mutation and leaves previous artifacts intact

#### Scenario: Fail closed on registry inspection errors
- **WHEN** registry inspection fails through authentication, transport or an unrecognized error
- **THEN** no image is uploaded and no tag changes
