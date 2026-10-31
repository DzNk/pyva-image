# Design

## Context

См. `proposal.md` о мотивации. `.github/workflows/` отсутствует; `.bazelversion` фиксирует Bazel 8.5.1. `BUILD.bazel` предоставляет четыре platform images/loaders и два OCI index/push targets. `release.sh [--channel] <minor> <repository>` уже выполняет весь релизный контракт: чистый Git checkout, детерминированный тег, base/POI на обеих платформах, защиту неизменяемого тега, проверку опубликованных digest и pull/run, затем обновление канала по digest.

`smoke_test.sh` использует `docker image inspect --platform` (API 1.49+). POI Dockerfile расширяет локально загруженный runtime. Поэтому CI должен поддерживать ARM64 execution, multi-platform image store и доступ Docker builder к локальным образам. Активное изменение `optimize-python-runtime-packaging` касается runtime-слоёв; workflow использует targets из выбранного коммита и не зависит от завершения этого изменения.

`update_python_manifest.py` уже читает latest metadata Astral и атомарно сохраняет четыре `install_only_stripped` URL и SHA-256 для стабильных Python 3.13/3.14. Updater не вызывается обычной сборкой. Его существующий контракт выбора Python сохраняется; новое поведение — автоматический запуск и публикация результата без PR.

## Goals / Non-Goals

**Goals:** Один workflow поверх существующих команд, полный цикл от релиза Astral до Docker Hub без участия оператора после однократной настройки, изоляция write/publish credentials от PR, бесплатная публичная конфигурация и сериализация обновлений и публикаций.

**Non-Goals:** Новая сборочная система, дублирование release gates, автоматическое обновление Java/Debian/Bazel/rules или списка Python minors, PR/auto-merge для обновлений Python, native ARM matrix с переносом OCI layouts, удалённый cache, платные runners, смена видимости репозиториев или настройка секретов через tracked files.

## Decisions

### Один workflow и матрица только по Python minor

Создать `.github/workflows/ci.yml` с `schedule` (`23 4 * * *`, ежедневно в 04:23 UTC), `pull_request` в `main`, `push` в `main` и `workflow_dispatch`. Default branch должна быть `main`. Все jobs имеют guard публичного репозитория; scheduled/manual runs вне `refs/heads/main` не запускают обновление, write authentication или release. По умолчанию `permissions: contents: read`, checkout с `persist-credentials: false`, actions фиксируются полным commit SHA с комментарием версии.

Для доверенных событий сначала выбрать актуальный `main` после получения publication concurrency group, чтобы ожидавший run не вернул каналы к устаревшему event SHA. На schedule/manual подготовить обновление по процедуре ниже; push использует уже сохранённые входные данные без updater. Передать точный выбранный или созданный SHA через job output. Все последующие jobs явно checkout этот SHA, а не плавающую ветку и не исходный `github.sha` до обновления. PR проверяет свой event commit без записи в репозиторий.

На выбранном коммите запустить `bash test_repository.sh`, `python3 test_python_manifest.py`, `python3 test_python_manifest.py --bazel`, `python3 test_image_manifest.py`, `bash test_release.sh` и shell syntax checks. За ними — runtime job с matrix `minor: ["3.13", "3.14"]`, `fail-fast: false`, чтобы сбой соседнего minor не прервал активную публикацию. Release получает timestamp из этого же коммита; сборка не обновляет закреплённые зависимости и не оставляет tracked changes.

Для PR runtime job собирает minor OCI index, запускает `smoke_test.sh` и существующие POI build/run команды для обеих архитектур из `CONTRIBUTING.md`. Для доверенного schedule/push/manual run этот же job после проверки configuration и login вызывает `bash release.sh --channel "$MINOR" "$DOCKERHUB_REPOSITORY"`: скрипт сам выполняет runtime gates, повторять их отдельными шагами перед ним не требуется. Авторизация относится к каждому minor; публикация двух minors не является общей транзакцией. Environment approval и другие ручные gates для доверенных релизов не требуются.

Альтернатива — независимые native arch jobs и merge/publish job — требует передачи и проверки OCI artifacts и изменения текущего release flow. QEMU на одном стандартном x64 runner на minor позволяет использовать существующий скрипт целиком.

### Автоматическая фиксация Python и повтор выпуска

Только job подготовки schedule/manual получает `contents: write`. После checkout актуального `main` сохранить исходный SHA и запустить существующие `python3 update_python_manifest.py`, `bazel mod tidy` и `bazel mod deps`. Сравнить новые patch versions с сохранёнными численно: не допускать downgrade. Сбой metadata/checksums, отсутствие одной архитектуры или prerelease не должны приводить к коммиту или публикации частичного обновления. Изменение URL/SHA-256 из нового релиза Astral при том же Python patch также является обновлением входных данных.

Проверить согласованность generated fragment/lock и существующие offline regressions до записи в remote. Разрешить tracked changes только в `python_runtimes.MODULE.bazel` и `MODULE.bazel.lock`, staging делать явным списком, неожиданные изменения прекращают run. Если diff отсутствует, оставить исходный SHA без пустого коммита. Иначе создать bot commit с обоими файлами и обычным fast-forward push в `main`; новый SHA разрешён для release только после успешного push. Если `main` изменился параллельно или запись запрещена, завершить run с ошибкой без force push, автоматического rebase, изменения branch protection или публикации локального коммита. Следующий scheduled run начнёт заново с актуального `main`.

Для push использовать временную авторизацию `GITHUB_TOKEN` без сохранения credentials в checkout; токен не должен попадать в diff, логи или build context. После push публикация продолжается через зависимые jobs этого же run: [push с `GITHUB_TOKEN` не запускает новый push workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow). PAT, GitHub App, PR и дополнительный dispatch для этого не нужны.

На каждом schedule/manual после успешной подготовки выполнять release обоих minors, даже если fragment не изменился. Это даёт автоматический retry после ситуации «bot commit сохранён, один minor не опубликован» без нового коммита и отдельного хранилища статуса. Существующий `release.sh` повторно проверяет совпадающий immutable index и обновляет только проверенный канал. Успешный повтор использует прежний commit-derived tag; нового релиза по текущим часам нет. Цена простоты — ежедневная повторная сборка и проверки даже без новых релизов; новые caches и маркеры успешной публикации в первой версии не нужны.

### Бесплатный runner и совместимый Docker

Использовать стандартный `ubuntu-24.04` в публичном репозитории: [GitHub подтверждает бесплатные стандартные runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). Публичность remote не была достоверно установлена во время discovery; это проверяемое условие активации, а не обещание бесплатности private runs. Guard публичности не позволяет workflow выделять runners после переноса в private repository.

Bazelisk/setup action должен читать существующую `.bazelversion`; caches оставить выключенными. Использовать официальный `docker/setup-docker-action` с фиксированной совместимой версией Engine/CLI (API 1.49+) и `features.containerd-snapshotter: true`, затем `docker/setup-qemu-action` для ARM64 в том же Docker context. Проверить наличие Buildx и пользоваться стандартным `docker` builder, который видит загруженные локальные base images; отдельный `docker-container` builder здесь не нужен. [Docker описывает настройку containerd store и QEMU для Actions](https://docs.docker.com/build/ci/github-actions/multi-platform/).

Конкретные проверенные action SHA и Engine patch фиксируются при реализации. Не загружать image tarballs, Bazel output или caches в Actions storage. Это также сохраняет чистый checkout: временные файлы и Docker config находятся вне source tree. Платные cache/storage не требуются для рабочего первого варианта.

### GitHub Variables/Secrets вместо встроенного namespace

Repository variables: `DOCKERHUB_REPOSITORY` с полным поддерживаемым destination и `DOCKERHUB_USERNAME`; repository secret: `DOCKERHUB_TOKEN` с Read/Write правами к целевому репозиторию. Все три обязательны для release; username может отличаться от namespace назначения. Публичный Docker Hub repository на Personal покрывает сценарий без платной подписки, с [лимитами Docker Hub](https://docs.docker.com/docker-hub/usage/).

Проверку наличия configuration и `docker/login-action` выполнять только для schedule/push/manual на `main`; token передавать лишь в login step, а не в общий job environment, updater или PR steps. Destination передавать через environment и цитированный shell argument, без подстановки expression в исполняемый shell source. Валидация destination остаётся в `release.sh`. Не включать shell tracing; стандартный logout cleanup action удаляет credentials в конце job. Альтернатива с hardcoded account или новым registry client не нужна и противоречит существующему destination contract.

Однократные prerequisites: Actions enabled, default branch `main`, разрешённый job-level `contents: write` и правила `main`, позволяющие выбранному bot identity обычный push обновлений. Workflow сам не ослабляет branch protection и не требует секретов в чате. Если правила требуют обязательный PR для всех identities, оператор должен заранее настроить разрешённую автоматизацию; в противном случае полный автомат не активирован и push должен явно завершаться ошибкой.

### Сериализация без отмены активного релиза

Workflow-level concurrency использует одну фиксированную publication group для schedule/push/manual на `main`, а для PR — отдельную group по номеру PR. Группа охватывает весь цикл: выбор `main`, обновление, bot push, проверки и публикацию. Для publishers `cancel-in-progress: false`; для PR можно отменять предыдущую проверку того же PR. Это не допускает перекрытия двух CI-релизов одной ветки независимо от trigger. Matrix minors изменяют разные теги и могут выполняться параллельно внутри одного run.

Группа действует только внутри данного GitHub repository. Локальные и внешние publishers требуют согласованного окна запуска. Concurrency не обещает FIFO или публикацию каждого промежуточного push: pending runs могут быть заменены; свежий run публикует своё состояние. Не вводить распределённую блокировку или очередь.

## Risks / Trade-offs

- [QEMU медленнее native ARM и может выявить несовместимость JVM] → выполнять реальные base/POI checks, установить конечный timeout, не пропускать ARM failures; переходить на native jobs только при измеренной необходимости.
- [Стандартный runner ограничен диском, холодная сборка повторяет downloads] → отдельный runner на minor, без хранения tarballs в Actions; измерить первый запуск. Cache добавлять только если он нужен и укладывается в бесплатные storage limits.
- [Docker Hub throttling или ошибки authentication] → доверенные runs выполняют login, а release preflight прекращает публикацию при неопределённой ошибке; повторять тот же commit без изменения immutable tags.
- [Один minor опубликован, другой завершился ошибкой] → общий workflow сообщает failure, успешный minor остаётся опубликованным; retry идемпотентен. Двухминорная атомарность не предусмотрена.
- [External publisher обходит concurrency] → документировать единственного активного publisher и ограничение GitHub group; существующий immutable protection сохраняется.
- [Branch protection или запрет write token блокирует bot push] → явно проверить однократную настройку; не обходить правила и не публиковать незаписанный кандидат.
- [Релиз CPython ещё не появился в Astral] → ждать полного стабильного Astral release для обеих архитектур; новые prereleases и Python minor lines не подключать автоматически.
- [GitHub задерживает или отключает расписание] → cron вне начала часа, автоматический повтор на следующем запуске и документированный ручной запуск для восстановления. По [правилам GitHub](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule) schedule может задерживаться, а в публичной репе отключается после 60 дней отсутствия активности; полный автомат не означает SLA или обход отключённого Actions.

## Migration Plan

1. Добавить workflow, минимальные runnable проверки автоматического обновления/workflow и документацию; проверить `actionlint`, offline regressions и текущие base/POI команды без записи в remote Git или registry. На fixtures и временном Git remote проверить update/no-change, failed push, отказ частичного обновления и повтор выпуска после сбоя.
2. В `CONTRIBUTING.md` дать оператору однократный список prerequisites: публичные GitHub/Docker Hub repositories, default branch `main`, Actions enabled, разрешение bot push, Variables/Secret и Docker Hub token Read/Write. Не вводить подтверждения на каждый релиз.
3. После попадания workflow в `main` проверять PR path и первый scheduled/manual trusted run в GitHub; фиксировать фактические run URL, выбранный/bot commit SHA, оба immutable tags/index digests, оба channels и повтор без нового коммита только после реального запуска. До активации результатом реализации служат проверенный workflow и инструкция настройки.
4. Для rollback сначала отключить автоматическое обновление/публикацию, затем revert workflow или входных данных; опубликованные immutable releases не удалять. При необходимости вернуть minor channel на ранее проверенный index существующей командой из `CONTRIBUTING.md`. Оставленный активным schedule снова выберет latest Astral и отменит ручной rollback канала.
