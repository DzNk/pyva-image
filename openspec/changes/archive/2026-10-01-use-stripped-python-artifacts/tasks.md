# Tasks

## 1. Select upstream stripped artifacts

- [x] 1.1 Confirm `pin-python-selection-to-astral-manifest` is implemented, then change the existing updater to require the selected patch's GIL-enabled x86_64 GNU `install_only_stripped` record; extend the existing runnable check with missing flavor, higher unstripped-only patch, prerelease, wrong architecture and built-in same-version shadowing cases, and verify no failed update changes the saved input.
- [x] 1.2 Refresh the authoritative generated input, update README with the debug-symbol trade-off and unchanged explicit refresh workflow, and verify both generated URLs/checksums and native resolved repositories identify the selected stripped archives without adding a local strip command.

## 2. Verify both runtime variants

- [x] 2.1 For unchanged Python patches and identical package selections, record before/after Python layer bytes and verify both stripped layers are smaller; run both existing runtime smoke and Docker POI checks and compare Python versions, OCI labels/annotations, immutable tag identity and linux/amd64 platform. Keep this validation local and do not overwrite existing registry tags.
