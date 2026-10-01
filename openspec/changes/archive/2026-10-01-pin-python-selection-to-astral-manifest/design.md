# Design

## Context

See proposal.md. The installed rules_python implementation merges its built-in manifest before the additional manifest, keeps the first version/platform record, and computes minor mappings over every available version. Native `single_version_platform_override` replaces exact URLs/checksums; `override(minor_mapping=...)` pins the supported minors. Restricting `available_python_versions` breaks rules_python's own mandatory `python_3_11` repository import and is not used.

## Goals / Non-Goals

**Goals:** One authoritative generated runtime input with deterministic native toolchain registration.
**Non-Goals:** A custom Bazel extension/resolver, multiple manually synchronized version files, fetching latest metadata during builds or changing architectures.

## Decisions

- Keep the stdlib updater as the explicit network boundary. Parse stable baseline GNU x86_64 candidates and select each minor's highest patch using integer version tuples; reject missing records, malformed hashes and conflicting records for the chosen artifact.
- Generate a single checked-in `python_runtimes.MODULE.bazel` instead of maintaining SHA256SUMS plus a second exact-version mapping. It owns the Python extension binding, exact `single_version_platform_override` tags, explicit minor mappings, defaults, minor-only toolchains and existing repository aliases. Leave other catalog minors available for dependency toolchains.
- Replace the original Python registration block in MODULE with native `include("//:python_runtimes.MODULE.bazel")`. Included fragments have separate variable bindings, so the fragment defines its own `use_extension`; it must not reference the parent's Python variable. [Bazel include contract](https://bazel.build/versions/7.7.0/rules/lib/globals/module).
- Retain `@pythons_hub//:versions.bzl` as the actual metadata source. Exact overrides replace a built-in artifact for the same version/platform; explicit mappings for 3.13 and 3.14 prevent a newer built-in patch from winning for either image.
- Validate both minors before producing output, render deterministically, and replace the one generated file atomically using stdlib filesystem operations. Retire the old manifest and export only after the new fragment is wired.
- Extend the existing runnable parser check with version ordering, missing/invalid/conflicting data and exact emitted override assertions. Verify Bazel's generated repository URLs/checksums and supported minor mappings for saved patches both older than and equal to built-in entries, while retaining dependency minors such as 3.11; no permanent fake catalog fork is needed.

## Risks / Trade-offs

- [Generated fragment stale relative to updater] → Commit it as the sole authoritative runtime selection; updating rules_python alone must not change saved patches.
- [An output contains unsafe source text] → Emit only validated version/platform/digest values and fixed-host immutable URLs.
- [Switching representation breaks fresh checkout] → Replace MODULE wiring, exports and generated fragment together, verify a clean resolution, then remove obsolete input.
- [Stripped artifact proposal intersects this selection] → Apply this change first while preserving the current flavor; the next change modifies flavor matching only.

## Migration Plan

Generate equivalent exact inputs from the existing saved release, wire native include, verify both toolchains and image identities, then retire python.SHA256SUMS and update README. No patch advance is required merely to migrate representation. Restore MODULE, old input and updater together for rollback.
