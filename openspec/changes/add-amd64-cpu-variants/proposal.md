# Proposal

## Why

Сейчас образы используют универсальную amd64-сборку CPython. Astral также публикует готовые GIL-enabled stripped GNU Linux сборки x86-64-v2/v3: их можно дать пользователям современных CPU с явным выбором, сохранив совместимость существующих amd64/arm64 образов. Прирост производительности зависит от нагрузки и заранее не обещается.

## What Changes

- Добавить Python 3.13/3.14 с вариантами `amd64-v2` и `amd64-v3`: восемь runtime images вместо четырёх. Существующие build/load/release команды и общий индекс `amd64 + arm64` сохраняют поведение по умолчанию.
- Обновлять все восемь Astral inputs атомарно: одинаковый patch и Astral release для четырёх вариантов каждого minor, точные stripped URL и SHA-256, отказ при недостающем артефакте без downgrade или подмены baseline-сборкой.
- Для оптимизированных образов переиспользовать amd64 Distroless/Debian/Java слои. Выбор CPython делать явно; v2/v3 не становятся автоматически выбранными host/toolchain runtimes.
- Публиковать дополнительные single-platform OCI indexes под неизменяемыми тегами `X.Y.Z-java21-debian13-amd64-vN-YYYYMMDDTHHMMSSZ-g<full-commit-SHA>` и явно запрашиваемыми каналами `X.Y-java21-debian13-amd64-vN`, где `N` — 2 или 3. Оптимизированные images остаются `linux/amd64`, а метаданные и документация явно показывают минимальный CPU. Общий индекс не получает новых amd64 entries и не обещает автовыбор ISA.
- Расширить существующие smoke/POI, integrity/installer, immutable/digest/pull проверки и GitHub Actions на новые варианты. Первый push реализации в `main` сам запускает hosted сборку и публикацию всех восьми images без Run workflow; результат подтверждается actual run URL и registry digests. Scheduled/manual обновление, повтор после сбоя, изоляция PR и сериализация publishers сохраняются; CPU-специфичные теги обновляются только после своих проверок.
- Добавить короткую информацию о вариантах в обе языковые части README и команды выбора/проверки/публикации, CPU prerequisites и rollback в `CONTRIBUTING.md`.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `python-minor-image-builds`: расширить набор сборок и атомарный выбор Astral до baseline amd64, amd64-v2, amd64-v3 и arm64; зафиксировать явный выбор оптимизированного CPython и совместимость существующих сборок.
- `dockerhub-image-publication`: добавить отдельные CPU tags/indexes и runtime/digest gates для выбранного CPU-варианта, сохранив строгую двухплатформенную проверку default release и автоматическую публикацию всех поддерживаемых вариантов.

## Impact

Затрагиваются updater и generated fragment/lock, `BUILD.bazel`, `runtime_image.bzl`, `image_manifest.py`, `smoke_test.sh`, `release.sh`, `ci_update_python.py`, workflow, связанные regression checks, README и CONTRIBUTING. Повторно используются `rules_python` custom platform overrides, `rules_oci`, текущие layer builders и release flow; новые зависимости, runtime Dockerfile и самостоятельная сборка CPython не требуются. Нужна проверка CPU возможностей hosted runner перед v2/v3 execution; несовместимость не должна превращаться в пропущенную успешную проверку.
