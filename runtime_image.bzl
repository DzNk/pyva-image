"""Python/JVM images parameterized by Python minor; patch versions come from Astral."""

load("@pythons_hub//:versions.bzl", "MINOR_MAPPING")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load", "oci_push")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files", "pkg_mklink")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def runtime_image(python_version):
    """Define an amd64 image plus load/push targets for one Python minor."""
    suffix = python_version.replace(".", "_")
    name = "pyva_runtime_" + suffix
    repo = "@cpython_" + suffix
    executables = [
        "idle" + python_version,
        "pip",
        "pip3",
        "pip" + python_version,
        "pydoc" + python_version,
        "python" + python_version,
        "python" + python_version + "-config",
    ]
    links = {
        "python": "python" + python_version,
        "python3": "python" + python_version,
        "python3-config": "python" + python_version + "-config",
        "idle3": "idle" + python_version,
        "pydoc3": "pydoc" + python_version,
    }
    pkg_files(
        name = name + "_files",
        srcs = [repo + "//:files"],
        excludes = [repo + "//:bin/" + path for path in executables + links.keys()],
        prefix = "usr",
        strip_prefix = "/",
    )
    pkg_files(
        name = name + "_executables",
        srcs = [repo + "//:bin/" + path for path in executables],
        attributes = pkg_attributes(mode = "0555"),
        prefix = "usr",
        strip_prefix = "/",
    )
    for link, target in links.items():
        pkg_mklink(
            name = name + "_" + link.replace("-", "_"),
            link_name = "usr/bin/" + link,
            target = target,
        )
    pkg_tar(
        name = name + "_python_layer",
        srcs = [":" + name + "_files", ":" + name + "_executables"] + [
            ":" + name + "_" + link.replace("-", "_")
            for link in links
        ],
    )
    version = MINOR_MAPPING[python_version]
    tag = version + "-java21-debian13"
    metadata = {
        "org.opencontainers.image.title": "pyva-runtime",
        "org.opencontainers.image.description": "Distroless Debian 13 runtime with CPython " + version + " and OpenJDK 21 for JPype.",
        "org.opencontainers.image.version": tag,
        "org.opencontainers.image.base.name": "gcr.io/distroless/static-debian13",
    }
    oci_image(
        name = name,
        base = "@distroless_static_debian13_linux_amd64",
        annotations = metadata,
        labels = metadata,
        entrypoint = ["/usr/bin/python3"],
        env = {
            "JAVA_HOME": "/usr/lib/jvm/java-21-openjdk-amd64",
            "LD_LIBRARY_PATH": "/usr/lib/jvm/java-21-openjdk-amd64/lib/server",
            "PATH": "/usr/bin:/bin",
            "PYTHONHOME": "/usr",
            "SSL_CERT_DIR": "/etc/certs",
        },
        tars = [":java_layer", ":" + name + "_python_layer", ":metadata_layer"],
        user = "65532:65532",
        workdir = "/app",
    )
    oci_push(
        name = name + "_push",
        image = ":" + name,
        remote_tags = [tag],
    )
    oci_load(
        name = name + "_load",
        image = ":" + name,
        repo_tags = ["pyva-runtime:" + python_version, "pyva-runtime:" + tag],
    )
