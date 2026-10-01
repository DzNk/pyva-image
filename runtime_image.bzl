"""Python/JVM images with explicit architecture inputs and native OCI indexes."""

load("@pythons_hub//:versions.bzl", "MINOR_MAPPING")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_load", "oci_push")
load("@rules_distroless//apt/private:deb_postfix.bzl", "deb_postfix")
load("@rules_distroless//distroless:defs.bzl", "flatten")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files", "pkg_mklink")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def runtime_layers(arch):
    """Package the explicit Debian closure and Java path for one architecture."""
    flatten(
        name = "java_flat_" + arch,
        tars = ["@debian13_openjdk21//openjdk-21-jre-headless/" + arch],
        deduplicate = True,
    )
    # Debian 13 is merged-/usr.
    deb_postfix(
        name = "java_layer_" + arch,
        mergedusr = True,
        outs = ["java_layer_" + arch + ".tar.gz"],
        srcs = [":java_flat_" + arch],
    )
    pkg_mklink(
        name = "java_" + arch,
        link_name = "usr/bin/java",
        target = "../lib/jvm/java-21-openjdk-" + arch + "/bin/java",
    )
    pkg_tar(
        name = "metadata_layer_" + arch,
        srcs = [":app_dir", ":certs_dir", ":java_" + arch],
    )

def runtime_image(python_version, arch):
    """Define a platform image and its separately tagged Docker loader."""
    suffix = python_version.replace(".", "_")
    name = "pyva_runtime_" + suffix + "_" + arch
    repo = "@cpython_" + suffix + "_" + arch
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
        base = "@distroless_static_debian13_linux_" + ("arm64_v8" if arch == "arm64" else arch),
        annotations = metadata,
        labels = metadata,
        entrypoint = ["/usr/bin/python3"],
        env = {
            "JAVA_HOME": "/usr/lib/jvm/java-21-openjdk-" + arch,
            "LD_LIBRARY_PATH": "/usr/lib/jvm/java-21-openjdk-" + arch + "/lib/server",
            "PATH": "/usr/bin:/bin",
            "PYTHONHOME": "/usr",
            "SSL_CERT_DIR": "/etc/certs",
        },
        tars = [":java_layer_" + arch, ":" + name + "_python_layer", ":metadata_layer_" + arch],
        user = "65532:65532",
        workdir = "/app",
    )
    oci_load(
        name = name + "_load",
        image = ":" + name,
        repo_tags = ["pyva-runtime:" + python_version + "-" + arch] + (
            ["pyva-runtime:" + python_version, "pyva-runtime:" + tag] if arch == "amd64" else []
        ),
    )

def runtime_index(python_version):
    """Publish both platform images together; release.sh supplies remote tags."""
    name = "pyva_runtime_" + python_version.replace(".", "_")
    oci_image_index(
        name = name,
        images = [":" + name + "_amd64", ":" + name + "_arm64"],
    )
    oci_push(name = name + "_push", image = ":" + name)
    oci_load(
        name = name + "_load",
        image = ":" + name + "_amd64",
        repo_tags = ["pyva-runtime:" + python_version, "pyva-runtime:" + MINOR_MAPPING[python_version] + "-java21-debian13"],
    )
