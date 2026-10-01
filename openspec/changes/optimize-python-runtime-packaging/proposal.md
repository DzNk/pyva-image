# Proposal

## Why

Готовые Python-слои всех четырёх образов содержат команды с `#!/bin/sh`, хотя shell в runtime отсутствует. Эти же слои публикуются несжатыми: измеренные 74.74–96.45 MiB можно сократить примерно до 26.87–33.42 MiB с помощью gzip без удаления библиотек.

## What Changes

- Убирать из Python-слоя shell-обёртки `pip`, `pip3`, `pipX.Y`, `idleX.Y`, `pydocX.Y`, `pythonX.Y-config` и связанные ссылки `idle3`, `pydoc3`, `python3-config`.
- **BREAKING**: перечисленные файлы перестанут присутствовать в runtime; прямой запуск сейчас уже требует отсутствующий shell. Сохранять `/usr/bin/pythonX.Y`, `/usr/bin/python`, `/usr/bin/python3`, стандартную библиотеку и Python-модули, включая запуск `python -m pip` и `python -m pydoc`.
- Сжимать Python-слой штатным gzip в существующем `pkg_tar`; применять одинаковую упаковку к Python 3.13/3.14 на amd64/arm64.
- Проверять состав, размер и воспроизводимость слоёв, загрузку Docker-архивов и существующую Java/JPype/POI-интеграцию; кратко описать команды через `python -m` в `CONTRIBUTING.md`.
- Сохранить текущую матрицу Bazel-целей, общие Java-слои, имена load/push-целей, локальные теги и пути Docker-архивов.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `python-jvm-runtime-image`: задать состав доступных Python-команд и gzip-доставку Python-слоя с сохранением работоспособности и воспроизводимости.

## Impact

Основные изменения реализации: `runtime_image.bzl`, существующие `smoke_test.sh` и `image_manifest.py`, а также `CONTRIBUTING.md`. Проверка gzip-слоёв расширяет существующий OCI-инспектор средствами Python stdlib. `rules_pkg` уже установлен, новые зависимости не нужны. Пины CPython, Debian, JVM и Bazel rules сохраняются.

Это отдельная задача об упаковке Python. Замена приватного `deb_postfix`, Java truststore, перестройка Bazel-файлов и автоматическая публикация новых образов сюда не входят. Новая упаковка изменит digest образов; дальнейшая публикация использует существующую схему нового commit-derived тега, без перезаписи выпущенных артефактов.
