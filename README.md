# pyva-runtime

**Python · Java 21 · JPype · Apache POI · Distroless**

## Русский

Образ для приложений, которым нужно вызывать Java-код из Python через JPype:
например, работать с документами через Apache POI.

Python **3.13 / 3.14**, OpenJDK **21**, Debian **13**;
платформы **linux/amd64** и **linux/arm64**.
Запуск от UID/GID `65532`, рабочая папка `/app`; без shell и пакетного менеджера.
Python-зависимости и Java JAR-файлы добавляет приложение; JPype и POI не включены.

PEM-сертификаты: `/etc/certs`, по умолчанию `SSL_CERT_DIR=/etc/certs`.
Каталог изначально пуст; скопируйте свои сертификаты, как в примере ниже.

Сборка, зависимости, тесты и публикация: [CONTRIBUTING.md](CONTRIBUTING.md).

## English

A runtime for calling Java code from Python through JPype:
for example, processing documents with Apache POI.

Python **3.13 / 3.14**, OpenJDK **21**, Debian **13**;
platforms **linux/amd64** and **linux/arm64**.
Runs as UID/GID `65532` in `/app`, without a shell or package manager.
The application supplies Python dependencies and Java JARs; JPype and POI are not bundled.

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
