# Validation

2026-10-31. Implementation based on current upstream `main`
`8db83a401b2ea8b35f7ea4e9bd63db1cf5a81ff2`. SSH read access and the public GitHub
repository/default branch `main` were verified; `main` is not protected.

## Passed locally

- `actionlint 1.7.12 .github/workflows/ci.yml`: syntax, expressions, action inputs
  and shell checks passed. Downloaded executable archive matched SHA-256
  `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8`.
- `python3 test_ci_workflow.py`: public/main/event guards, job dependencies,
  frozen commit propagation, isolated write/publish credentials, serialized
  publishers, pinned actions, no artifact/cache uploads and missing configuration
  passed. Removing publication guards was detected.
- `python3 test_ci_update.py`: eleven offline scenarios passed using real temporary
  Git repositories and the actual workflow push shell. Covered numeric patch
  ordering, new Astral artifacts at the same patch, unchanged inputs/retry without
  another commit, downgrade, incomplete/invalid upstream data, unexpected files,
  failed preparation checks, rejected push and a concurrent main update. Upstream
  downloads and Bazel were fixtures; failures did not change remote source.
- `bash test_repository.sh`, `python3 test_python_manifest.py`,
  `python3 test_python_manifest.py --bazel`, `python3 test_image_manifest.py`,
  `bash test_release.sh` and `bash -n release.sh smoke_test.sh test_release.sh`
  passed. Existing release regressions include immutable collision, uncertain
  registry errors, idempotent reuse and both-platform/channel gates.
- `bazel build //:pyva_runtime_3_13 //:pyva_runtime_3_14` passed. Both
  `image_manifest.py local` inspections passed, including every layer's installer
  exclusion and blob integrity.
- For Python **3.13.18** and **3.14.10**, base smoke and JPype1 1.7.1 / Apache POI
  5.4.1 XLSX integration passed on **linux/amd64 and linux/arm64**. The commands
  used local Docker builds/runs and did not publish images. Local Docker Engine
  29.8.2, API 1.56, Buildx 0.37.2 and the `docker` driver were verified, including
  ARM64 execution and builder access to loaded local images. Docker 29.8.2's
  pinned runner download URL returned HTTP 200.
- `bazel mod tidy` and `bazel mod deps` ran in an isolated checkout. They exposed
  formatting-only drift in `MODULE.bazel` and the generated Python fragment.
  The initial implementation normalizes those lists and the renderer's blank
  line once; the resulting files match tidy output. No Python version, URL,
  checksum, dependency version or existing release gate was changed.
- `openspec validate add-github-actions-dockerhub-publish --strict` and
  `git diff --check` passed. No credentials, image tarballs, caches or generated
  build outputs are included in the change.

## Hosted activation and verification

At local validation time no GitHub run or Docker Hub authentication/publication
has been claimed. The user's variables/secret are consumed only by a trusted
hosted run; their values are not retrieved or printed locally.

1. Push the reviewed workflow to `main` and record the actual run URL and source
   SHA from Actions. Confirm `refresh` skips on a main push and that both runtime
   jobs use the SHA selected by `checks`.
2. Verify both runtime/POI executions per minor, immutable tags/index and child
   digests, both explicit platform pulls, and that each minor channel matches its
   verified immutable index. A failed job is not a successful publication.
3. Dispatch `Python runtime` on `main` to exercise refresh immediately. Record the
   bot SHA if inputs change, and confirm the same run publishes it without an
   extra push trigger, PR or approval. If unchanged, confirm no empty commit and
   reuse/verification of matching immutable content.
4. Observe the next daily schedule at 04:23 UTC. Transient failures retry on the
   next scheduled preparation/release; rejected writes and failure recovery are
   already covered offline without deliberately corrupting the public registry.
5. PR/fork validation, non-main dispatch, private-repository runner skipping and
   a real upstream version transition remain hosted scenarios to observe, not
   claims based on static checks. Disable automation before channel/source
   rollback; GitHub can delay or disable schedules as documented in CONTRIBUTING.
