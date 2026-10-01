# Tasks

## 1. Produce one authoritative runtime selection

- [x] 1.1 Adapt the existing stdlib parser to select one highest stable baseline x86_64 GNU artifact per supported minor and reject missing/invalid/conflicting records; extend the existing runnable check with numeric patch ordering and malformed/conflicting/missing data, and verify it passes without network access.
- [x] 1.2 Render one deterministic `python_runtimes.MODULE.bazel` with its own extension binding, exact native version/platform URL/checksum overrides, explicit minor mappings, defaults, minor registrations and existing use_repo aliases; verify emitted values match parsed records, repeated rendering is byte-identical and a failed refresh preserves the previous file.
- [x] 1.3 Wire native MODULE include and exports, retire `python.SHA256SUMS` only after the replacement resolves, and update README's refresh/commit/rollback instructions; verify no duplicate manual patch source or latest lookup remains in ordinary builds.

## 2. Verify native catalog isolation

- [x] 2.1 Resolve against a saved test patch older than the installed catalog's maximum and against a saved same-version/platform record with a different upstream archive; verify supported minor mappings, repository URLs and checksums remain exactly saved without excluding dependency toolchains such as 3.11, and record the smallest reproducible regression check alongside the existing parser check.
- [x] 2.2 Restore the intended saved release selection, refresh dependency lock data as required, build/load both variants and run runtime/POI checks; verify interpreter versions, OCI metadata, immutable tags and linux/amd64 agree before applying `use-stripped-python-artifacts`. No registry upload is part of this migration.
