# Proposal

## Why

`release.sh` separately checks the pulled image platform immediately before calling `smoke_test.sh`, which already validates that same platform and interpreter identity. Two copies add drift without strengthening the gate.

## What Changes

- Delete the redundant release-local platform inspection and conditional.
- Retain mandatory post-pull smoke validation and propagate its failure before reporting publication success.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

Only the duplicate block in `release.sh` and a small offline regression check need changes. Pure refactor with `skip_specs: true`; the existing publication contract is unchanged. Coordinate the shared release file with `protect-release-tag-digests` and `normalize-dockerhub-repository-names`.
