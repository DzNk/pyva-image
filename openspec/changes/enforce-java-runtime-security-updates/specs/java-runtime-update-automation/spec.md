# Spec Delta

## Purpose

Keep both Eclipse Temurin LTS runtimes current through pinned upstream updates and verified image publication.

## ADDED Requirements

### Requirement: Discover a complete Temurin JRE update
The updater SHALL compare the latest stable Eclipse Temurin release of each supported Java major with the saved version and build. An update SHALL exceed the saved release for that major, satisfy its minimum, and have official Linux glibc HotSpot JRE archives and SHA-256 checksums for amd64 and arm64 from the same release.

#### Scenario: A newer upstream release is available
- **WHEN** both architecture archives and their checksums are available for a newer release, including a higher build number with the same Java version
- **THEN** the updater prepares one change with the release tag, versioned archive URLs and both checksums for every updated major

#### Scenario: The saved release is current
- **WHEN** verified upstream metadata matches the saved releases and all four checksums, and both releases meet their minimum
- **THEN** the update check succeeds without rebuilding images or writing Git changes

#### Scenario: The latest candidate cannot be verified
- **WHEN** metadata is unavailable or invalid, the latest release lacks an eligible archive or checksum for either architecture, the version regresses, or an existing release is returned with changed archive hashes
- **THEN** the updater reports the failure and leaves the previously committed selection in place

### Requirement: Refresh pinned Java inputs in GitHub Actions
The existing runtime workflow SHALL check for Java updates daily and by manual dispatch on the original repository's default branch. It SHALL add the Java pins to its checked, fast-forward runtime input update and release from the resulting exact commit.

#### Scenario: Persist a runtime input update
- **WHEN** the Java updater finds a complete new release and the preparation checks pass
- **THEN** the workflow commits the changed Java pins with any other runtime input changes and passes that exact source commit to the existing publication jobs

#### Scenario: Repeat a successful update check
- **WHEN** the updater finds no changed pins
- **THEN** the workflow creates no empty source commit and the publication jobs use the current committed pins

#### Scenario: A candidate image cannot be validated
- **WHEN** a platform cannot run, a runtime reports a different Java version than selected, or any required test fails
- **THEN** the affected release job fails and leaves that image pair's channel unchanged

#### Scenario: Run the ordinary development checks
- **WHEN** a feature or develop branch runs the ordinary runtime build and smoke checks
- **THEN** those checks run independently of the production minimum

#### Scenario: An update workflow is outside the default branch
- **WHEN** a fork or non-default branch invokes the update workflow
- **THEN** the update workflow performs no Git writes or registry publication
