# Spec Delta

## MODIFIED Requirements

### Requirement: Verified publication gate
The release flow SHALL run the base runtime smoke check and Apache POI through JPype integration check on every exact platform image selected for publication: both amd64 and arm64 for a default release, or the one explicitly selected amd64-v2/v3 image for a CPU-specific release before upload. It SHALL verify that all selected images carry the same resolved Python version and SHALL stop without pushing when any check fails or a platform cannot be executed. Metadata inspection alone SHALL NOT replace runtime execution.

#### Scenario: Successful release validation
- **WHEN** runtime and POI execution checks pass for both default platform images with matching Python identity
- **THEN** the release flow permits their shared index to be pushed

#### Scenario: Failed release validation
- **WHEN** any selected platform's runtime or POI check fails, or selected version identities differ
- **THEN** no release tag is uploaded or updated

#### Scenario: No compatible runner
- **WHEN** the execution environment cannot run one of the required platforms
- **THEN** release fails before upload instead of skipping that platform's checks

#### Scenario: Validate a CPU-specific release
- **WHEN** a publisher explicitly selects amd64-v2 or amd64-v3
- **THEN** its matching saved CPU artifact, advertised CPU requirement and single-platform runtime/POI execution must pass before its dedicated index is pushed

### Requirement: Post-publication pull verification
After upload or reuse of an identical existing release, the release flow SHALL inspect the immutable index for exactly `linux/amd64` and `linux/arm64` in a default release, or exactly one `linux/amd64` entry with matching CPU identity in an explicitly selected CPU-specific release, verify that its index and platform manifest digests match the validated local candidate, explicitly pull each platform, verify its platform metadata, and run the base runtime smoke assertions against every selected pulled image. Success output SHALL report the registry digest of the shared index and SHALL NOT be printed if any required platform or CPU identity verification fails or a requested channel does not resolve to that index.

#### Scenario: Verify a published release
- **WHEN** Docker Hub accepts the default immutable release tag
- **THEN** both pulled platform images pass runtime checks and the shared index digest is reported to the publisher

#### Scenario: Reject incomplete published content
- **WHEN** the remote tag lacks a required platform, has an unexpected platform set, differs from the validated candidate digests, or any selected pulled image fails runtime checks
- **THEN** the release command fails without reporting successful publication

#### Scenario: Verify an optimized release
- **WHEN** Docker Hub accepts an explicitly selected CPU-specific immutable tag
- **THEN** its one amd64 manifest and index digest match the validated candidate, the pulled image has the expected CPU identity and passes runtime checks, and its dedicated channel is updated only after verification

## ADDED Requirements

### Requirement: Separate optimized CPU tags
CPU-specific publication SHALL explicitly select v2 or v3 and publish a one-entry amd64 OCI index under `X.Y.Z-java21-debian13-amd64-vN-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>`. The timestamp and SHA SHALL come from the same clean release commit. Only an explicitly requested `X.Y-java21-debian13-amd64-vN` channel SHALL move after verification. Default shared indexes/tags and existing immutable artifacts SHALL remain compatible; no global `latest` SHALL be added.

#### Scenario: Publish an optimized minor
- **WHEN** Python 3.14 with CPU v3 is released with a channel request
- **THEN** only its CPU-specific immutable identity and `3.14-java21-debian13-amd64-v3` channel are published or refreshed; v2, baseline and the other Python minor's tags are unaffected by that release command

#### Scenario: Preserve default publication
- **WHEN** a publisher uses the existing release command without CPU selection
- **THEN** the original dated immutable tag and optional minor channel retain the exact two-entry amd64/arm64 index and both-platform validation

#### Scenario: Protect CPU-specific immutable content
- **WHEN** a CPU-specific immutable tag already exists
- **THEN** matching content is reused and verified; conflicting content or uncertain inspection errors stop publication without replacing the tag or advancing its channel

### Requirement: Automated CPU variant coverage
Trusted automation SHALL publish and verify default, v2 and v3 selections for both Python minors from the same saved source SHA. PR checks SHALL execute all eight runtime variants without write/publish credentials. Atomic input refresh, publication serialization, failure reporting and unchanged-source retry SHALL include the new selections. Each selection's channel SHALL depend on its own successful gates; no cross-selection transaction is required.

#### Scenario: Refresh all supported CPU variants
- **WHEN** a scheduled or manual run saves a complete eight-artifact update
- **THEN** downstream checks and releases use its exact commit and attempt both default indexes and all four CPU-specific indexes, without a PR or per-release approval

#### Scenario: Start the first CPU build from a main push
- **WHEN** the implementation and its complete pinned inputs are pushed to `main`
- **THEN** GitHub automatically starts hosted validation and publication for all eight runtime images and six indexes, without a manual workflow dispatch; completion is confirmed by the actual run and published registry artifacts

#### Scenario: Reject an incomplete CPU refresh
- **WHEN** a required v2/v3 artifact is absent or invalid in the selected highest stable Astral patch
- **THEN** automation leaves saved remote inputs unchanged and does not publish a partially refreshed source selection

#### Scenario: Recover a failed CPU-specific publication
- **WHEN** one selection fails while other releases succeed and a later scheduled run has unchanged inputs
- **THEN** the failed selection reports failure and preserves its old channel, while the later run retries all selections and reuses matching immutable content without creating an empty commit

### Requirement: Documented CPU selection
Consumer documentation SHALL identify v2/v3 tags as explicit minimum-CPU choices, show the `io.pyva.cpu.variant` metadata contract and preserve baseline/arm64 guidance. Maintainer instructions SHALL cover build/load/release selection, runner CPU checks, all six publication selections and rollback. Documentation SHALL NOT promise automatic ISA selection, fallback on an incompatible CPU or a measured speedup without benchmark evidence.

#### Scenario: Choose an optimized image
- **WHEN** a consumer reads either language section of README and its linked maintainer instructions
- **THEN** they can choose a CPU-specific tag for a compatible CPU or retain the baseline image, understand that Java/Debian layers remain shared, and are not led to expect automatic selection or a guaranteed speedup
