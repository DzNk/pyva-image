# Spec Delta

## MODIFIED Requirements

### Requirement: Complete Python runtime
The image SHALL contain the CPython standard library except the optional `ensurepip` installer bootstrap, runtime-facing native extension modules, and the shared libraries required to use them without installing operating-system packages at runtime. The `venv` module SHALL remain available without automatic pip bootstrapping.

#### Scenario: Import representative native modules
- **WHEN** Python imports `ssl`, `ctypes`, `sqlite3`, `bz2`, `lzma`, `uuid`, `readline`, and `multiprocessing`
- **THEN** every import succeeds in the running image

#### Scenario: Use Python as the primary process
- **WHEN** a consumer supplies a Python script as the container command
- **THEN** the configured entrypoint executes that script with `/usr/bin/python3`

#### Scenario: Create an environment without an installer
- **WHEN** a consumer imports `venv` and creates a virtual environment with `--without-pip` in a writable directory
- **THEN** its Python interpreter executes without requiring `ensurepip`, pip or setuptools

## ADDED Requirements

### Requirement: No bundled Python package installation tools
Each base runtime image SHALL omit pip, its vendored libraries, ensurepip and its bundled wheels, and standalone setuptools, pkg_resources, `_distutils_hack` and `distutils-precedence.pth`, including their distribution metadata and installer entrypoints. This policy SHALL apply to Python 3.13 and 3.14 on amd64 and arm64.

#### Scenario: Inspect all supported base runtimes
- **WHEN** any supported base image is inspected without consumer additions
- **THEN** pip, ensurepip, setuptools and pkg_resources are not importable or listed as installed distributions
- **AND** their code, bytecode, bundled wheels and distribution metadata are absent
- **AND** `/usr/bin/pip`, `/usr/bin/pip3` and `/usr/bin/pipX.Y` are absent, including dangling symlinks

#### Scenario: Installer invocation is unavailable
- **WHEN** `python -m pip --version` or `python -m ensurepip` is invoked in a base runtime
- **THEN** the command fails because the corresponding module is absent

### Requirement: Packaging payload absent from delivered layers
No OCI layer delivered in a base runtime image SHALL contain the excluded Python installation tools or their bundled payload. Deleting or hiding those files in a later layer SHALL NOT satisfy this requirement. Removing packaging payload SHALL preserve unrelated interpreter files, permissions and symlinks.

#### Scenario: Inspect image blobs independently of merged filesystem
- **WHEN** every layer referenced by a supported platform image manifest is inspected, including compressed layers
- **THEN** none contains the excluded installer files, metadata or ensurepip wheels, including vendored msgpack and pkg_resources within pip

#### Scenario: Preserve the remaining Python payload
- **WHEN** the filtered Python layer is compared with the same saved interpreter input under the same packaging configuration
- **THEN** files outside the explicitly excluded packaging paths retain their contents, executable permissions and symlink targets

### Requirement: Execute dependencies installed in a builder
The runtime SHALL execute compatible application dependencies installed in a separate builder and copied into the image without requiring pip or setuptools unless the application itself uses their runtime APIs. Dependency metadata and package data SHALL remain usable. Base-image filtering SHALL NOT delete or rewrite consumer dependency payload.

#### Scenario: Run copied native and Java dependencies
- **WHEN** target-platform Python dependencies are installed in a compatible builder, copied with their metadata into `/opt/python`, and executed with that path available to Python
- **THEN** the JPype/Apache POI workload succeeds for both supported minors and architectures without installation commands or network access in the final runtime
- **AND** `importlib.metadata` can read the copied installed distribution version

#### Scenario: Preserve similarly named consumer files
- **WHEN** an application copies dependencies containing `cffi/setuptools_ext.py` or explicitly required standalone msgpack
- **THEN** the base-image packaging policy leaves those files and their owning distribution metadata intact

#### Scenario: Explicit application requirement for setuptools APIs
- **WHEN** an application uses runtime APIs from setuptools or pkg_resources
- **THEN** the consumer must supply a compatible distribution providing those APIs with the application's dependencies
- **AND** the base image does not provide an implicit fallback or remove that consumer-supplied distribution
