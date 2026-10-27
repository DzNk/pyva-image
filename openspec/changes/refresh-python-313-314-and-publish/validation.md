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

Обе публикации завершились с кодом 0 из чистого release commit `3f746426bce70e56737229bd2094d40c68bae7e8` (committer time UTC: `20261027T072058Z`).

Python 3.12 используется только сборочными инструментами Bazel; в опубликованных образах исключительно Linux Python 3.13.18/3.14.10. Изменение renderer проверено assert-проверками и повторным `test_python_manifest.py --bazel`.

Для каждого minor успешно выполнены base runtime smoke и JPype1 1.7.1 / Apache POI 5.4.1 XLSX integration на linux/amd64 и linux/arm64. После публикации verified remote index содержит ровно эти две платформы; index и child digests совпали с локальными. Обе платформы явно загружены из registry по index digest, их config/layer digests проверены, base smoke повторно прошёл на каждой.

### Published artifacts


- Tag: `index.docker.io/librebuilder098/pyva-runtime:3.13.18-java21-debian13-20261027T072058Z-g3f746426bce70e56737229bd2094d40c68bae7e8`
- Index reference: `index.docker.io/librebuilder098/pyva-runtime@sha256:a883bf2f0137db9d7906429cf29070adca6cd6fe154b37ca08cc15f900f06949`
- amd64 manifest: `sha256:005f403af831d9ffb86beb145eb7db75402eba4c7a3ab054e569ab9cbc77dcc0`
- arm64 manifest: `sha256:0a87a70db89d8aa003fc34c960b77a3a5bba40759c33457f21cccc02af2e9f6e`

- Tag: `index.docker.io/librebuilder098/pyva-runtime:3.14.10-java21-debian13-20261027T072058Z-g3f746426bce70e56737229bd2094d40c68bae7e8`
- Index reference: `index.docker.io/librebuilder098/pyva-runtime@sha256:3ec12675a14fe5f40bf0d4c9ac7acb0efba0d284d812694ea98c72c4d3b8ac17`
- amd64 manifest: `sha256:1aefcfec09cbfccfe95951c1cee1832af03cca56623d69f757053112567a7b0f`
- arm64 manifest: `sha256:8862db2c29c54b9db4a26c5e854d33bb4f833cea90ee025f31341392e874f76a`

Публикации выполнены без `--channel`; moving channels и global latest не изменялись. Git push не выполнялся. Полные локальные логи: `/tmp/pyva-python-release.PiZkic/python313.log` и `/tmp/pyva-python-release.PiZkic/python314.log`.
