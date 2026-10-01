# Proposal

## Why

The Python 3.14 layer is about 240 MiB; its interpreter and libpython alone occupy about 205 MiB. Production runtime images currently carry debug symbols that are not needed for the supported Python/JPype workload.

## What Changes

- Select stable GIL-enabled x86_64 GNU `install_only_stripped` artifacts from the same tagged Astral release.
- Keep exact version, URL and checksum pinning; do not silently fall back to an unstripped or different-platform artifact.
- Measure both variants before and after and rerun the existing runtime and POI checks.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `python-minor-image-builds`: Require upstream stripped runtime archives while preserving minor selection and runtime compatibility.

## Impact

Changes `update_python_manifest.py`, its test, generated runtime inputs and update documentation. Depends on `pin-python-selection-to-astral-manifest` so built-in artifacts cannot shadow the chosen stripped URL. No new dependencies or hand-written strip step. Local validation only; never overwrite a published patch tag with the newly composed digest.
