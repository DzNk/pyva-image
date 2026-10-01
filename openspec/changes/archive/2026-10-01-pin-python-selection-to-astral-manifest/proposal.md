# Proposal

## Why

`add_runtime_manifest_files` merges saved Astral records with the built-in rules_python catalog, chooses the maximum version across both and can retain an existing version/platform URL. Saved release selection therefore is not the sole authority after dependency changes.

## What Changes

- Make the saved Astral-selected version, immutable URL and checksum authoritative for each supported minor.
- Use existing rules_python exact version/platform overrides and explicit minor mappings to pin the saved selection without disabling dependency toolchains.
- Keep explicit updater execution and minor-only build selection; fail on missing or invalid records rather than falling back to built-in data.
- Replace redundant saved representations with one deterministic generated Bazel module fragment and verify catalog-shadowing regressions.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `python-minor-image-builds`: Require exact saved Astral selection despite newer built-in versions or conflicting version/platform artifacts.

## Impact

Changes `update_python_manifest.py`, its test, MODULE integration, generated runtime input, exports and update docs; retires `python.SHA256SUMS` only after its replacement is wired and verified. Use Bazel's native `include()` and rules_python tags rather than a custom module extension. Implement before `use-stripped-python-artifacts`; no new dependencies or automatic network lookup during build.
