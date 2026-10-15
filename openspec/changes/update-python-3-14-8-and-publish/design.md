# Design

## Context

Мотивация и согласованный scope — в `proposal.md`. `update_python_manifest.py` уже атомарно выбирает обе minor-ветки из одного Astral release и сохраняет четыре stripped GNU/GIL артефакта. `runtime_image.bzl` получает patch через `MINOR_MAPPING`, поэтому labels, annotations и локальные теги обновятся автоматически.

`release.sh` принимает minor и Docker Hub repository, требует чистый commit, строит index, запускает base/POI на обеих платформах, сверяет candidate configs/layers, защищает существующий immutable tag и проверяет registry digests и оба pulled images. Внешние credentials скрипт не сохраняет. `--channel` — отдельная необязательная операция, которую пользователь исключил из этого релиза.

Наблюдения при планировании 2026-10-15:

| Inputs | Сейчас | Ожидаемый release |
| --- | --- | --- |
| Astral | 20260929 | 20261013 |
| CPython 3.13 | 3.13.15 | 3.13.16 |
| CPython 3.14 | 3.14.7 | 3.14.8 |

Источники: [Python 3.14.8](https://www.python.org/downloads/release/python-3148/), [Astral latest metadata](https://raw.githubusercontent.com/astral-sh/python-build-standalone/latest-release/latest-release.json), [четыре stripped GNU assets в release 20261013](https://github.com/astral-sh/python-build-standalone/releases/expanded_assets/20261013). Наличие assets подтверждено по GitHub; скачивание `SHA256SUMS` и проверка bytes относятся к apply и пока не выполнены.

## Goals / Non-Goals

**Goals:** сохранить точные integrity-verified inputs, доказать совместимость четырёх образов и опубликовать два проверенных OCI index с конкретной версией и source identity.

**Non-Goals:** новый updater/release API, изменение упаковки, обновление ОС/JVM/rules, реализация соседнего CI change, Git push и обновление любых подвижных registry tags.

## Decisions

### 1. Повторно использовать существующий updater

Обновить generated fragment и lock вместе через `update_python_manifest.py`, `bazel mod tidy` и `bazel mod deps`. Сверить четыре URL/SHA-256 с `SHA256SUMS` того же captured release tag, `minor_mapping` и фактические repositories через `bazel mod show_repo @pythons_hub @cpython_3_13_amd64 @cpython_3_13_arm64 @cpython_3_14_amd64 @cpython_3_14_arm64`.

Не редактировать generated fragment вручную и не добавлять выбор minor в updater: пользователь согласовал обе ветки. Если latest к apply изменится, допускается другой Astral tag только при тех же ожидаемых patches и наличии всех четырёх нужных assets; иначе остановить обновление scope до фиксации inputs и публикации. Для повторного использования captured tag доступны существующие `download`, `refresh` и `RELEASES`, новый CLI не нужен.

### 2. Сохранить существующую проверочную матрицу

Для каждого minor/arch выполнить `smoke_test.sh` и target-platform POI image/run из `CONTRIBUTING.md`. Smoke проверяет exact Python patch, native imports, Java 21, libjvm, UID/GID, `/app`, certificates и отсутствие shell/package manager. Отдельно проверить `/usr/bin/python` и `/usr/bin/python3` на ожидаемые версии. Перед upload `release.sh` повторяет base/POI gates для точного candidate.

Новые тесты для простого обновления данных не нужны: используются `test_python_manifest.py`, его `--bazel` проверка, `test_release.sh` и `test_repository.sh`. В соответствии с существующей `Stripped runtime compatibility` измерить четыре stripped Python layers относительно checksum-verified unstripped артефактов того же patch/release и той же упаковки в временном checkout. Baseline не попадает в release inputs.

Сверить два index и четыре child digests после повторной сборки из того же release commit в отдельном Bazel output base с `--lockfile_mode=error`; версии и inputs между сборками не обновлять. Это проверяет повторяемость конкретных новых inputs, а не меняет build engine.

### 3. Публиковать последовательно из чистого release checkout

Проверить diff и создать локальный commit только из inputs/lock и документов данного change. Существующий untracked `add-github-actions-dockerhub-publish` не добавлять и не удалять. Для release использовать отдельный detached worktree от зафиксированного commit; никаких обходов `clean_source` и включения посторонних файлов в релиз.

Перед upload записать текущее состояние minor channels и прежних immutable refs из последнего release evidence. Repository передавать внешним аргументом: использовать существующий Docker Hub destination из README. Credentials использовать через имеющуюся Docker авторизацию; не читать и не публиковать секреты. Проверить Docker API 1.49+ и реальное исполнение amd64/arm64; исторические результаты прошлой сборки не доказывают готовность текущего окружения.

В чистом worktree выполнить последовательно:

```sh
bash release.sh 3.13 <docker-hub-repository>
bash release.sh 3.14 <docker-hub-repository>
```

Оба вызова без `--channel`. Не создавать дополнительные remote aliases даже вида `X.Y.Z-java21-debian13`: использовать действующий dated commit-qualified формат. Новые каналы и `latest` не создаются, существующие не меняются. Независимый CI change предлагает channel updates и не должен запускаться как часть этой публикации.

### 4. Зафиксировать проверяемый результат

`validation.md` хранит captured Astral tag, patches, четыре URL/checksums, source commit/UTC timestamp, результаты regressions, слой/baseline sizes, повторную сборку, локальные/remote index и child digests, оба immutable refs и четыре post-pull результата. После релиза повторно сверить прежние immutable refs и состояние minor channels.

Постпубликационное evidence писать в основной рабочей копии, не меняя чистый release checkout во время `release.sh`. Не считать весь change завершённым, пока обе публикации и все проверки не подтверждены фактическими результатами.

## Risks / Trade-offs

- ARM64 execution, Docker API или внешняя авторизация недоступны → устранить конкретную проблему окружения; не пропускать платформу и не ослаблять release gates.
- Upstream metadata изменится или archive недоступен → использовать captured integrity-verified inputs; не подменять ожидаемый patch или flavor молча.
- Одна minor-публикация прошла, другая упала → сохранить успешный immutable artifact, записать частичный результат и повторить неуспешный release из того же commit. Публикация двух minor не атомарна.
- Совпадение immutable tag с другим digest либо ошибка registry inspection → штатный fail-closed; не перезаписывать и не трактовать ошибку как отсутствие тега.
- Два publisher работают одновременно → выполнять данный релиз последовательно и не запускать параллельную публикацию тех же tags; registry не предоставляет compare-and-set.
- Полная матрица и baseline увеличивают расход диска → использовать временные output bases и удалять только созданные для этой проверки outputs после фиксации результатов.

## Migration Plan

После фиксации inputs и локальных проверок создать clean release checkout, сравнить повторные build digests, выполнить оба verified releases, записать evidence и выдать потребителю конкретные immutable refs/index digests. Потребитель обновляет свой `FROM` явно.

Для отката потребитель возвращает прежний immutable ref/digest. Если требуется откат сохранённых project inputs, восстановить предыдущие fragment/lock отдельным source commit; существующие registry artifacts не удалять и не заменять.
