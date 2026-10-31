# Spec Delta

## ADDED Requirements

### Requirement: Free hosted validation
The project SHALL provide GitHub Actions checks for PRs targeting `main`, main pushes, daily scheduled runs and manual runs on `main`. Jobs SHALL use free standard hosted Linux runners in a public repository, without paid services or artifact/cache storage. Private-repository jobs SHALL be skipped before runner allocation. Validation SHALL cover existing regressions and Python 3.13/3.14 base and JPype/POI execution on amd64/arm64 using committed inputs.

#### Scenario: Validate a pull request without publication
- **WHEN** a pull request targeting `main` runs, including a fork pull request
- **THEN** all four runtime variants and existing regressions are checked without repository writes, Docker Hub publication or access to publishing credentials

#### Scenario: Reject a failing platform
- **WHEN** one required platform cannot execute or a runtime, integration or regression check fails
- **THEN** the affected check fails rather than skipping that platform or reporting successful validation

#### Scenario: Preserve pinned build inputs
- **WHEN** validation or image building runs after a source commit is selected
- **THEN** it uses that commit's saved runtime selection and lock data without refreshing dependencies or changing tracked release inputs

#### Scenario: Avoid private repository runner charges
- **WHEN** the workflow is invoked in a private repository
- **THEN** its jobs are skipped before allocating hosted runners and the documentation states the public-repository prerequisite

### Requirement: Automatic upstream Python refresh
Daily and manual runs on `main` SHALL discover the latest stable Astral inputs for supported Python 3.13/3.14, without a PR, merge or per-release approval. Selection SHALL preserve the existing GIL-enabled GNU Linux stripped-artifact contract for both architectures. New minor lines and unrelated dependencies SHALL NOT be selected automatically. A lower Python patch SHALL NOT replace a saved higher patch.

#### Scenario: Discover a supported release
- **WHEN** Astral provides new valid versions, URLs or checksums for the supported Python lines on both architectures
- **THEN** the automation prepares matching runtime inputs and lock data without requiring a maintainer to run the updater

#### Scenario: Reject incomplete or invalid upstream data
- **WHEN** metadata cannot be read, a checksum is malformed, a required stripped architecture artifact is missing, or a candidate lowers a saved patch
- **THEN** the run fails without committing or publishing a partial update or substituting an older patch, prerelease or another artifact flavor

#### Scenario: Upstream CPython release is not yet available in Astral
- **WHEN** CPython has a new release but the required Astral release artifacts are not yet available
- **THEN** the automation waits for a complete supported Astral selection and does not publish an image claiming the unavailable version

### Requirement: Recorded automated release inputs
Changed Python inputs and required lock data SHALL be committed together to `main` before publication. Automation SHALL change only the saved Python fragment and its lock file, reject unexpected tracked changes, and use an ordinary fast-forward push. It SHALL NOT force-push, bypass branch rules or publish an unpushed local commit. Unchanged inputs SHALL NOT create an empty commit.

#### Scenario: Save an update automatically
- **WHEN** candidate inputs and their lock data pass preparation checks and `main` still permits the ordinary push
- **THEN** the bot commits and pushes both together and all later validation and publication jobs use that exact clean commit

#### Scenario: Reject a concurrent update or forbidden write
- **WHEN** `main` advances during preparation or its rules reject the bot push
- **THEN** the run fails without overwriting the concurrent work or publishing the unpushed candidate, and the next scheduled run starts from the current `main`

#### Scenario: Leave unchanged source untouched
- **WHEN** refresh produces no changes to the saved inputs or required lock data
- **THEN** no bot commit is created and publication verification uses the existing selected commit

### Requirement: Trusted automated Docker Hub publication
Successful daily runs, main pushes and manual runs on `main` SHALL publish both supported Python minors from one exact clean main commit. Scheduled updates SHALL continue to publication in the same run after saving the new commit, without relying on another push event. PRs, other branches and tags SHALL NOT update source, authenticate for publication or release. Trusted publication SHALL require no per-release human approval.

#### Scenario: Publish a newly discovered Python release
- **WHEN** a daily run records valid updated inputs and the selected commit passes required checks
- **THEN** the same run publishes both Python OCI indexes and their verified channels without a PR, manual merge, extra workflow trigger or operator confirmation

#### Scenario: Publish a main push
- **WHEN** a push to `main` starts a trusted run
- **THEN** the run selects current `main` after acquiring publisher serialization and publishes that frozen commit after successful checks, without refreshing Python inputs

#### Scenario: Reject publication from another ref
- **WHEN** a manual run selects another branch or a tag, or the event is a pull request
- **THEN** no automated source update, repository write authentication, Docker Hub authentication or release operation runs

### Requirement: Verified automated release channels
Each minor SHALL pass existing base/POI checks on both platforms, immutable-tag protection, remote digest comparison and both-platform pull/run verification. Its moving `X.Y-java21-debian13` channel SHALL advance only after those gates. Automation SHALL preserve the existing commit-derived immutable identity and SHALL NOT add a global `latest` tag or overwrite an immutable release.

#### Scenario: Preserve a failed minor's channel
- **WHEN** a minor's pre-publication check, immutable protection or post-publication verification fails
- **THEN** the workflow reports failure and that minor's channel is not advanced

#### Scenario: Report independent minor outcomes
- **WHEN** one minor succeeds and the other fails
- **THEN** the workflow reports failure while preserving the successful release; it does not claim an atomic two-minor publication

### Requirement: Automatic publication recovery
Every daily run after successful input preparation SHALL attempt publication of the current selected commit even when inputs are unchanged. A transient publication failure SHALL be retried at the next daily run without a new source commit or human action. Identical immutable content SHALL be reused and verified before channel updates; conflicting content or registry inspection errors SHALL fail closed. Manual runs SHALL offer the same recovery path.

#### Scenario: Retry after a committed update was not fully published
- **WHEN** a bot update was pushed but publication of one or both minors failed, and the next daily run has no new inputs
- **THEN** it retries both minors from the same current commit, reuses matching immutable content and completes missing publication and channel verification

#### Scenario: Repeat a successful release
- **WHEN** a daily or manual run uses an already published unchanged commit
- **THEN** it creates no new commit or clock-derived release identity and verifies the existing immutable releases before refreshing their channels

### Requirement: External CI publication configuration
The workflow SHALL accept the Docker Hub destination and username from repository variables and a write-capable token from repository secrets. Missing or malformed configuration SHALL fail publication clearly before upload or tag mutation. Maintainer documentation SHALL cover one-time activation, bot write permissions, triggers, retries, both-minor publication, schedule limits and verified rollback.

#### Scenario: Activate fully automatic publication once
- **WHEN** the operator enables Actions in a public repository with default branch `main`, allows bot pushes, and supplies the documented Docker Hub variables and secret
- **THEN** supported future Python updates can be saved, checked and published without further operator approval

#### Scenario: Missing publication configuration
- **WHEN** a trusted publishing run lacks a required destination, username or token, or has a malformed destination
- **THEN** publication fails with a configuration error before upload or tag mutation rather than silently succeeding

#### Scenario: Explain schedule and rollback limits
- **WHEN** a maintainer reads activation and recovery instructions
- **THEN** they explain delayed or disabled GitHub schedules, how to re-enable or manually run automation, and why automation must be disabled before intentionally rolling source or channels back

### Requirement: Isolated automation credentials
Repository write permission SHALL be limited to trusted scheduled/manual preparation. Other jobs SHALL have read-only repository access. PR validation SHALL work without publication configuration. GitHub and Docker Hub credentials SHALL NOT appear in tracked files, logs, build contexts, images, artifacts or caches; each token SHALL be available only to its required authentication step.

#### Scenario: No secrets configured for a pull request
- **WHEN** a pull request runs without Docker Hub variables or secrets
- **THEN** validation still runs, cannot write to `main` and requests no publishing credential

#### Scenario: Separate updater and publisher permissions
- **WHEN** a trusted run prepares and publishes a release
- **THEN** preparation alone receives repository write authentication and Docker Hub login alone receives the registry token

### Requirement: Serialized CI publishers
Daily, push and manual trusted runs SHALL share one concurrency group covering source selection, update, push, validation and publication. A new trigger SHALL NOT cancel an active publisher. PR checks SHALL use separate groups. Each trusted run SHALL select current `main` after acquiring serialization, then freeze its source SHA. Documentation SHALL state that external publishers must not overlap this repository's CI.

#### Scenario: Daily update arrives during a manual release
- **WHEN** a manual publishing run is active and the daily schedule triggers another release
- **THEN** the active publisher completes without cancellation and the scheduled run selects current `main` only after obtaining the publication group

#### Scenario: Validate a PR while publishing
- **WHEN** a pull request runs while a main release is active
- **THEN** its validation can run independently without modifying source or release tags
