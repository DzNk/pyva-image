# Proposal

## Why

В базовых образах закреплены CPython 3.13.15 и 3.14.7 из Astral 20260929. Python 3.14.8 уже выпущен; необходимо обновить обе поддерживаемые ветки и опубликовать проверенные образы для amd64 и arm64 с воспроизводимой идентичностью релиза.

## What Changes

- Обновить сохранённые Python inputs штатным `update_python_manifest.py`: ожидаемые версии 3.13.16 и 3.14.8, GNU/GIL-enabled `install_only_stripped` для обеих архитектур, точные URL и SHA-256. На момент планирования latest Astral — 20261013.
- Обновить `MODULE.bazel.lock` вместе с generated fragment; собрать четыре образа и два OCI index, выполнить существующие base smoke и JPype/Apache POI проверки.
- Из чистого release commit выполнить обе публикации через `release.sh` в существующий Docker Hub destination из README, передаваемый аргументом. Использовать только уникальные теги `X.Y.Z-java21-debian13-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>`; пользователь явно исключил `--channel`, подвижные теги и `latest`.
- Проверить remote index/child digests и выполнить явные pull/run обеих платформ для каждого minor; записать фактические версии, commit, теги, digest и результаты в `validation.md`.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Это обновление закреплённых зависимостей и исполнение существующих требований `python-minor-image-builds`, `python-jvm-runtime-image` и `dockerhub-image-publication`. Контракт выбора Python и публикации не меняется, поэтому change объявляет `skip_specs: true` и не создаёт delta specs.

## Impact

Изменяются `python_runtimes.MODULE.bazel`, связанный `MODULE.bazel.lock` и документы данного change. Существующие build targets, metadata, loaders, `smoke_test.sh`, `Dockerfile.poi-smoke` и `release.sh` уже получают patch из сохранённых inputs и повторно используются без нового release-кода.

Под «обновить базовый образ» здесь понимается Python/JVM runtime данного проекта: обновление Distroless digest, Debian snapshot, Java или Bazel rules не требуется. Нужны Docker с API 1.49+, исполнение обеих архитектур и действующая внешняя Docker Hub авторизация. Независимый незакоммиченный change `add-github-actions-dockerhub-publish` нужно сохранить вне release checkout; реализация CI, Git push и изменение чужих planning artifacts в этот scope не входят.
