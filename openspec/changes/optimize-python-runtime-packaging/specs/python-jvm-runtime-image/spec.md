# Spec Delta

## ADDED Requirements

### Requirement: Python command entrypoints without shell wrappers
Each supported runtime image SHALL retain executable `/usr/bin/pythonX.Y` for its selected Python minor and working `/usr/bin/python` and `/usr/bin/python3` aliases. It SHALL omit the shell-dependent commands `/usr/bin/pip`, `/usr/bin/pip3`, `/usr/bin/pipX.Y`, `/usr/bin/idleX.Y`, `/usr/bin/pydocX.Y`, `/usr/bin/pythonX.Y-config` and their `/usr/bin/idle3`, `/usr/bin/pydoc3`, `/usr/bin/python3-config` aliases. Removing these command files SHALL preserve the bundled standard library, native extensions, shared libraries and Python modules, including `pip` and `pydoc`.

#### Scenario: Inspect commands in every supported image
- **WHEN** the filesystem of any Python 3.13 or 3.14 image on amd64 or arm64 is inspected
- **THEN** the listed shell-dependent command files and aliases are absent, including dangling symlinks
- **AND** the versioned interpreter and both retained aliases execute and report the exact selected CPython patch

#### Scenario: Run Python modules without shell wrappers
- **WHEN** a consumer runs `python -m pip --version` or invokes the command-line help of `python -m pydoc` in any supported runtime image
- **THEN** the corresponding Python module starts successfully without requiring a shell

#### Scenario: Preserve Python and JVM integration
- **WHEN** the existing native-module imports and Java 21/JPype/Apache POI workload run against any supported image after the command files are removed
- **THEN** they succeed with the same selected CPython patch and target architecture

### Requirement: Compressed Python layer delivery
Every supported runtime image SHALL deliver its Python filesystem payload as an OCI gzip-compressed tar layer with media type `application/vnd.oci.image.layer.v1.tar+gzip`. The compressed blob SHALL be smaller than its own uncompressed tar representation. Decompression SHALL retain the payload's file contents, paths, permissions and interpreter symlinks, and the uncompressed digest SHALL match the corresponding root filesystem layer digest in the image configuration. Rebuilding the same source revision with identical saved inputs SHALL reproduce identical Python layer, platform-image and multi-platform-index digests.

#### Scenario: Inspect a compressed Python payload
- **WHEN** the Python payload descriptor and blob of any supported platform image are inspected
- **THEN** the descriptor reports the gzip layer media type, its size and SHA-256 match the blob, the blob decompresses successfully, and its uncompressed SHA-256 matches the image configuration
- **AND** the compressed blob contains the retained interpreter and module files and is smaller than its uncompressed tar representation

#### Scenario: Load compressed images through existing delivery paths
- **WHEN** a consumer builds and loads any architecture-specific Docker archive or an existing amd64 minor-only archive
- **THEN** the existing load command, local tags and Docker archive path remain usable and the loaded image executes its bundled Python and Java runtimes

#### Scenario: Repeat the build independently
- **WHEN** the same source revision and saved runtime inputs are built in two independent build directories at different wall-clock times or timezones
- **THEN** all four Python-layer digests, all four platform-image digests and both multi-platform-index digests are identical
