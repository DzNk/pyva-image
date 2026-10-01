# Tasks

## 1. Keep one post-pull platform gate

- [x] 1.1 Delete only the redundant platform-inspection block in `release.sh`, retain the post-pull `smoke_test.sh` invocation before success output, and verify shell syntax plus a minimal offline command-stub regression in which a failing post-pull smoke check makes release fail without printing Published. Reuse the release regression file if another release proposal has already added it; preserve any channel guard from `protect-release-tag-digests`.
