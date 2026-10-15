# Design

## Context

Мотивация и контракт — в `proposal.md` и delta `python-jvm-runtime-image`. Сейчас `runtime_image.bzl` передаёт весь `@cpython_<minor>_<arch>//:files` в `pkg_files`, отдельно переупаковывает executables, затем создаёт Python `pkg_tar`. Поэтому исходные installer files входят в образ независимо от consumer requirements. `Dockerfile.poi-smoke` уже устанавливает JPype в builder, копирует `/python` в `/opt/python` и в финальной стадии только запускает приложение.

Проверено 2026-10-15, без изменения образов:

| Объект | Наблюдение |
| --- | --- |
| Локальный `pyva-runtime:3.14-amd64` | CPython 3.14.7; pip 26.2.1; есть `pip/_vendor/msgpack` и `pip/_vendor/pkg_resources`; самостоятельные setuptools/pkg_resources не импортируются |
| Сохранённые amd64 Python tar layers для 3.13.15 и 3.14.7 | Есть pip metadata, vendored msgpack и `ensurepip/_bundled/pip-26.2.1-py3-none-any.whl`; нет самостоятельных setuptools metadata/module, pkg_resources module и distutils shim |
| Их `pip/_vendor/vendor.txt` | `msgpack==1.1.2`, `setuptools==70.3.0` |
| Исходники packaging | Один общий `runtime_image()` обслуживает четыре варианта; wrappers pip включены в список executables |

Это inventory локального base, не повтор корпоративного скана. Содержимое prod-образа, реальный `cffi/setuptools_ext.py` потребителя и точные scanner findings не проверены.

Первичные источники: [vendor.txt pip 26.2.1](https://raw.githubusercontent.com/pypa/pip/26.2.1/src/pip/_vendor/vendor.txt), [pip vendoring policy](https://pip.pypa.io/en/stable/development/vendoring-policy/), [ensurepip](https://docs.python.org/3.14/library/ensurepip.html), [venv](https://docs.python.org/3.14/library/venv.html), [pkg_resources runtime APIs](https://setuptools.pypa.io/en/latest/deprecated/pkg_resources.html). pip вендорит msgpack и оставляет от setuptools pkg_resources; ensurepip хранит offline installer payload. Следовательно, отсутствие самостоятельного setuptools в site-packages ещё не исключает корректную идентификацию vendored setuptools сканером.

## Goals / Non-Goals

**Goals:** исключить installer payload до упаковки и проверить этот результат в доставляемых blobs; сохранить существующий путь builder → скопированные зависимости → runtime без installer.

**Non-Goals:** универсальная санация чужих site-packages, исправление правил корпоративного сканера, удаление cffi или явно нужного msgpack, новые версии Python/JVM/OS, gzip-оптимизация, отдельный «full» образ, автоматическое восстановление pip, публикация или изменение соседних planning artifacts.

## Decisions

### 1. Фильтровать исходные файлы до Python tar

В `runtime_image.bzl` добавить минимальный приватный Starlark file-selection rule: получить files существующего interpreter target, отфильтровать по путям относительно исходного repository и вернуть retained files через `DefaultInfo`. Подать результат в существующий `pkg_files`, сохранив его path mapping, permissions, symlinks и остальные слои. Убрать `pip`, `pip3`, `pip<minor>` из отдельно включаемых executables и исключить эти paths из общего file selection, чтобы они не вернулись через `//:files`.

Набор исключений относительно Astral root, где `<minor>` — существующий аргумент macro:

- `bin/pip`, `bin/pip3`, `bin/pip<minor>`;
- дерево `lib/python<minor>/ensurepip`, включая `_bundled`, bytecode и вложенные wheels;
- деревья `lib/python<minor>/site-packages/pip`, `setuptools`, `pkg_resources`, `_distutils_hack`;
- metadata directories `pip-*.dist-info` и `setuptools-*.dist-info` непосредственно в том же site-packages;
- файл `lib/python<minor>/site-packages/distutils-precedence.pth`.

Сопоставлять целые path components и package/metadata boundaries. Не использовать общее `pip*`, поиск `setuptools` в любой части имени или удаление всех `.dist-info`/`.whl`. Наличие самостоятельного setuptools необязательно: пустое совпадение допустимо, но появившиеся в upstream файлы из указанного набора не должны попасть в payload. Весь `pip/_vendor` уходит вместе с pip; отдельная модификация msgpack не нужна.

`pkg_files.excludes` в установленном rules_pkg принимает file labels, а не glob patterns. Поэтому не закладывать туда неработающие строковые globs и не добавлять тысячи ручных labels. Небольшой selection rule сохраняет исходные File objects и работает на build host для обеих target architectures без запуска их Python. Upstream repositories, downloaded archives и pinned hashes остаются неизменными.

Альтернативы: consumer `RUN` с удалением оставляет исходный payload в нижнем OCI-слое и не исправляет общий base; удаление только metadata скрывает installed distribution, но оставляет код; удаление только pip оставляет его wheel в ensurepip. Перепаковка upstream архивов отдельным shell/Python pipeline добавляет лишние I/O и обработку tar metadata. Эти варианты не выбираются.

### 2. Сохранить работу перенесённых зависимостей

Builder устанавливает или компилирует зависимости с pip/setuptools, затем переносит только результат, нужный приложению: package trees, native extensions, runtime data, `.dist-info` и необходимые shared libraries. Совпадение Python minor, ABI/GIL, target architecture и совместимого Debian/glibc окружения обязательно; копирование всего site-packages билдера может снова принести pip/setuptools. Скрипты из builder с абсолютным shebang требуют проверки пути интерпретатора; штатный пример запускает приложение через `/usr/bin/python3`.

В документации сохранить текущий `pip install --target /python` в builder и `COPY --from=deps /python /opt/python`, `PYTHONPATH=/opt/python`. pip в финальной стадии не нужен для обычного import готовых пакетов. Если код или legacy entrypoint импортирует setuptools/pkg_resources, потребитель переносит совместимую реализацию явно; общий base такую зависимость не обещает. Не удалять consumer metadata: она нужна `importlib.metadata`, entrypoints и проверкам версий.

`venv` сохраняется; проверить создание и запуск окружения с `--without-pip` в writable temporary path. `python -m pip`, `python -m ensurepip`, default venv pip bootstrap и runtime installation становятся явно неподдерживаемыми. Другие stdlib-модули, в том числе pydoc, этот change не затрагивает.

### 3. Проверять blobs и исполнение через существующие проверки

Расширить существующий `image_manifest.py local`: проверять tar members всех layers двух platform children и отказывать при запрещённом payload. Повторно использовать проверку descriptor size/hash; читать plain/gzip tar средствами stdlib без filesystem extraction. Проверка встроена в `local`, уже вызываемый `release.sh`, поэтому обнаружение installer payload блокирует публикацию без новой команды release.

Добавить небольшой offline `test_image_manifest.py` с минимальными OCI fixtures: разрешённый image, pip code/metadata, vendored subtree, ensurepip wheel, setuptools helpers, payload в нижнем слое с whiteout выше, gzip layer и похожие допустимые имена/consumer metadata. Проверить отказ на malformed/corrupt layers и недопустимые paths. Это проверка installer policy; не превращать её в новый security scanner.

`test_release.sh` создаёт synthetic OCI candidates и вызывает реальный inspector: его fixtures необходимо дополнить валидными tar blobs с согласованными descriptors/config digests. Сохранить все existing release cases и добавить candidate с installer payload, для которого upload не происходит. Проверка `local` относится к базовым candidate images проекта, а не к произвольным consumer images с явными runtime-зависимостями.

Расширить `smoke_test.sh` проверкой module discovery, installed distribution metadata, entrypoints и путей installer payload; использовать exact paths/pattern boundaries, учитывать dangling symlinks. Сохранить текущие imports и все Java/UID/certificate checks, отдельно проверить `venv --without-pip`. Дополнить существующий `poi_smoke.py` чтением версии JPype через `importlib.metadata` и отсутствием installer в финальном image. Dockerfile сохраняет установку только в builder; финальный POI workload для четырёх вариантов запускать без сети.

Сравнить до/после inventory Python tar на одинаковых inputs: меняется только оговорённый набор paths, остальные contents, executable bits и link targets сохраняются. Для всех четырёх image variants проверить каждый referenced layer, base smoke и JPype/POI. Зафиксировать два index/четыре child digests после независимых сборок одного source revision, чтобы filtering не добавил зависимости от времени или порядка файлов. Evidence писать в `validation.md` этого change во время apply, без вымышленных результатов.

### 4. Согласовать соседние changes без смешивания scope

`optimize-python-runtime-packaging` пока сохраняет pip module. Его shell-wrapper/gzip работу можно применять отдельно, но обещание работоспособности `python -m pip` несовместимо с выбранным здесь контрактом и должно быть пересмотрено перед apply того change. Этот proposal явно выбирает отсутствие pip по текущему запросу пользователя; чужие артефакты сейчас не переписываются.

`update-python-3-14-8-and-publish` обновляет только pinned inputs и публикует проверенные outputs. Очистку можно реализовать до новой публикации и включить в её reviewed release commit; при этом подтверждения полного Python layer inventory для этого change необходимо получить уже на окончательных inputs. Сам данный change не выполняет upload и не меняет immutable tags.

## Risks / Trade-offs

- Приложение, startup или initContainer вызывают pip/ensurepip либо неявно используют setuptools/pkg_resources → проверить эти вызовы в consumer перед переходом; нужную runtime-библиотеку перенести явно, installation оставить builder. Корпоративный consumer repo здесь недоступен.
- Сканер считает vendored код или архивы отдельными компонентами → убрать весь pip и ensurepip wheel из каждого доставляемого layer, подтвердить inventory; не объявлять прежние findings шумом без их paths/evidence.
- Scanner finding относится к `cffi/setuptools_ext.py` или явно нужному consumer msgpack → очистка base этот случай не решает; сопоставить finding с владельцем файла, не удалять рабочие зависимости ради имени.
- Потребитель копирует весь system site-packages → installer вернётся как consumer payload; документировать перенос только установленных application dependencies и сохранение их metadata.
- Upstream меняет layout → запрет в OCI inspector и smoke должен обнаружить остатки; проверять все четыре варианта при каждом refresh, не ослабляя проверку отсутствием setuptools сегодня.

## Migration Plan

Реализовать filtering, проверки и документацию; выполнить offline regressions, четыре base и четыре POI проверки и сравнение воспроизводимости. При наличии корпоративного scanner report выполнить повтор тем же scanner/version/config по новым immutable digests; при отсутствии отчёта ограничить доказательство inventory и исполнением, не заявляя «скан чистый».

При отдельной публикации использовать штатный release workflow с новым source commit-derived immutable tag; существующие refs не перезаписывать. Потребитель обновляет `FROM` явно и проверяет запуск основного процесса и migration/initContainer. Откат — на предыдущий immutable digest; восстановление installer в новом base не является автоматическим fallback.
