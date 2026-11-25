# Proposal

## Why

В `MODULE.bazel.lock` закреплён OpenJDK `21.0.8`, а действующий smoke-тест проверяет только major. Нужны воспроизводимые обновления Java независимо от Debian, два варианта LTS для потребителей и проверка порогов CVE-2026-114938 перед выпуском. [Бюллетень Eclipse Adoptium](https://adoptium.net/news/2026/11/temurin-november-2026-cspu-java4shell)

## What Changes

- Сначала перевести Java 21 на официальные tarball-архивы Eclipse Temurin JRE с закреплёнными URL и SHA-256, начиная с исправленного релиза `21.0.13.1+2`. Сохранить пути и проверить работу текущих четырёх платформенных образов.
- Затем добавить Java 25, начиная с `25.0.5.1+2`, через ту же упаковку. Python 3.13 и 3.14 доступны с каждым Java major на amd64 и arm64. Получаются четыре OCI индекса и восемь платформенных образов. В существующих командах Java 21 остаётся значением по умолчанию. [Архивы Temurin 21](https://github.com/adoptium/temurin21-binaries/releases/expanded_assets/jdk-21.0.13.1%2B2) · [Архивы Temurin 25](https://github.com/adoptium/temurin25-binaries/releases/expanded_assets/jdk-25.0.5.1%2B2)
- Проверять внутри образа точную выбранную JVM перед публикацией и после pull. Применять пороги `21.0.13.1` и `25.0.5.1` к соответствующим веткам Java. Обычные feature- и develop-сборки используют базовый smoke.
- Существующий GitHub Actions workflow обновляет pins Temurin в том же процессе, что и Astral. Релизный запуск из основной ветки собирает, проверяет и публикует четыре baseline индекса в Docker Hub через `release.sh`, а также сохраняет текущие релизы Java 21 для amd64-v2/v3.

## Capabilities

### New Capabilities

- `java-runtime-update-automation` — обнаружение, проверка и обновление закреплённых Eclipse Temurin JRE для двух LTS.

### Modified Capabilities

- `python-jvm-runtime-image` — закреплённый релиз Temurin для каждого Java major.
- `python-minor-image-builds` — четыре комбинации Python и Java на обеих архитектурах.
- `dockerhub-image-publication` — релизные теги для каждого сочетания, проверка JVM и публикация из Actions.

## Impact

`MODULE.bazel`, `BUILD.bazel` и `runtime_image.bzl` задают архивы и цели обеих веток Java. `smoke_test.sh`, `image_manifest.py` и `release.sh` проверяют выбранную пару. Java 21 сохраняет существующие команды, пути JVM и теги. Новые варианты получают теги `java25`. GitHub Actions публикует в настроенный Docker Hub repository, а `README.md` и `CONTRIBUTING.md` описывают выбор варианта и выпуск.
