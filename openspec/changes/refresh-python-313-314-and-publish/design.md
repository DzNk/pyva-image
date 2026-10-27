# Design

## Context

См. `proposal.md` для мотивации. `update_python_manifest.py` уже выбирает максимальный стабильный patch обеих веток из latest Astral, требует оба stripped GNU/GIL-enabled архива и атомарно сохраняет URL/SHA-256. `runtime_image.bzl` получает patch через minor mapping: отдельные правки metadata и loaders не нужны. `release.sh` проверяет обе платформы, публикует OCI index и проверяет registry digests и pull/run.

## Goals / Non-Goals

**Goals:** воспроизводимое обновление inputs и проверенная публикация двух minor index существующим release flow.

**Non-Goals:** изменение resolver, packaging и правил публикации; добавление новых зависимостей и CI.

## Decisions

- Использовать штатный updater и `bazel mod tidy` / `bazel mod deps`; не редактировать generated fragment вручную. Это сохраняет атомарную проверку полноты и существующую политику latest Astral. Python.org подтверждает выпуск, но источником бинарных inputs остаётся Astral.
- Использовать `release.sh` отдельно для `3.13` и `3.14` с аргументом `docker.io/librebuilder098/pyva-runtime`. Не добавлять `--channel`: неизменяемые теги выполняют запрос публикации без изменения дополнительных aliases.
- Перед публикацией зафиксировать проверенные inputs, lock и planning artifacts в чистом локальном release commit. Git push не нужен. Во время двух публикаций не изменять tracked файлы: release identity зависит от одного commit, а release gate запрещает dirty checkout. Итоговое `validation.md` и отметки задач сохранить после обеих публикаций.
- Повторно использовать существующие тесты и runtime/POI gates, не создавать тесты для простого обновления версий. Не обходить отказ исполнения любой архитектуры.

## Risks / Trade-offs

- [Latest Astral может измениться к применению] → заново разрешить версии штатным updater и записать точный выбранный tag, patches и checksums.
- [Регрессия Python или несовместимость JPype] → выполнить base smoke и Apache POI интеграцию для четырёх вариантов до публикации соответствующего minor.
- [Одна ветка опубликована, вторая завершилась ошибкой] → записать частичный результат; исправить причину и повторить штатную immutable digest проверку, не перезаписывать существующие теги.
- [Совпадение immutable tag с другим digest] → остановиться согласно `release.sh`; не обходить защиту и не удалять прошлые релизы.

## Migration Plan

Обновить inputs и lock, выполнить проверки, создать чистый release commit, последовательно выпустить обе ветки, сохранить commit, полные теги, index/child digests и результаты исполнения в `validation.md`. Существующие теги остаются доступны. Откат потребителя — возврат на предыдущий проверенный digest; исправленный релиз получает новый commit-qualified тег.
