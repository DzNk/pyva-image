# Validation

## Inputs and execution

- Astral release 20260929: CPython 3.13.15 and 3.14.7, both GNU/GIL stripped architectures, exact URL/SHA-256 overrides saved in the generated fragment.
- Distroless index: `sha256:58133991db06659feaabe0f4e97a35cebf15ef4ea08f8a4c6d2ee5f75e4aa6a0`; preserved amd64 child, ARM64/v8 child.
- Debian snapshot 20250901T000000Z: both explicit OpenJDK 21.0.8 closures resolved and built.
- Docker Desktop 29.8.1; amd64 host with existing ARM64 emulation. No binfmt installation performed.
- All four base runs and all four target-platform JPype1 1.7.1 / Apache POI 5.4.1 XLSX runs passed before the release commit.
- Existing published tag `3.13.15-java21-debian13` initially resolved to `sha256:3a7d328bbdf6ed7b02862268a6ba1e912b307fdb6840a827f80f1d62f28a96be`.

## Stripped vs unstripped layer bytes

Both variants use identical `pkg_files`/`pkg_tar` packaging, the same patch and
architecture from Astral release 20260929. Only temporary input overrides in
`/tmp/pyva-unstripped-baseline` point to checksum-verified `install_only` archives.
Tracked release inputs remain stripped. Sizes are the uncompressed Python layer
tar bytes (without Java/base/metadata); all four reductions asserted.

| Minor | Architecture | Stripped bytes | Unstripped bytes | Saved bytes |
| --- | --- | ---: | ---: | ---: |
| 3.13 | amd64 | 98160640 | 258990080 | 160829440 |
| 3.13 | arm64 | 78366720 | 181268480 | 102901760 |
| 3.14 | amd64 | 101130240 | 250664960 | 149534720 |
| 3.14 | arm64 | 80855040 | 175831040 | 94976000 |

## Pre-commit checks

Repository ignores, Astral atomic-selection tests and native Bazel catalog
isolation passed. Offline release regression passed for both minors: Git-derived
UTC identity (timezone/clock changes and same-time different commits), clean
source, immutable collision/retry/auth/transport handling, either-platform gates,
config/layer mismatch, remote index/child/platform mismatch, pull/run failures and
late channel-copy failures. Shell syntax and strict OpenSpec validation passed.

README has 44 lines, Russian before English, certificates/default environment in
both languages. Its exact Dockerfile built and ran a UID 65532 application that
read the copied PEM. Existing amd64 loader targets and archive paths built.

Docker Desktop Docker-archive imports expose a different Docker manifest ID;
`.Id` is not reliably the OCI config digest. Docker-save inspection confirmed
that exported config bytes equal the original OCI config exactly. Loaded/pulled
execution is checked against the candidate config and ordered uncompressed layer
SHA-256 values. Native OCI index/child digests are checked exactly against the
registry descriptors.

## Release source

Reviewed local source commit: `a614dc1adbfe4e83d8e72f1a4299c1858b03be64`.
Git committer epoch: `1790880333`; UTC time: `2026-10-01T18:45:33Z`.
Clean detached worktree: `/tmp/pyva-release-a614dc1`; exact SHA/timestamp and
empty `git status --porcelain --untracked-files=all` verified. No Git push.
Candidate review found no generated output paths or obvious credential
signatures. The 82 new ARM64 lock records use the existing snapshot; existing
amd64 package records are unchanged.

## Independent release builds

Two separate output bases (`/tmp/pyva-repeat-one`, `/tmp/pyva-repeat-two`) built
all four images/load archives and both indexes from the clean release commit,
using `--lockfile_mode=error`, independent action caches and action TZ settings
UTC vs Pacific/Honolulu. First-build temporary tmpfs exhaustion interrupted the
second build; the completed size-baseline output base was expunged and the
second build completed successfully. No release inputs changed.

All four image digests, both index digests and all four load-archive SHA-256
values matched exactly. Git-derived tags matched across UTC/Honolulu and rebuild
time. The clean checkout still had the exact source SHA and no eligible changes.

| Minor | Artifact/platform | Identical OCI digest in both builds |
| --- | --- | --- |
| 3.13 | index | `sha256:22eee02d8a7a31d89662d67df550849b0c8f026e08bbace89139ba56371edaee` |
| 3.13 | amd64 | `sha256:2f5ba950b06a8a3c1a94cfaec20eaeefdca208386aa087eea6e5c3207ec5ac60` |
| 3.13 | arm64 | `sha256:e1bf8c5808f692dedfcd9cb5a4967efdd2c03f07a4153d440607a313babc16b9` |
| 3.14 | index | `sha256:91d5802af51361e5f332bad8883faf74bbf509bd13f1026d79f81117afc1410d` |
| 3.14 | amd64 | `sha256:944658fcee04e1522dcbe5e044089363ce3360a9a9cfe8e2ef139da67c0ce530` |
| 3.14 | arm64 | `sha256:6c4f033ba6c5889fbbc1eeb250d21d48b913980fd8bc6bf346bdf888c76ab62d` |

| Minor | Platform | Identical Docker-load archive SHA-256 |
| --- | --- | --- |
| 3.13 | amd64 | `752ccd3a1f16f5ce8cf0f035adad2ca48f69ef009aa812cc0affa2aa017a4ea2` |
| 3.13 | arm64 | `548d3d750933b7814aa96a47b5001ab98358820c3dc9c80b8bcb0caf261efeed` |
| 3.14 | amd64 | `06b4b1b249c04a5b25b994eb8e1a20f27e109d292b355cea6e0f9894fdd05eeb` |
| 3.14 | arm64 | `d20d8fa5ff05a6a3d988e081c3405bf390f54574f2ae9619a4d46c9a9e04c654` |

## Release-output execution matrix

Each archive from the first independent release build was loaded and executed;
its config and ordered layer digests matched the candidate.

| Minor | Platform | Runtime identity | Checks |
| --- | --- | --- | --- |
| 3.13 | amd64 | 3.13.15-java21-debian13 | base, POI XLSX, config/layers: PASS |
| 3.13 | arm64 | 3.13.15-java21-debian13 | base, POI XLSX, config/layers: PASS |
| 3.14 | amd64 | 3.14.7-java21-debian13 | base, POI XLSX, config/layers: PASS |
| 3.14 | arm64 | 3.14.7-java21-debian13 | base, POI XLSX, config/layers: PASS |

## Initial live verification correction

The initial 3.13 dated tag
`3.13.15-java21-debian13-20261001T184533Z-ga614dc1adbfe4e83d8e72f1a4299c1858b03be64`
was uploaded with the expected index and both child digests; amd64 post-pull
passed. ARM64 post-pull correctly stopped publication success when Docker
inspection implicitly returned the host-platform config. No channel was changed.
The uploaded immutable tag remains untouched.

The release and smoke inspection calls now select `--platform linux/<arch>`
explicitly (Docker API 1.49+), and the offline mock requires that selection.
A reviewed amended source commit and fresh dated tags follow below; image
inputs/build definitions are unchanged.
