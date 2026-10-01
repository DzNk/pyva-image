# Tasks

## 1. Normalize explicit Docker Hub aliases

- [x] 1.1 Validate allowed hosts and two valid lowercase repository components before side effects, normalize docker.io to index.docker.io once, and keep the current version/channel arguments; leave one runnable offline argument check for both aliases and missing, foreign, scheme, tag, digest, whitespace, uppercase/invalid-component and extra-segment cases.
- [x] 1.2 Ensure push, pull, digest inspection and success output all consume the canonical repository variable; use command stubs to verify both accepted spellings produce identical downstream references without uploading anything, reusing the release check from `protect-release-tag-digests` if present.
- [x] 1.3 Update usage and README with both accepted aliases and canonical output, then run shell syntax and offline validation checks against the combined release changes; verify malformed destinations fail before any build or registry operation and credentials remain external.
