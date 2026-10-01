# Spec Delta

## MODIFIED Requirements

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
