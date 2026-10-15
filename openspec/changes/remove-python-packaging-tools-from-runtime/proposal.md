# Proposal

## Why

pyva-runtime используется для запуска зависимостей, уже установленных или скомпилированных в отдельном Debian builder, но сейчас переносит из Astral также pip, его vendored msgpack и pkg_resources из setuptools, а через ensurepip — ещё и вложенный wheel pip. Эти неиспользуемые компоненты увеличивают состав образа и создают находки сканера; их нужно исключить из поставляемых слоёв, сохранив запуск готового приложения.

## What Changes

- Исключать из Python payload до создания OCI-слоя pip целиком (включая `_vendor`, metadata и команды), ensurepip с bundled wheels и, если присутствуют в upstream runtime, самостоятельный setuptools с его metadata, `pkg_resources`, `_distutils_hack` и `distutils-precedence.pth`. Применять одну политику к Python 3.13/3.14 на amd64/arm64.
- **BREAKING**: базовый runtime больше не предоставляет `python -m pip`, `python -m ensurepip`, pip entrypoints или setuptools/pkg_resources. Создание venv с автоматической установкой pip перестаёт поддерживаться; модуль `venv` сохраняется, вариант `--without-pip` остаётся доступным.
- Сохранить интерпретатор, остальную stdlib, native extensions, JVM и выполнение зависимостей из builder, включая их `.dist-info`, package data и shared libraries. Потребитель переносит необходимые runtime-зависимости явно; если приложение действительно импортирует setuptools/pkg_resources, эта зависимость должна быть установлена в builder и перенесена вместе с приложением.
- Проверять отсутствие удаляемого содержимого в самих OCI blobs, а не только в merged filesystem; повторно проверять все четыре base/JPype/POI варианта без установки пакетов в финальной стадии.
- Обновить описание состава runtime и builder workflow. Не удалять файлы приложений по имени вроде `cffi/setuptools_ext.py` и не запрещать явно нужный приложению самостоятельный msgpack.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `python-jvm-runtime-image`: уточнить границу полного Python runtime исключением ensurepip и инструментов установки/сборки пакетов; закрепить отсутствие их payload в слоях и работоспособность зависимостей, перенесённых из builder.

## Impact

Реализация затронет `runtime_image.bzl` и существующий `smoke_test.sh`; проверка состава OCI-слоёв расширит `image_manifest.py` с небольшим offline regression check. `poi_smoke.py`/`Dockerfile.poi-smoke` затрагиваются только для проверок перенесённых зависимостей; `README.md` и `CONTRIBUTING.md` объяснят новый контракт и ограничения. `BUILD.bazel` и ignore checks корректируются только если необходимы новые test inputs. Новые зависимости, варианты образа и runtime switches не нужны; Python inputs, Debian/JVM и build pins не меняются.

Отдельный незавершённый `optimize-python-runtime-packaging` предлагает сохранить `python -m pip`; это явный конфликт планов. Для runtime без installer при совместной реализации действует контракт данного change, а конфликтующий packaging plan необходимо согласовать до его apply. Артефакты соседних changes здесь не редактируются. Обновление Python до 3.14.8 остаётся отдельным change; эта очистка не зависит от конкретного patch и не включает публикацию или Git push.

Фактический отчёт корпоративного сканера и prod-образ недоступны. Удаление pip устраняет подтверждённый источник vendored msgpack/setuptools из базового образа, но не гарантирует исчезновение всех находок в downstream, включая возможное срабатывание на файл cffi или зависимости, повторно принесённые потребителем.
