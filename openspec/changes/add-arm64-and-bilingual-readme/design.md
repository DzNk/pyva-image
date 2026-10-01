# Design

## Context

See proposal.md for motivation. Current amd64 assumptions span the Astral parser/generated repositories, distroless pull, apt source architecture, global Java/metadata layers, image macro, smoke assertions and release commands. The pinned base digest is an amd64 image manifest, not a two-platform index. The installed apt repository's `:flat` target selects packages through Bazel CPU constraints; referencing it from an explicitly named arm64 image would still select the build platform unless configuration changed. Explicit `//openjdk-21-jre-headless/<arch>` targets already expose the architecture's complete dependency closure.

Installed `rules_oci` supports `oci_image_index(images = [...])`, and the current updater already has atomic refresh and catalog-isolation tests. README contains useful maintenance commands that can move rather than be discarded.

Read-only inspection of the existing Docker Hub repository found `3.13.15-java21-debian13` at `sha256:3a7d328bbdf6ed7b02862268a6ba1e912b307fdb6840a827f80f1d62f28a96be` as a single image manifest. Its existing local registry copy is amd64; the current local 3.13 runtime has a different digest. The `3.14.7-java21-debian13` remote tag returned not found. Docker access and buildx are available after Docker Desktop startup, using the configured docker group. Static inspection also found that installed `oci_push` applies CLI `--tag` values before its configured `remote_tags`, so the current `--channel` call advances the channel before the intended immutable tag. Separate those operations. Keep the repository/account supplied from the session at execution, not embedded in tracked artifacts.

## Goals / Non-Goals

**Goals:** Separate image architecture from the machine performing packaging; keep one pinned Python patch identity across both platforms; retain existing amd64 local-load behavior; keep the consumer landing page around one screen.

**Non-Goals:** A toolchain framework, new dependencies, CI, additional architectures/Python minors, automatic QEMU/binfmt installation, registry writes or Git mutations during planning, Git push during implementation, or bundling JPype/POI into the runtime. Later implementation prepares one reviewed local source commit for release identity and performs the requested fresh 3.13 and 3.14 publications after successful full validation.

## Decisions

### 1. Explicit architecture variants and native OCI indexes

Extend the existing image macro with a small fixed amd64/arm64 mapping. Use `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` Python repositories, matching distroless bases, and Java layers built from explicit apt dependency closures. Reuse native `flatten` and the current merged-/usr `deb_postfix` normalization for each Java layer; do not use a host-selected `:flat` closure for both. Parameterize Java symlinks, `JAVA_HOME` and `LD_LIBRARY_PATH` to the Debian architecture paths. Share architecture-independent directories.

Pull both base platforms using a verified pinned OCI index digest; inspect it before replacing the current amd64-only digest. Keep the current Debian snapshot and rules versions unless resolving the required ARM inputs demonstrates a concrete incompatibility.

Proposed targets:

- `pyva_runtime_3_13_amd64`, `pyva_runtime_3_13_arm64` and equivalent `3_14` image targets, each with its own `_load` target/archive.
- `pyva_runtime_3_13` and `pyva_runtime_3_14` become native OCI indexes over their respective two explicit images; their existing `_push` targets publish those indexes by digest, with no built-in remote tags. The release command supplies the validated dated immutable tag explicitly.
- Existing minor `_load` commands alias the corresponding amd64 loader. Architecture loaders use local `pyva-runtime:<minor>-<arch>` tags; amd64 additionally keeps the existing minor and exact patch local aliases. ARM loads must not overwrite the legacy amd64 aliases.

This avoids Bazel platform transitions and cross-compilation: the image packages prebuilt binaries. Alternative: a single platform-sensitive target and split transitions, which adds configuration complexity to a four-image matrix.

### 2. Resolve the highest patch once, then require both stripped artifacts

Extend checksum parsing to both GNU architecture triples; determine each minor's highest stable patch across recognized GIL-enabled install-only records, then require both stripped archives for that patch. Do not select the highest common older patch. Save four explicit version/platform overrides and four repository aliases, with one minor-to-patch mapping per minor. Reject missing/malformed/conflicting records before atomic replacement. Ordinary builds keep using saved URLs/hashes without looking up latest or falling back to catalogs.

Reuse and extend `test_python_manifest.py` including its `--bazel` mode. No separate manifest format or dependency resolver is needed.

### 3. One release command validates both images before pushing their index

Keep `release.sh [--channel] <minor> <repository>` and current destination validation. Add optional `--arch amd64|arm64` to `smoke_test.sh` while preserving its current amd64 default and optional image reference. Explicit architecture execution checks the OCI platform, Python machine (`x86_64`/`aarch64`), selected patch, complete native import set, Java 21, JVM loading, identity, directories and absence of shell/package managers. Check `/etc/certs` empty/default configuration without the test mount, then check readability with the consumer PEM mount.

For each platform, load an architecture-qualified local tag, run base checks, build the existing POI Dockerfile with that platform and runtime tag, and execute it with an explicit `--platform`. Its Python dependency stage must match the target platform; the Maven stage can run on the build platform because its output is JARs. Verify both images report the same version before any upload. Preserve their identities through validation; do not independently refresh inputs or silently rebuild a different variant for push.

Build the selected minor's OCI index and record its actual index/child manifest digests from the Bazel OCI layout. Before upload, inspect the intended immutable registry tag with Docker buildx: only a positively identified missing-tag response permits first publication; authorization, network or unrecognized errors stop. Reject a different existing digest without modifying tags; reuse an identical digest for an idempotent retry. A different digest for an unchanged source identity is a reproducibility failure, not a reason to overwrite.

For a new tag, use one native `oci_push` of the index with only the dated immutable `--tag`. Remove configured undated `remote_tags`, and do not pass the channel tag to this push. Use `docker buildx imagetools inspect` to verify the remote index/platform set and compare all manifest digests to the validated candidate, explicitly pull/run each platform sequentially, and print success only after both post-pull base checks. A Docker child image's `RepoDigests[0]` is not sufficient proof of the shared index digest. Sequential pull-and-check avoids a subsequent platform pull replacing the tag before its check.

Only after those checks, an explicitly requested channel is assigned from the verified registry index digest using `docker buildx imagetools create --tag <channel> <repository>@<verified-index-digest>`, then inspected for exact digest equality. A single existing image-index source is copied unchanged by this native command ([Docker documentation](https://docs.docker.com/reference/cli/docker/buildx/imagetools/create/)). Inspect the index and children with structured JSON where available ([inspection documentation](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/)), using the Python stdlib for validation instead of a custom registry client. A failed immutable verification leaves channels unchanged; a failed channel operation reports the partial release without rollback or success output.

The release runner must execute both architectures, natively or using already configured Docker emulation. Missing execution support fails the release; no metadata-only substitute. Reuse `test_release.sh` mocks to cover all gates and index/digest verification without registry writes.

### 4. Russian-first landing page, one maintainer document

Keep README roughly 35-45 lines including whitespace: title, `Python · Java 21 · JPype · Apache POI · Distroless`, `Русский` then `English`, two or three short sentences each describing Python calling Java (POI as an example), supported Python versions and platforms, no-shell/non-root notes, and consumer-supplied dependencies/JARs. State the certificate location in each language: `PEM-сертификаты: /etc/certs (SSL_CERT_DIR=/etc/certs)` / `PEM certificates: /etc/certs (SSL_CERT_DIR=/etc/certs)`. Add one shared minimal Dockerfile including `COPY certs/ /etc/certs/` and a link to `CONTRIBUTING.md`. Use an existing local image tag in that snippet and identify it as locally loaded; do not invent a published Docker Hub namespace. Detailed dependency-install examples and Java truststore guidance belong in the maintainer document.

Move and update existing build/load, refresh, validation, POI, authentication/release/pull, rollback, certificate and ignore-policy material to `CONTRIBUTING.md`. Explain selecting the target platform when preparing native Python dependencies there. Preserve `/etc/certs` and Java truststore guidance, external credential handling and immutable-tag policy. Document the new dated identity, clean-source requirement and idempotent retry semantics using a repository placeholder. Avoid duplicate examples and internal history on the landing page. README is a description, not an SEO badge system or a tutorial.

### 5. Commit-derived release tags, deterministic image contents

The user delegated the timestamp choice. Use `X.Y.Z-java21-debian13-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>`, with the UTC committer time and full SHA read once from the clean release checkout. Never use current time, local timezone or a short hash for immutable identity. The full commit id distinguishes commits even if their timestamps coincide.

Keep the image's existing `org.opencontainers.image.version` as the runtime identity `X.Y.Z-java21-debian13`; construct the dated publication tag in `release.sh` from that verified label plus Git metadata. This avoids stamping image layers/configs or introducing a circular digest-derived image label. Both architecture labels must agree, and their matching exact patch must agree with the generated inputs. Tag naming alone does not guarantee byte reproducibility: retain pinned inputs and normalized package metadata, avoid wall-clock OCI creation fields, and verify identical image/index digests by two independent builds of the same clean source revision. If a check shows variable archive timestamps, normalize them at the existing packaging rule rather than hiding the mismatch with a new tag.

Release rejects a dirty checkout, including eligible untracked source files. Since implementation and OpenSpec progress tracking edit the working tree, prepare a reviewed local release commit after tests/documentation, then run publication from a clean detached worktree of that exact commit using native Git. Progress/evidence can be recorded in the main working tree without changing the release checkout. The commit and clean worktree are implementation tasks; no Git staging, commit or publication occurs during proposal. No extra release manifest, scheduler or build-status abstraction is needed.

## Risks / Trade-offs

- [Different architecture names and host-selected closures can hide mixed binaries] -> use one explicit mapping and architecture-qualified package closures; build and execute all four images.
- [Current snapshot or selected Astral patch may lack an ARM artifact] -> check exact pinned inputs during implementation; stop with the missing input rather than changing versions/platform scope silently.
- [Emulation may be absent or fail native JPype/JVM execution] -> report the failing execution check and require a compatible runner; do not mark validation complete or install host support automatically.
- [Adding ARM changes the old patch-only tag's artifact] -> publish fresh dated immutable tags and retain all previously published undated tags; update channels only after the new index is verified.
- [A mocked release test does not prove registry availability] -> validate local images/index directly, then run the requested real release of both minors in the existing caller-selected repository after implementation; report both index and four child digests.
- [Parallel publishers can race between inspection and tag assignment] -> this local release workflow assumes one publisher per repository; document that ceiling and use registry-enforced tag immutability before enabling concurrent publishers. A client-side preflight is not an atomic registry guarantee.

## Migration Plan

Implement the four pinned runtime inputs, architecture layers/images and indexes; extend existing offline tests and execute base/POI checks for all four variants on a compatible Docker runner. Measure stripped versus unstripped Python layer sizes for matching patch/architecture/packaging as the current spec already requires; use temporary baseline inputs outside tracked files. Rewrite README only with platform claims justified by those checks, relocate maintainer details, and validate OpenSpec. Review the source candidate and create the local release commit, then check out that commit in a clean detached worktree and verify repeat-build tags/digests. Release each minor into the existing repository supplied from the session, with dated immutable tags and no channel option by default; any channel update remains explicitly selected. Record the two registry index digests and all four platform digests plus pull/run results, and verify the previous 3.13 immutable tag remains unchanged. Rollback restores the prior generated inputs, lockfile, build/scripts and documentation together; registry rollback never rewrites immutable tags.
