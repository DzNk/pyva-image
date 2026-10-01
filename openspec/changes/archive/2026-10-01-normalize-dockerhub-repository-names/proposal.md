# Proposal

## Why

The main spec accepts `docker.io/example/pyva-runtime`, but `release.sh` accepts only `index.docker.io/...`. A documented valid destination is currently rejected before publication.

## What Changes

- Accept both explicit Docker Hub host spellings and normalize them once to the existing canonical form.
- Keep explicit namespace/repository and reject foreign hosts, schemes, tags, digests and malformed paths before building or uploading.
- Use the normalized reference consistently for push, pull, verification and success output.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dockerhub-image-publication`: Align the caller-selected destination contract with both Docker Hub host aliases and fail-fast validation.

## Impact

Changes `release.sh`, README and a small offline validation check. Preserve external Docker-compatible authentication; no implicit host expansion, credentials in files or support for other registries. Coordinate with other release-file changes; normalize before digest lookup.
