# Design

## Context

See proposal.md for motivation. The updater and its test currently select `install_only` and explicitly reject `install_only_stripped`; the runtime macro packages the resulting repository. The rules_python catalog can shadow a saved artifact, so this change follows `pin-python-selection-to-astral-manifest`.

## Goals / Non-Goals

**Goals:** Reduce the deployed Python layer without changing the selected patch, ABI, platform or image interface.
**Non-Goals:** Local stripping, GUI-library removal, Java module trimming, new architectures or production publication.

## Decisions

- Use Astral's upstream stripped archive, verified by its own SHA256SUMS record, instead of running a host strip tool. Astral defines it as the install-only distribution without debug symbols: [distribution documentation](https://github.com/astral-sh/python-build-standalone/blob/main/docs/distributions.rst).
- Select the highest stable patch for each minor first, then require its exact stripped flavor. Never choose an older patch merely because it has a stripped archive. Retain GIL-enabled baseline x86_64 GNU constraints.
- Extend the existing updater regression file; exercise the exact native platform overrides introduced by the prerequisite, including a same-version built-in unstripped artifact.
- Compare Python tar contents/uncompressed bytes for the same patch before and after, with identical packaging. Run both existing runtime and POI checks rather than inventing a benchmark harness.

## Risks / Trade-offs

- [Missing flavor] → Fail before replacing the old generated input.
- [Reduced native debugging information] → Document the trade-off; unstripped artifacts remain upstream, not a second image target.
- [Same patch tag, changed image digest] → Do not publish over an existing release; use an unpublished patch or separate explicitly selected repository for any authorized future publication.
- [Runtime-pruning change affects measurement] → Keep the before/after package contents identical and report separate effects.

## Migration Plan

Apply strict Astral selection first, update flavor matching and saved input, rebuild both variants and record measured sizes. Roll back by restoring the previous generated input and updater policy together. No registry writes are part of implementation acceptance.
