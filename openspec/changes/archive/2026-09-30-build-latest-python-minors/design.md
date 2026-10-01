# Design

## Context

The current image hard-codes Python `3.13.15` in its module, packaging, metadata and release scripts. The built-in `rules_python` version list lags Astral, but the installed dependency already supports reading additional Astral `SHA256SUMS` manifests and selecting the highest patch for a minor. Its generated `pythons_hub/versions.bzl` exports the actual resolved `MINOR_MAPPING`.

## Goals / Non-Goals

**Goals:** Configure only `3.13` and `3.14`; package x86_64 GNU interpreters; derive exact image identities from the toolchain resolver; preserve reproducible inputs between deliberate updates.

**Non-Goals:** New dependencies, a custom Bazel version resolver, additional architectures, or a global `latest` image tag.

## Decisions

### Save Astral's release checksum data and use the existing parser

A short standard-library updater reads Astral's `latest-release.json` pointer and its tagged release's `SHA256SUMS`, retains stable baseline x86_64 GNU install-only records for the supported minors, and saves them with immutable absolute download URLs in `python.SHA256SUMS`. Validate both minors before replacing the previous manifest.

Register `python.toolchain(python_version = "3.13")` and `python.toolchain(python_version = "3.14")` with `python.override(add_runtime_manifest_files = ["//:python.SHA256SUMS"])`. Reuse `rules_python` to parse versions, select the highest patch, and download/check each archive. Load the resolved mapping from `@pythons_hub//:versions.bzl` for OCI annotations, labels and immutable tags. This keeps toolchains and advertised versions in agreement without generating duplicate version configuration.

The updater runs explicitly; ordinary builds consume the saved manifest and Bazel lock. A floating manifest URL inside the module was rejected because GitHub's latest-download URLs change their contents and previously named artifacts can disappear from that route.

### Share the image definition across both minors

One Starlark macro accepts a minor version and creates its Python layer, image, load and push targets. Keep the Java and metadata layers common. Public targets use suffixes `3_13` and `3_14`; loaded images use `pyva-runtime:3.13` and `pyva-runtime:3.14` plus their full immutable tags.

### Select and validate the release variant

Require `3.13` or `3.14` in `release.sh`, run both existing validation gates against that image, and derive the release identity from its verified OCI label. Preserve explicit channel updates and post-publication pull verification. Parameterize the POI builder's Python minor and runtime reference; use a pinned JPype version with wheels for Python 3.14.

## Risks / Trade-offs

- [Astral lookup fails or a supported artifact is missing] → Fail before replacing the saved manifest; ordinary builds continue using existing inputs.
- [Minor variants drift] → Use one packaging macro and the resolver's actual mapping for all version metadata.
- [Dependency wheels differ by Python minor] → Match the POI builder to the selected minor and verify both variants.
- [Old unversioned commands stop working] → Update build and release documentation together with the commands.

## Migration Plan

1. Refresh the saved Astral checksum manifest and register both minor toolchains.
2. Replace hard-coded image declarations with the shared macro and refresh the module lock.
3. Parameterize smoke, POI and release commands; update their documentation.
4. Build and verify both images, including exact versions, metadata and amd64 platforms.
5. Roll back by restoring the previous manifest/build inputs; leave existing immutable registry tags untouched.
