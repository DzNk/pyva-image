# Proposal

## Why

The runtime is hard-coded to one full CPython release, including a hand-written Astral URL and checksum, so adding or updating a supported Python line requires editing build internals. The build should instead accept plain minor versions and resolve the latest available stable patch release directly from Astral's release metadata.

## What Changes

- Support `3.13` and `3.14` as the complete Python version inputs for runtime image builds.
- Parse Astral's latest-release pointer and release asset checksums to resolve the latest stable CPython patch and x86_64 GNU install-only archive for each supported minor.
- Keep resolved versions, URLs, and checksums generated and locked for reproducible builds; refresh them explicitly when advancing to newer Astral releases.
- Produce and verify one image per supported Python minor, with the resolved full version visible in OCI metadata and immutable release tags.
- Keep both variants limited to `linux/amd64` (`x86_64-unknown-linux-gnu`) and retain the existing Java 21 / Debian 13 runtime contents.
- Replace the single `3.13` publication path with explicit `3.13` and `3.14` release variants; do not introduce a global `latest` tag.
- **BREAKING**: Require the release command to name the Python minor being published instead of assuming the former hard-coded `3.13.15` image.

## Capabilities

### New Capabilities

- `python-minor-image-builds`: Build a separate x86_64 runtime image for each configured Python minor using the latest Astral-backed patch release and expose its resolved version.

### Modified Capabilities

- `dockerhub-image-publication`: Publish and verify immutable and minor-channel tags for both supported Python image variants instead of one hard-coded Python release.

## Impact

- Affects `MODULE.bazel`, `BUILD.bazel`, image metadata/tag files, smoke and release scripts, and usage documentation.
- Adds a small command to refresh a saved Astral checksum manifest. The existing `rules_python` manifest parser selects patch versions and supplies their resolved mapping to image metadata; no new dependency is required.
- Changes build and release target selection from one fixed image to two explicit Python-minor variants, both amd64-only.
