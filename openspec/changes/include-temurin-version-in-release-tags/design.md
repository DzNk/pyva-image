# Design

## Context

`image_manifest.py local` checks the platform configs and supplies the release family to `release.sh`. The latter appends the commit timestamp and SHA. `smoke_test.sh` already uses the pinned Temurin version and build for strict checks before upload and after both pulls.

## Goals / Non-Goals

**Goals**

- Keep the exact CPython and Temurin release identity visible in the immutable reference and retryable on the same commit.

**Non-Goals**

- The existing image label, local loader aliases, channel names and upstream selection policy stay in place.

## Decisions

Read CPython's patch from the already-validated OCI label and Temurin's patch and build from the same manifest used by runtime verification. Reuse Java version validation and require the pin to match the requested major. This gives tagging and runtime verification a shared source while keeping the image config compatible with current loaders.

Encode Temurin's build separator `+` as `_`, as upstream does in archive names. The full tag retains the UTC Git committer timestamp and full commit SHA so independent packaging changes still get separate references. Publishing a second short exact-version tag would make packaging revisions ambiguous and add a registry write.

Validate the actual updater through `workflow_dispatch` on `main`. The run should save a source commit only if the real upstream selection changed and should release the exact selected commit. Use local updater fixtures for a new Python patch, a new Temurin build and their combined update. This exercises advancement while keeping production pins sourced from upstream.

## Risks / Trade-offs

- A consumer parsing immutable tag names must accommodate the longer Java segment. The verified reference and digest remain available in the workflow summary.
- When upstream pins have not advanced, a hosted run demonstrates discovery, unchanged source selection and publication. Only a run with fresh upstream pins demonstrates a hosted update commit. Report which outcome was observed.

## Migration Plan

Publish via the existing workflow after this change and `retire-optimized-amd64-builds` are applied. Preserve historical immutable tags. For rollback, move the affected family channel to a previously verified digest using the existing procedure.

The dedicated Java change still has an unarchived delta for `Versioned release tags`. Preserve its Java gates when syncing the earlier delta and apply this tag-format delta after it.
