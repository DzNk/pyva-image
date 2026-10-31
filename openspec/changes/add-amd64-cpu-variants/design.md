# Design

## Context

См. `proposal.md` для цели. Текущая реализация использует два minors, четыре Astral archives, четыре platform images и два двухплатформенных OCI indexes. `release.sh`, `image_manifest.py` и smoke checks предполагают amd64/arm64; workflow запускает по одному release job на minor. Автообновление и публикация уже работают из сохранённого чистого SHA; это изменение расширяет их, не создавая второй release engine.

На 2026-10-31 в [Astral 20261026](https://github.com/astral-sh/python-build-standalone/releases/download/20261026/SHA256SUMS) подтверждены GIL-enabled GNU `install_only_stripped` и соответствующие unstripped archives для x86_64_v2/v3, Python 3.13.18/3.14.10. При реализации updater заново разрешает latest; эти номера не являются новым hardcode.

В закреплённом `rules_python` 2.3.4 `single_version_platform_override` поддерживает custom platform keys и ограничения выбора toolchain. В `rules_oci` 2.3.0 `oci_image` запрещает переопределять `os`, `architecture` или `variant`, когда задан `base`. Это определяет способ повторного использования текущей amd64 базы.

## Goals / Non-Goals

**Goals:** Явный выбор оптимизированного CPython, общий patch для четырёх вариантов каждого minor, переиспользование слоёв и проверок, совместимость текущих default-команд и полноценный CI/release для новых тегов.

**Non-Goals:** Автовыбор ISA из общего индекса, поддержка v4, перекомпиляция Python/Java/Debian, настройка JVM флагов, новый registry client, новая зависимость или benchmark framework. Измеренный speedup не является условием выпуска; документация не заявляет его без фактических измерений.

## Decisions

### Восемь inputs через существующий resolver и rules_python

Расширить `PLATFORMS` и parser на `amd64_v2` / `amd64_v3` с точными triples `x86_64_v2-unknown-linux-gnu` / `x86_64_v3-unknown-linux-gnu`. Для highest stable patch каждого minor требовать все четыре stripped artifacts из одного Astral release. Только после полной валидации атомарно сохранять generated fragment; сравнение версий в `ci_update_python.py` продолжает запрещать downgrade, а whitelist записи остаётся fragment + lock.

В generated fragment использовать существующие `single_version_platform_override` и `use_repo` для дополнительных repository aliases `cpython_<minor>_amd64_v2` / `_v3`. У custom entries задать `target_compatible_with = ["@platforms//:incompatible"]`, не объявлять их host-compatible через `arch`/`os_name`. Их `//:files` и bin labels используются напрямую для упаковки, а toolchain resolution не выбирает их автоматически. Сохранить default host Python 3.12 и baseline mappings. Проверка `--bazel` должна подтвердить как точные восемь URLs/SHA-256, так и отсутствие оптимизированного host/target выбора.

Отдельные `http_archive` дали бы ещё один способ объявления Python repositories и дублировали бы их BUILD/filegroup setup. Custom platform mechanism уже предоставляет нужную форму файлов; новые загрузчики или расширения не нужны.

### Архитектура и CPU-вариант — отдельные параметры

Расширить существующий `runtime_image` необязательным `cpu_variant`, оставив `arch="amd64"` для v2/v3. Базовая архитектура определяет Distroless base, Java слои и `/usr/lib/jvm/java-21-openjdk-amd64`; CPU-вариант — Python repository, суффикс target/local tag и metadata. `runtime_layers("amd64")` определяется один раз и используется всеми тремя amd64 images. Python packaging и удаление installation tools работают для всех вариантов через текущие helpers.

Добавить targets вида `//:pyva_runtime_3_13_amd64_v2` и `_load` с локальным тегом `pyva-runtime:3.13-amd64-v2` (аналогично v3 и 3.14). Default aliases `:3.13`, `:3.14`, baseline loaders и их точные локальные version tags не переопределять.

Оптимизированные images наследуют `linux/amd64` из той же базы и добавляют label и annotation `io.pyva.cpu.variant=v2|v3`. Version metadata сохраняет `X.Y.Z-java21-debian13`; CPU identity проверяется отдельно. Baseline metadata без CPU label считается baseline; пометка v2/v3 в baseline-кандидате отвергается. Отдельный CPU tag является способом выбора: `--platform linux/amd64/v3` и отказ Docker при запуске на старом CPU не обещаются. Это позволяет не писать преобразователь OCI layouts и не менять зависимости ради optional platform-variant field.

### Отдельные OCI indexes и совместимое расширение release

Default index каждого minor по-прежнему содержит ровно amd64 и arm64. Добавить `//:pyva_runtime_<minor>_amd64_v2_index` / `_v3_index` и соответствующие push targets: каждый index содержит одну amd64 image. Сохранить index format для повторного использования immutable protection и digest-based channel copy.

`release.sh` получает необязательный `--cpu v2|v3`; отсутствие флага сохраняет текущий interface и двухплатформенный путь. `--channel` продолжает означать явный запрос канала. Неподдерживаемые CPU значения и CPU selection для arm64 в smoke/build CLI отвергаются до работы Docker/Bazel. `smoke_test.sh` также получает optional `--cpu` при настоящем `--arch amd64`, не превращает `amd64-v3` в Debian architecture и выбирает соответствующий loader/image tag.

| Release selection | Index contents | Immutable family | Moving channel |
| --- | --- | --- | --- |
| default | amd64 + arm64 | `X.Y.Z-java21-debian13` | `X.Y-java21-debian13` |
| `--cpu v2` | one amd64, CPU label v2 | `X.Y.Z-java21-debian13-amd64-v2` | `X.Y-java21-debian13-amd64-v2` |
| `--cpu v3` | one amd64, CPU label v3 | `X.Y.Z-java21-debian13-amd64-v3` | `X.Y-java21-debian13-amd64-v3` |

Все immutable families получают существующий суффикс `-<commit-time-UTC>-g<full-SHA>`. Для каждой selection выполняется тот же порядок: clean checkout, локальная integrity/installer проверка, base/POI, immutable preflight, upload/reuse, remote index/child digest comparison, явный pull и smoke, затем запрошенный channel по проверенному digest. Одна команда не меняет соседние CPU/minor tags; опубликованные старые immutable artifacts не переписываются.

В `image_manifest.py` расширить existing helpers/modes явным CPU selection и ожидаемым набором платформ: default строго две, optimized строго одна. Сохранить default CLI и формат результата для текущих callers/tests. Для CPU paths проверять label/annotation, patch identity, index/config/diff_ids и каждый layer blob; не заменять проверки простым разрешением любого одноэлементного индекса. Test fixtures должны отвергать baseline под CPU tag, неверный CPU label, лишнюю платформу, несовпадающий config и скрытые installers.

### CI: шесть release selections, восемь executions

Расширить текущую runtime matrix на `minor: [3.13, 3.14]` × `cpu: [baseline, v2, v3]`. Default job выполняет две архитектуры, optimized job — один amd64 вариант. `fail-fast: false` и общая workflow concurrency group сохраняются; каждый job обновляет только свои теги. Сбой v3 не отменяет уже начавшийся baseline release, но весь run сообщает failure. Следующий daily run повторяет все selections, в том числе если updater не создал коммит.

PR выполняет те же восемь base/POI executions без secrets и публикации. Trusted jobs вызывают расширенный `release.sh`, сохраняя текущие source SHA outputs, permissions, configuration и login guards. Обновить workflow policy/update regressions: текущие assertions про два minor jobs недостаточны для шести selections.

Перед optimized execution записать и проверить CPU flags Linux runner по стандартным требованиям x86-64-v2/v3, включая необходимые SIMD/OS-enabled features для v3. Запускать image нативно на совместимом x64 runner; v2/v3 нельзя просто пропустить или заменить baseline при отсутствии capabilities. ARM64 сохраняет существующий QEMU путь. Если стандартный hosted runner не обеспечивает нужный CPU, проверка явно падает; платный runner или обход проверок не добавляется автоматически.

## Risks / Trade-offs

- [Пользователь запускает v3 на несовместимом CPU] → явные суффиксы, CPU metadata и предупреждение в обеих README секциях; default baseline остаётся переносимым. Это не механизм автоматического fallback.
- [Hosted runner не поддерживает ISA или скрывает flags] → fail before publication с конкретным недостающим набором; recorded flags и реальные runtime/POI execution обязательны. Изменение runner strategy потребует отдельного согласования, если понадобится.
- [Отсутствие одного v2/v3 artifact блокирует refresh] → сохранить прежние восемь inputs целиком; не выпускать смесь patches и не откатываться к старшему доступному baseline.
- [Рост времени CI] → шесть стандартных jobs с общими layer definitions, без переноса layouts между jobs и без нового paid/cache storage. Оптимизация pipeline — только по измеренным результатам.
- [Слишком широкая валидация single-platform index ослабляет default release] → явная selection и отдельные negative tests; default по-прежнему требует обе платформы.
- [Оптимизация не даёт заметного ускорения] → публикация означает совместимость и конкретный artifact, а не гарантию скорости; пользователь может сравнить свою нагрузку на baseline/v2/v3.

## Migration Plan

1. Расширить saved inputs и module tests, выполнить updater/tidy/deps и подтвердить восемь pinned repositories при прежнем host toolchain.
2. Добавить четыре optimized images/loaders и четыре single-platform indexes; собрать все восемь images. Проверить совместимость, sharing Java/base layers и размеры stripped Python layers относительно соответствующих unstripped архивов того же patch/CPU; записать фактические размеры для всех восьми вариантов.
3. Расширить smoke/release/manifest regressions до записи в registry. Старые default команды должны проходить прежние проверки; negative CPU/arch, tag collision, registry error и failed pull/channel cases не обходятся.
4. Обновить CI, README и CONTRIBUTING. Проверить actionlint, policy fixtures и полный PR-equivalent путь; не утверждать hosted успех без actual run.
5. Отправить реализацию и полные pinned inputs чистым новым commit в `main`. Событие `push` должно само запустить hosted сборку восьми images и публикацию шести indexes/channels; не заменять этот запуск ручным dispatch или локальным release. Дождаться actual run, записать run URL, source SHA, tags, index/child digests и CPU execution evidence в validation. Отказ запуска или публикации — незавершённая проверка, а не успешный выпуск.
6. Для rollback сначала отключить автоматизацию, затем вернуть каждый CPU channel к ранее проверенному digest либо baseline в потребителе. Не удалять immutable tags. Текущие общий index и baseline команды остаются доступны.
