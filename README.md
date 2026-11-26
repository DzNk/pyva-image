# pyva-runtime

**Python · Java 21 / 25 · JPype · Apache POI · Distroless**

[Docker Hub: librebuilder098/pyva-runtime](https://hub.docker.com/r/librebuilder098/pyva-runtime)

## Русский

Образ для приложений, которым нужно вызывать Java-код из Python через JPype:
например, работать с документами через Apache POI.

Python **3.13 / 3.14** с Eclipse Temurin **21 / 25** на Debian **13**.
Все четыре пары доступны для **linux/amd64** и **linux/arm64**. Выберите тег
`3.13-java25-debian13` или `3.14-java25-debian13` для Java 25.
Теги `amd64-v2/v3` больше не обновляются. Для обновлений используйте
соответствующий базовый канал, например `3.14-java21-debian13`.
Запуск от UID/GID `65532`, рабочая папка `/app`; без shell и пакетного менеджера.
Python-зависимости и Java JAR-файлы добавляет приложение; JPype и POI не включены.
pip, ensurepip и setuptools отсутствуют; зависимости готовятся в отдельном builder.

PEM-сертификаты: `/etc/certs`, по умолчанию `SSL_CERT_DIR=/etc/certs`.
Каталог изначально пуст; скопируйте свои сертификаты, как в примере ниже.

Сборка, зависимости, тесты и публикация: [CONTRIBUTING.md](CONTRIBUTING.md).

## English

A runtime for calling Java code from Python through JPype:
for example, processing documents with Apache POI.

Python **3.13 / 3.14** with Eclipse Temurin **21 / 25** on Debian **13**.
All four pairs support **linux/amd64** and **linux/arm64**. Select
`3.13-java25-debian13` or `3.14-java25-debian13` for Java 25.
The `amd64-v2/v3` tags are retired. For updates, use the matching baseline
channel, such as `3.14-java21-debian13`.
Runs as UID/GID `65532` in `/app`, without a shell or package manager.
The application supplies Python dependencies and Java JARs; JPype and POI are not bundled.
pip, ensurepip and setuptools are absent; prepare dependencies in a separate builder.

PEM certificates: `/etc/certs`, default `SSL_CERT_DIR=/etc/certs`.
The directory starts empty; copy your certificates as shown below.

Build, dependencies, tests and releases: [CONTRIBUTING.md](CONTRIBUTING.md).

## Пример / Example

После локальной загрузки образа / After loading the image locally:

```Dockerfile
FROM pyva-runtime:3.13-amd64
COPY --chown=65532:65532 app/ /app/
COPY certs/ /etc/certs/
CMD ["/app/main.py"]
```
