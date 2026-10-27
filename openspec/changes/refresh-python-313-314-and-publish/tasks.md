# Tasks

## 1. Обновление Python inputs

- [x] 1.1 Выполнить `python3 update_python_manifest.py`, `bazel mod tidy`, `bazel mod deps`; проверить diff fragment и lock: обе ветки используют максимальные стабильные patches выбранного Astral release и четыре точных stripped GNU/GIL-enabled URL/SHA-256. Записать выбранные версии и tag в `validation.md`.
- [x] 1.2 Выполнить `python3 test_python_manifest.py` и `python3 test_python_manifest.py --bazel`; проверить совпадение фактических Bazel inputs с сохранёнными версиями, URL и SHA-256, записать результаты в `validation.md`.

## 2. Сборка и подготовка релиза

- [x] 2.1 Собрать `//:pyva_runtime_3_13` и `//:pyva_runtime_3_14`; проверить локальные index через `image_manifest.py local`: у каждого ровно amd64/arm64 с общей patch identity. Записать результаты в `validation.md`.
- [x] 2.2 Выполнить `bash test_repository.sh`, `python3 test_image_manifest.py`, `bash test_release.sh` и `bash -n release.sh smoke_test.sh test_release.sh`; убедиться, что проверки прошли, и записать результаты в `validation.md`.
- [x] 2.3 Проверить diff на посторонние изменения и секреты, зафиксировать inputs, lock и документы change в локальном release commit; проверить пустой `git status --porcelain --untracked-files=all`. До окончания обеих публикаций держать результаты и прогресс вне tracked файлов.

## 3. Публикация и проверка Docker Hub

- [ ] 3.1 Выполнить `bash release.sh 3.13 docker.io/librebuilder098/pyva-runtime` без `--channel`; проверить успешные base/POI checks обеих платформ, remote index/child digests и pull/run, сохранить вывод вне checkout до завершения следующей задачи.
- [ ] 3.2 Из того же чистого commit выполнить `bash release.sh 3.14 docker.io/librebuilder098/pyva-runtime` без `--channel`; проверить успешные base/POI checks обеих платформ, remote index/child digests и pull/run, сохранить вывод.
- [ ] 3.3 После публикаций дополнить `validation.md`: release commit, выбранные patches/Astral tag, полные immutable Docker Hub теги, index и child digests, результаты четырёх runtime/POI проверок и pull/run. Проверить соответствие фактическому выводу release-команд; отметить выполненные задачи только по полученным результатам.
