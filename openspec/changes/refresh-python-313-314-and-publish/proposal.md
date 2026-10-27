# Proposal

## Why

Закреплённые Python 3.13.16 и 3.14.8 устарели. Нужно обновить обе ветки до свежих стабильных патчей и опубликовать проверенные runtime-образы обеих архитектур в Docker Hub.

## What Changes

- Обновить Python inputs штатным `update_python_manifest.py` и согласовать `MODULE.bazel.lock`. На 2026-10-27 latest Astral — `20261026`, содержащий Python `3.13.18` и `3.14.10` с GNU/GIL-enabled `install_only_stripped` для amd64 и arm64. При применении повторно проверить latest и записать фактически выбранный релиз.
- Пересобрать четыре платформенных образа и два OCI index; выполнить существующие runtime и JPype/Apache POI проверки.
- Опубликовать обе ветки через `release.sh` в `docker.io/librebuilder098/pyva-runtime`, используя уникальные commit-qualified immutable теги; проверить digest и pull/run обеих платформ. Подвижные каналы не обновлять без явного запроса.
- Сохранить версии, проверки и ссылки на опубликованные образы в `validation.md` этого change.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Обновление закреплённых зависимостей и публикация исполняют существующие требования `python-minor-image-builds` и `dockerhub-image-publication`, не меняя контракт. Используется `skip_specs: true`.

## Impact

Меняются `python_runtimes.MODULE.bazel`, связанный `MODULE.bazel.lock` и документы этого change. Повторно используются существующие Bazel targets, loaders, smoke/integration checks и release flow. Distroless, Debian snapshot, Java, build rules и runtime packaging остаются в текущем scope без обновлений. Git push и новые механизмы публикации не требуются.
