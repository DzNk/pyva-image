# Validation

## Python inputs

2026-10-27: штатный updater выбрал Astral `20261026`, CPython `3.13.18` и `3.14.10`. Для каждой ветки закреплены GNU/GIL-enabled `install_only_stripped` для amd64 и arm64 с URL и SHA-256 из tagged SHA256SUMS.

`bazel mod tidy` и `bazel mod deps` завершились успешно. Автоматическое форматирование списков MODULE.bazel отменено; зависимости не менялись. Lock дополнен сгенерированной записью host Go SDK для macOS arm64.

## Passed checks

- `python3 test_python_manifest.py`: Astral selection, exact overrides and atomic refresh passed.
- `python3 test_python_manifest.py --bazel`: native Bazel catalog isolation passed; saved patches, URLs and SHA-256 win.
- `bash test_repository.sh`: repository ignore regression passed.
- `python3 test_image_manifest.py`: OCI policy passed, включая every layer, gzip, hidden installers, retained dependencies and integrity.
- `bash test_release.sh`: deterministic identity, immutable protection, both-platform gates and verified channel copy passed.
- `bash -n release.sh smoke_test.sh test_release.sh`: passed.

## Release status

`bazel build //:pyva_runtime_3_13 //:pyva_runtime_3_14` завершился успешно. Оба `image_manifest.py local` подтвердили ровно linux/amd64 и linux/arm64, общую patch identity, целостность blobs и отсутствие Python installation tools во всех слоях.

- Python 3.13.18 index: `sha256:a883bf2f0137db9d7906429cf29070adca6cd6fe154b37ca08cc15f900f06949`.
- Python 3.14.10 index: `sha256:3ec12675a14fe5f40bf0d4c9ac7acb0efba0d284d812694ea98c72c4d3b8ac17`.

Публикация и runtime/POI проверки ещё не выполнены.
