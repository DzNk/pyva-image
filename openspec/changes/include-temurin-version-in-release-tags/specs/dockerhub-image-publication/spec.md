# Spec Delta

## MODIFIED Requirements

### Requirement: Versioned release tags
Each supported Python minor and Java major pair SHALL publish one index containing exactly `linux/amd64` and `linux/arm64` under `X.Y.Z-java<TEMURIN>-debian13-YYYYMMDDTHHMMSSZ-g<SHA>`. `TEMURIN` SHALL be the selected stable runtime version and build, with `+` encoded as `_`. Both platforms SHALL run the same exact Python and Temurin releases. The timestamp SHALL be the clean source commit's committer time in UTC and `SHA` SHALL be its full hexadecimal ID. Published immutable references SHALL be preserved. The optional channel SHALL remain `X.Y-java<J>-debian13` and point to the verified index for that pair.

#### Scenario: Publish an immutable runtime tag
- **WHEN** a supported Python and Java pair is released
- **THEN** its dated, commit-qualified tag contains the exact CPython patch and the pinned Temurin patch and build, and both platform manifests pass runtime validation against those versions

#### Scenario: Publish a new Temurin build at the same Python patch
- **WHEN** the selected Temurin pin changes in a new committed runtime selection
- **THEN** its new patch or build appears in the immutable tag and the previous immutable tag still resolves to its original digest

#### Scenario: Publish a selected minor channel
- **WHEN** the publisher requests the moving channel for a supported Python and Java pair
- **THEN** only that pair's `X.Y-java<J>-debian13` tag advances after both pulls are verified and resolves to the immutable index digest

#### Scenario: Omit an unrequested channel update
- **WHEN** the publisher does not request a moving channel tag
- **THEN** publication preserves all channel tags and creates no implicit floating tag, including `latest`

#### Scenario: Select the platform automatically
- **WHEN** a consumer uses the shared tag on an amd64 or arm64 Docker host
- **THEN** Docker selects the corresponding platform image without an architecture suffix

#### Scenario: Repeat a release from unchanged source
- **WHEN** the same clean source commit and runtime pins are released at another wall-clock time
- **THEN** the tag and index digest remain the same and the matching immutable content is reused

#### Scenario: Change the runtime packaging without a Python patch change
- **WHEN** a new source commit changes packaging while retaining both runtime versions
- **THEN** it receives a different immutable tag and preserves the previous artifact

#### Scenario: Refuse an uncommitted release
- **WHEN** a release starts from a checkout with tracked changes or eligible untracked files
- **THEN** it fails before image upload or tag changes

#### Scenario: Preserve channels on immutable verification failure
- **WHEN** either published platform fails pull verification, including reporting Java different from the pinned version or build
- **THEN** all channel tags remain unchanged and the release reports failure
