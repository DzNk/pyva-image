# Local stripped runtime validation

Baseline rebuilt before changing archive selection on 2026-10-01.
Astral release: `20260929`. Runtime packaging (`runtime_image.bzl`), Java
packages, base image and both Python patches remain unchanged.

| Python patch | Unstripped Python layer tar bytes | Stripped Python layer tar bytes | Reduction |
| --- | ---: | ---: | ---: |
| 3.13.15 | 258990080 | 98160640 | 62.1% |
| 3.14.7 | 250664960 | 101130240 | 59.7% |

Sizes are uncompressed `pkg_tar` outputs, including tar headers/padding:
`stat -c '%n %s' bazel-bin/pyva_runtime_3_13_python_layer.tar bazel-bin/pyva_runtime_3_14_python_layer.tar`.

Checks passed:

- `python3 test_python_manifest.py` and `python3 test_python_manifest.py --bazel`:
  numeric patch ordering, strict flavor requirement, invalid/conflicting input,
  atomic refresh and native same-version catalog override regression.
- `bazel mod show_repo @cpython_3_13 @cpython_3_14`: exact stripped URLs and
  checksums agree with `python_runtimes.MODULE.bazel` and tagged Astral SHA256SUMS.
- `bazel mod tidy` and both load/push target builds (push targets built, not run).
- Both tarballs loaded locally; `bash smoke_test.sh 3.13 pyva-runtime:3.13`
  and `bash smoke_test.sh 3.14 pyva-runtime:3.14` passed for exact saved patches.
- Both `Dockerfile.poi-smoke` builds and container runs passed: JPype started
  Java 21, Apache POI wrote `/tmp/poi-smoke.xlsx`, ZIP structure assertions passed.
  The existing missing Log4j provider warning did not fail either check.
- OCI manifest annotations, config labels, local load tags and generated push
  tags match `3.13.15-java21-debian13` and `3.14.7-java21-debian13`; both configs
  remain `linux/amd64`. Both measured Python layers are strictly smaller.

Validation is local only. No image was published and no registry tag overwritten.
