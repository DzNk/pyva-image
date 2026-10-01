# Tasks

## 1. Astral-backed Python selection

- [x] 1.1 Add a standard-library command to save stable x86_64 GNU install-only checksum records from Astral's latest tagged release, reuse `rules_python` for patch selection, and verify the updater against live metadata and missing/invalid artifact data.
- [x] 1.2 Register `3.13` and `3.14` toolchains using the saved checksum manifest, refresh `MODULE.bazel.lock`, and verify both interpreter repositories and the generated hub version mapping resolve to the selected artifacts.

## 2. Versioned image variants and checks

- [x] 2.1 Add the minimal shared image macro, instantiate `pyva_runtime_3_13` and `pyva_runtime_3_14` build/load/push targets, derive exact version metadata and tags from the generated version mapping, and verify both load tarballs build successfully.
- [x] 2.2 Parameterize `smoke_test.sh` for the selected Python minor and exact resolved version, then run it against both loaded images and verify runtime version, OCI metadata, Java/JPype prerequisites, and `linux/amd64` platform assertions.
- [x] 2.3 Parameterize the existing Apache POI downstream image check for `3.13` and `3.14`, then build and run the same POI workbook validation against both runtime variants.
- [x] 2.4 Replace the single-version build examples in `README.md` with both versioned targets and explain that rerunning the Astral resolver advances patches; verify every documented local build command names `3.13` or `3.14`.

## 3. Explicit variant publication

- [x] 3.1 Change `release.sh` to require `3.13` or `3.14`, select the matching targets, derive `X.Y.Z-java21-debian13`, optionally update only `X.Y-java21-debian13`, and verify shell syntax plus rejection of missing or unsupported versions before any upload.
- [x] 3.2 Update Docker Hub documentation with version-selected release, pull, and `FROM` examples for both minors and no global `latest` tag; verify the examples match the release script usage and generated tag forms.
- [x] 3.3 Run the complete build and local smoke/POI gates for both variants, inspect each image as `linux/amd64`, and confirm its runtime `X.Y.Z`, OCI version metadata, and immutable tag are identical before considering publication ready.
