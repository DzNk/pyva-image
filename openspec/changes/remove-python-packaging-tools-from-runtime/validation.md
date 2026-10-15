# Validation

## Environment and scope

2026-10-15: Docker 29.8.2, server API 1.56. Existing ARM64 execution verified
with local CPython 3.14.7 reporting `aarch64`. No binfmt or credentials changed.
The corporate scanner, its findings and consumer repository are unavailable;
corporate scan disappearance and consumer cffi findings have not been verified.

## Exact payload comparison on original pinned inputs

Built all four original Python layers from Astral 20260929 (3.13.15/3.14.7),
saved them, then rebuilt with file selection and the same inputs/packaging.
Each image lost exactly 563 entries belonging to the specified installer paths.
Every retained file had the same content hash, tar entry type, permission mode
and symlink target; no unrelated files were added or removed.

| Python | Architecture | Original tar bytes | Filtered tar bytes | Retained entries |
| --- | --- | ---: | ---: | ---: |
| 3.13.15 | amd64 | 98160640 | 90224640 | 1240 |
| 3.13.15 | arm64 | 78366720 | 70440960 | 1240 |
| 3.14.7 | amd64 | 101130240 | 93204480 | 1288 |
| 3.14.7 | arm64 | 80855040 | 72919040 | 1288 |

## Implementation checks

`python3 test_image_manifest.py` passed: plain/gzip OCI layers, hidden installer
payload below a whiteout, code/metadata/vendor/wheel/helper paths, invalid paths,
corrupt/malformed layers and retained unrelated package files/metadata.
`python3 test_python_manifest.py` passed.

Runtime, POI, final-input and independent-build results are recorded below.

All four cleaned original-input images passed full base smoke, installer absence,
negative pip/ensurepip invocation and creation/execution of `venv --without-pip`.
Both original-input OCI indexes passed all-layer inspection. Release regression,
repository ignore check and shell syntax checks passed.

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

## Result and scanner limit

All specified project implementation and verification checks passed. The
corporate scanner was not run, and no claim is made about cffi filename-based
findings or consumer dependencies reintroducing installer packages.
