# Design

## Context

The production workflow adds four `amd64-v2/v3` jobs to the four Python and Java pairs. The same CPU choices appear in Bazel, Astral input selection, release and smoke scripts, and CI fixtures. Removing matrix jobs alone leaves both archive availability and explicit build paths tied to those variants.

## Goals / Non-Goals

**Goals**

- Keep one build per architecture within each Python and Java pair and release each pair through the existing two-platform path.

**Non-Goals**

- Registry cleanup, changing the nightly trigger policy, and changing the selected Python or Java releases are outside this change.

## Decisions

Make `amd64` and `arm64` the only Astral inputs. Regenerate `python_runtimes.MODULE.bazel` and the Bazel lock from the retained pins to isolate the matrix change from upstream updates. Remove the unused CPU-specific artifacts, selectors and native CPU checker. Keep the checks that reject an optimized image masquerading as a baseline candidate, since historical images can still be passed to the smoke script.

Use the Cartesian product of the two Python minors and two Java majors in GitHub Actions. Both architectures follow the same build, validation and publication flow. Baseline version labels and digest checks stay compatible while the existing family channels are promoted only after post-pull verification.

## Risks / Trade-offs

- Retired CPU channels will stay at their last published image and no longer receive updates. The maintained channel for the same Python and Java pair provides the migration path.
- The completed `add-amd64-cpu-variants` change is still unarchived. Its CPU requirements should be superseded by this delta when the changes are synced in historical order. Reconcile the overlapping requirements from `enforce-java-runtime-security-updates` so Java 25 and the exact runtime checks are retained.

## Migration Plan

Remove CPU-specific paths from the repo and release four pairs using the new tag format from `include-temurin-version-in-release-tags`. Preserve old CPU references in Docker Hub. The hosted verification can cover both changes in one run.
