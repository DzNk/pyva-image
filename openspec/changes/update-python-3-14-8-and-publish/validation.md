# Validation

## Captured inputs

2026-10-15: captured official Astral latest metadata and tagged `SHA256SUMS`.
Selected release: `20261013`; selected stable patches are exactly 3.13.16/3.14.8.

| Python | Architecture | Immutable URL | SHA-256 |
| --- | --- | --- | --- |
| 3.13.16 | amd64 | `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.13.16+20261013-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz` | `d0080766b6b74aeb81e1949ef0d9a20e6c17f7b160fb295a69b936ccb17660be` |
| 3.13.16 | arm64 | `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.13.16+20261013-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz` | `69a30ed26198178732c37b8de0b6b5191479fbacfe526954da776befe38f18e7` |
| 3.14.8 | amd64 | `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.14.8+20261013-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz` | `d8faa1b588506b9e3e5a3f57807bb056d534a1641a6b10d15b6ea3f0b413b960` |
| 3.14.8 | arm64 | `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.14.8+20261013-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz` | `d8ae14f303d3971431184cf423ae5467202de2bc19bf6491a490250b87647d4b` |

Docker 29.8.2 / API 1.56; ARM64 execution verified. Credentials remain external.

## Resolution and registry preflight

`bazel mod tidy`, `bazel mod deps` and native `show_repo` completed. All four
repository versions/URLs/hashes match the captured inputs. Module/rules, OS and
JVM pins are unchanged. Lock regeneration produces an identical file: the
reproducible Python extension does not have runtime input records in this lock.
`test_python_manifest.py --bazel` passed saved-input/catalog isolation.

Four previous immutable refs (the legacy 3.13 tag, initial dated 3.13 tag and
final corrected 3.13/3.14 tags from the previous release evidence) were inspected
successfully. Minor channels and global `latest` are confirmed absent. The exact
before snapshot is retained for post-publication comparison.

Both new OCI indexes built successfully; Bazel verified all four archive hashes.
Local image identities are 3.13.16/3.14.8, and all referenced layer blobs pass
the installer-absence policy. Distroless/OS/JVM/rules inputs are unchanged.

## New-input execution matrix

All four combinations of Python 3.13.16/3.14.8 and amd64/arm64 passed base
smoke, installer module/metadata/file absence, negative installer invocation,
`venv --without-pip`, exact versions from both interpreter aliases, and OCI
platform/label/annotation inspection. All four target-platform JPype 1.7.1 /
Apache POI XLSX workloads succeeded with `--network none`; copied distribution
metadata remained readable through `importlib.metadata`. The documented builder
workflow is the existing tested POI multistage pattern; installer runs only in
the builder.

## Same-patch unstripped baseline

Four GNU/GIL unstripped archives from the same captured Astral release were
selected with their tagged SHA-256 records in a separate temporary checkout.
Bazel verified archive integrity and built the same Python packaging/filtering
with `--lockfile_mode=error`. Production inputs were not changed.

| Minor | Platform | Stripped tar bytes | Unstripped tar bytes |
| --- | --- | ---: | ---: |
| 3.13 | amd64 | 90398720 | 254248960 |
| 3.13 | arm64 | 70543360 | 175790080 |
| 3.14 | amd64 | 93245440 | 242769920 |
| 3.14 | arm64 | 72960000 | 167843840 |

Every stripped Python layer is smaller than its equivalent unstripped baseline.

Unstripped integrity inputs:

- `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.13.16+20261013-x86_64-unknown-linux-gnu-install_only.tar.gz` SHA-256 `e588e50db882fa6a89f926d9a9ad64e445183af0eda5bda226a2c151b17db8a6`
- `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.13.16+20261013-aarch64-unknown-linux-gnu-install_only.tar.gz` SHA-256 `0fce0605da7b6532d5bdaec185336ffaaddd02ec04e27382014952ca4857ed6d`
- `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.14.8+20261013-x86_64-unknown-linux-gnu-install_only.tar.gz` SHA-256 `322271a761140ffb3f522431048f701831e412c8f64770103d2b881ee2bbaed0`
- `https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.14.8+20261013-aarch64-unknown-linux-gnu-install_only.tar.gz` SHA-256 `6c3cfb175acca2748d5a9e42208c523bfbc1099ddb928615b5f328ba7c106e83`

Offline manifest/OCI/release/repository regressions, native Bazel catalog
isolation, shell syntax and both strict OpenSpec validations passed. Candidate
review excluded unrelated CI planning, ignored outputs and obvious credential
signatures. This is a joint release of the two explicitly requested changes.

## Clean release source

Release source commit: `ef7f84fe5b134206b927081af39bd0fb76c492bd`; UTC committer timestamp: `20261015T170914Z`
(epoch `1792084154`). Detached release checkout has exact SHA and empty
`git status --porcelain --untracked-files=all`. Unrelated untracked CI planning
stays in the main working copy. No source push.

## Independent release builds

Two fresh independent Bazel output bases built the clean source commit with
`--lockfile_mode=error` and action timezones UTC / Pacific-Honolulu. All four
image digests, two index digests and four Docker archive hashes match exactly,
and match the outputs used by the successful execution matrix. Both builds
passed all-layer installer policy. The detached source remained clean.

| Minor | Artifact | Identical digest |
| --- | --- | --- |
| 3.13 | index | `sha256:a3065911aba086691b357ea847e6636651a8a809edf73141e616803a3ddca708` |
| 3.13 | amd64 | `sha256:044850d1d275b8de101879f536b4243b0d265804ef9d27fef4a59e6d9d6bfbd9` |
| 3.13 | arm64 | `sha256:c62143f8e1e877d26b94d3ad5aa0e777071ee860914d40bd849bbcbc234e0eca` |
| 3.14 | index | `sha256:e9699e5d19255b03d30c848cd15f1cb5824b3e13fca6d73a1a5880506711d85b` |
| 3.14 | amd64 | `sha256:6a16d8935d1ece574ddb938286929ae0c6f94d1ec2cb0b2881b106e5b8430a85` |
| 3.14 | arm64 | `sha256:68b24ba9fffa6fb532be144bf65a870f280d05cc2cf87f28abff6a3a58a01400` |

Docker-load archive SHA-256:

- `pyva_runtime_3_13_amd64_load`: `fed8cf9e5f1383405d7d4eab590d4bcc13843c131f53e36d6246bb2fef779928`
- `pyva_runtime_3_13_arm64_load`: `db115323d8fe5c6ee4b2a21c4d586d66ed8f8680126453b5b387f5215540f371`
- `pyva_runtime_3_14_amd64_load`: `dacbd40fa27b77ebccace7b8afd8c1f10d40c1c6db8b77821ee7bf22ca855efa`
- `pyva_runtime_3_14_arm64_load`: `017c27b93b891631caff5495fefbbe8a40bb8c3160a7b0ece15a846b0af273ba`

## Live publication: Python 3.13.16

Immutable ref: `index.docker.io/librebuilder098/pyva-runtime:3.13.16-java21-debian13-20261015T170914Z-gef7f84fe5b134206b927081af39bd0fb76c492bd`.
Index ref: `index.docker.io/librebuilder098/pyva-runtime@sha256:a3065911aba086691b357ea847e6636651a8a809edf73141e616803a3ddca708`.
Verified amd64 child: `sha256:044850d1d275b8de101879f536b4243b0d265804ef9d27fef4a59e6d9d6bfbd9`; arm64 child: `sha256:c62143f8e1e877d26b94d3ad5aa0e777071ee860914d40bd849bbcbc234e0eca`.

`release.sh` exited successfully from the clean release commit with no
`--channel`: pre-upload base/POI gates, exact loaded config/layer comparisons,
remote index/child verification and explicit pull/run for both platforms all
passed. Published outputs match both independent builds.

## Live publication: Python 3.14.8

Immutable ref: `index.docker.io/librebuilder098/pyva-runtime:3.14.8-java21-debian13-20261015T170914Z-gef7f84fe5b134206b927081af39bd0fb76c492bd`.
Index ref: `index.docker.io/librebuilder098/pyva-runtime@sha256:e9699e5d19255b03d30c848cd15f1cb5824b3e13fca6d73a1a5880506711d85b`.
Verified amd64 child: `sha256:6a16d8935d1ece574ddb938286929ae0c6f94d1ec2cb0b2881b106e5b8430a85`; arm64 child: `sha256:68b24ba9fffa6fb532be144bf65a870f280d05cc2cf87f28abff6a3a58a01400`.

The second sequential `release.sh` invocation exited successfully from the same
clean source commit without `--channel`. Both platform base/POI gates, candidate
config/layer comparisons, remote index/child verification and explicit platform
pull/run passed. All four post-pull runtimes across both minors passed the full
smoke, including installer absence; registry outputs match independent builds.

## Final registry preservation and result

After both successful publications, all previous immutable refs retain their
exact initial digests. Both minor channels and global `latest` remain confirmed
absent. No additional aliases were created and no Git push was performed.

| Previous tag | Unchanged digest / state |
| --- | --- |
| `3.13.15-java21-debian13` | `sha256:3a7d328bbdf6ed7b02862268a6ba1e912b307fdb6840a827f80f1d62f28a96be` |
| `3.13.15-java21-debian13-20261001T184533Z-ga614dc1adbfe4e83d8e72f1a4299c1858b03be64` | `sha256:22eee02d8a7a31d89662d67df550849b0c8f026e08bbace89139ba56371edaee` |
| `3.13.15-java21-debian13-20261001T192201Z-g3073daf024a16da3817706ac0a29daf0d94ec16f` | `sha256:22eee02d8a7a31d89662d67df550849b0c8f026e08bbace89139ba56371edaee` |
| `3.14.7-java21-debian13-20261001T192201Z-g3073daf024a16da3817706ac0a29daf0d94ec16f` | `sha256:91d5802af51361e5f332bad8883faf74bbf509bd13f1026d79f81117afc1410d` |
| `3.13-java21-debian13` | confirmed absent |
| `3.14-java21-debian13` | confirmed absent |
| `latest` | confirmed absent |

Both requested releases and all project verification gates are complete.
The source checkout remains clean at the recorded release commit. Final evidence
and task progress are recorded in the main working copy; the unrelated CI
change was preserved. Corporate scanner and consumer application checks were
not available, as documented in the cleanup change validation.
