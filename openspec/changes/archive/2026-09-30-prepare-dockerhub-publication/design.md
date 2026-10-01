# Design

## Context

See `proposal.md` for motivation. The repository already produces `//:pyva_runtime`, a Docker-loadable archive, a base smoke script, and an Apache POI downstream integration image. `rules_oci` 2.3.0 is already pinned and its `oci_push` executable can accept `--repository` and additional `--tag` values at runtime while using the host's standard Docker-compatible credential configuration.

The source tree currently has no hosted-CI configuration or fixed registry namespace. The release path must therefore be locally runnable, CI-friendly, and independent of a particular Docker Hub account.

## Goals / Non-Goals

**Goals:**

- Publish the exact Bazel-produced OCI image without a Docker save/tag/push conversion step.
- Keep the destination repository and credentials outside tracked files.
- Make the immutable release tag the safe default and channel-tag movement explicit.
- Gate publication on the existing runtime and POI integration behavior.
- Attach useful OCI metadata without changing runtime contents.
- Verify the registry copy by pulling and running it, then report its digest.

**Non-Goals:**

- Multi-architecture image indexes.
- GitHub Actions or another hosted-CI provider.
- Image signing, provenance attestations, SBOM generation, or Docker Hub API management.
- Publishing application dependencies such as JPype or POI inside the base image.

## Decisions

### Use `oci_push` on the existing image target

Add an `oci_push` target whose `image` is `:pyva_runtime`, whose default remote tags contain only `3.13.15-java21-debian13`, and whose repository is intentionally omitted. Publishers pass `--repository index.docker.io/<namespace>/pyva-runtime` at runtime. An optional `--tag 3.13-java21-debian13` advances the channel tag.

This keeps the published manifest tied to the Bazel output and uses the credential lookup already implemented by `rules_oci`. Docker `tag` plus `docker push` was rejected because it unnecessarily routes the release through the local daemon and makes the Bazel output less directly traceable.

### Keep one small release orchestrator

Add one shell entrypoint for the ordered release operation: validate required inputs, run the base smoke test, build and run the POI smoke image, invoke the Bazel push target, pull the immutable remote tag, run the runtime assertions against that pulled tag, and print its repository digest.

The existing smoke logic should accept an optional image reference so post-push verification can reuse it without rebuilding or loading the local archive. A larger release framework or task runner is unnecessary for one image.

### Separate immutable and moving tags

The push target always carries the fully qualified runtime tag. The minor-version channel is supplied only by an explicit release option and no `latest` tag is defined. This makes accidental channel movement less likely and forces future Python patch releases to update the immutable tag alongside the pinned runtime input.

### Add deterministic OCI labels

Provide a checked-in labels file for stable metadata: title, description, runtime version, and documentation/source URLs when known. Allow source revision metadata to be stamped only when the caller provides it; otherwise omit it rather than insert a timestamp or floating value that would make identical builds differ.

### Use external Docker-compatible authentication

Publication reads the standard host credential configuration created by `docker login` or an equivalent credential helper. The release entrypoint accepts only the repository name and tag choice; it never accepts a password as a command-line argument and never writes credentials.

## Risks / Trade-offs

- [Docker Hub tagging is sequential rather than atomic] → Push the image by digest first, apply the immutable tag before the optional channel tag, and report partial failures clearly; immutable releases are never rolled back or overwritten.
- [A publisher can supply the wrong namespace] → Require a fully qualified `index.docker.io/<namespace>/<repository>` value and print it before the first upload.
- [Local smoke checks and the uploaded registry object could diverge] → Pull the immutable tag after publication and run the runtime assertions against the pulled image.
- [Static labels can become stale when runtime versions change] → Keep label/tag updates in the same task and verification as CPython/JVM version changes.
- [The current artifact is amd64-only] → Verify the pulled manifest architecture and document the limitation prominently.

## Migration Plan

1. Add labels and the push target without changing the current image layers or local load target.
2. Parameterize the existing smoke check for local and remote image references.
3. Add and exercise the release entrypoint against a non-production Docker Hub repository or disposable tag.
4. Publish the immutable production tag, verify it after pull, then explicitly advance the channel tag if desired.

Rollback does not delete immutable tags. If a moving channel points at a bad release, reapply that channel tag to the last verified immutable image and document the correction.
